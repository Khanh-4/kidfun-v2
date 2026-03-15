const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const socketService = require('../services/socketService');

// Tạo mã device ngẫu nhiên
const generateDeviceCode = () => {
  return crypto.randomBytes(4).toString('hex').toUpperCase();
};

// GET /api/devices
const getAllDevices = async (req, res) => {
  try {
    const devices = await prisma.device.findMany({
      where: { userId: req.user.userId },
      include: {
        profile: true,
        applications: true,
        _count: { select: { sessions: true } }
      }
    });
    sendSuccess(res, devices);
  } catch (error) {
    console.error('Get devices error:', error);
    sendError(res, 'Failed to get devices', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/devices
const registerDevice = async (req, res) => {
  try {
    const { deviceName, osVersion } = req.body;

    const device = await prisma.device.create({
      data: {
        userId: req.user.userId,
        deviceName,
        deviceCode: generateDeviceCode(),
        osVersion
      }
    });

    sendSuccess(res, { device }, 201);
  } catch (error) {
    console.error('Register device error:', error);
    sendError(res, 'Failed to register device', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/devices/:id
const getDeviceById = async (req, res) => {
  try {
    const device = await prisma.device.findFirst({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      },
      include: {
        applications: true,
        sessions: {
          take: 10,
          orderBy: { startTime: 'desc' }
        }
      }
    });

    if (!device) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    sendSuccess(res, device);
  } catch (error) {
    console.error('Get device error:', error);
    sendError(res, 'Failed to get device', 500, 'INTERNAL_ERROR');
  }
};

// PUT /api/devices/:id
const updateDevice = async (req, res) => {
  try {
    const { deviceName, osVersion, isOnline, profileId } = req.body;

    const device = await prisma.device.updateMany({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      },
      data: {
        deviceName,
        osVersion,
        isOnline,
        profileId: profileId !== undefined ? (profileId === null ? null : parseInt(profileId)) : undefined,
        lastSeen: isOnline ? new Date() : undefined
      }
    });

    if (device.count === 0) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    sendSuccess(res, { message: 'Device updated successfully' });
  } catch (error) {
    console.error('Update device error:', error);
    sendError(res, 'Failed to update device', 500, 'INTERNAL_ERROR');
  }
};

// DELETE /api/devices/:id
const deleteDevice = async (req, res) => {
  try {
    const id = parseInt(req.params.id);

    const device = await prisma.device.findFirst({
      where: { id, userId: req.user.userId }
    });

    if (!device) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    await prisma.session.deleteMany({ where: { deviceId: id } });
    await prisma.fCMToken.deleteMany({ where: { deviceId: id } });
    await prisma.device.delete({ where: { id } });

    sendSuccess(res, { message: 'Device deleted successfully' });
  } catch (error) {
    console.error('Delete device error:', error);
    sendError(res, 'Failed to delete device', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/devices/generate-pairing-code
const generatePairingCode = async (req, res) => {
  try {
    const { profileId } = req.body;
    if (!profileId) {
      return sendError(res, 'profileId is required', 400, 'MISSING_FIELDS');
    }

    // Kiểm tra xem profile có thuộc về user hiện tại không
    const profile = await prisma.profile.findFirst({
      where: {
        id: parseInt(profileId),
        userId: req.user.userId
      }
    });

    if (!profile) {
      return sendError(res, 'Profile not found or unauthorized', 404, 'NOT_FOUND');
    }

    // Tạo mã code 6 số random
    const pairingCode = Math.floor(100000 + Math.random() * 900000).toString();
    const pairingCodeExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 phút

    // Tạo device nháp
    const device = await prisma.device.create({
      data: {
        userId: req.user.userId,
        profileId: parseInt(profileId),
        deviceCode: crypto.randomUUID(), // Dùng UUID tạm trong lúc chờ link thật
        deviceName: 'Pending Device',
        pairingCode,
        pairingCodeExpiry
      }
    });

    sendSuccess(res, { pairingCode, deviceId: device.id, expiresAt: pairingCodeExpiry }, 201);
  } catch (error) {
    console.error('Generate pairing code error:', error);
    sendError(res, 'Failed to generate pairing code', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/devices/link
const linkDevice = async (req, res) => {
  try {
    let { pairingCode, deviceCode, deviceName, platform, osVersion } = req.body;

    if (!pairingCode) {
      return sendError(res, 'pairingCode is required', 400, 'MISSING_FIELDS');
    }

    deviceCode = deviceCode || 'DEV-' + Math.random().toString(36).substr(2, 9);
    deviceName = deviceName || 'Thiết bị chưa rõ tên';

    // Tìm device nháp chưa hết hạn
    const pendingDevice = await prisma.device.findFirst({
      where: {
        pairingCode,
        pairingCodeExpiry: { gt: new Date() }
      }
    });

    if (!pendingDevice) {
      return sendError(res, 'Pairing code is invalid or expired', 400, 'INVALID_CODE');
    }

    // Kiểm tra nếu deviceCode phần cứng đã có trong DB thì lấy id cũ ghi đè, nếu không thì dùng record pending
    // Tránh duplicate deviceCode unique constraint
    const existingHardwareDevice = await prisma.device.findUnique({
      where: { deviceCode }
    });

    let linkedDevice;

    if (existingHardwareDevice) {
      // Cập nhật device cũ với thông tin profile mới, xóa pending device
      linkedDevice = await prisma.device.update({
        where: { id: existingHardwareDevice.id },
        data: {
          userId: pendingDevice.userId,
          profileId: pendingDevice.profileId,
          deviceName,
          osVersion: osVersion || existingHardwareDevice.osVersion,
          isOnline: true,
          lastSeen: new Date()
        }
      });
      await prisma.device.delete({ where: { id: pendingDevice.id } });
    } else {
      // Cập nhật đè lên device pending
      linkedDevice = await prisma.device.update({
        where: { id: pendingDevice.id },
        data: {
          deviceCode,
          deviceName,
          osVersion: osVersion || pendingDevice.osVersion,
          pairingCode: null,
          pairingCodeExpiry: null,
          isOnline: true,
          lastSeen: new Date()
        }
      });
    }

    // Generate long-lived JWT for the child device
    const token = jwt.sign(
      { 
        deviceId: linkedDevice.id,
        role: 'child',
        profileId: linkedDevice.profileId,
        userId: linkedDevice.userId
      },
      process.env.JWT_SECRET,
      { expiresIn: '365d' }
    );

    // Notify Parent via Socket.IO
    socketService.notifyFamily(linkedDevice.userId, 'deviceLinked', {
      deviceId: linkedDevice.id,
      deviceCode: linkedDevice.deviceCode,
      deviceName: linkedDevice.deviceName,
      profileId: linkedDevice.profileId
    });

    sendSuccess(res, { message: 'Device linked successfully', token, device: linkedDevice });
  } catch (error) {
    console.error('Link device error:', error);
    sendError(res, 'Failed to link device', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/devices/:id/status
const getDeviceStatus = async (req, res) => {
  try {
    const device = await prisma.device.findFirst({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      }
    });

    if (!device) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    sendSuccess(res, {
      device: {
        id: device.id,
        deviceName: device.deviceName,
        deviceCode: device.deviceCode,
        osVersion: device.osVersion,
        profileId: device.profileId
      },
      isOnline: device.isOnline,
      lastSeen: device.lastSeen
    });
  } catch (error) {
    console.error('Get device status error:', error);
    sendError(res, 'Failed to get device status', 500, 'INTERNAL_ERROR');
  }
};

module.exports = {
  getAllDevices,
  registerDevice,
  getDeviceById,
  updateDevice,
  deleteDevice,
  linkDevice,
  generatePairingCode,
  getDeviceStatus
};
