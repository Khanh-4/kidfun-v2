const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

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
    const device = await prisma.device.deleteMany({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      }
    });

    if (device.count === 0) {
      return sendError(res, 'Device not found', 404, 'NOT_FOUND');
    }

    sendSuccess(res, { message: 'Device deleted successfully' });
  } catch (error) {
    console.error('Delete device error:', error);
    sendError(res, 'Failed to delete device', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/devices/link
const linkDevice = async (req, res) => {
  try {
    const { deviceCode } = req.body;

    const device = await prisma.device.findUnique({
      where: { deviceCode }
    });

    if (!device) {
      return sendError(res, 'Invalid device code', 404, 'NOT_FOUND');
    }

    sendSuccess(res, { device });
  } catch (error) {
    console.error('Link device error:', error);
    sendError(res, 'Failed to link device', 500, 'INTERNAL_ERROR');
  }
};

module.exports = {
  getAllDevices,
  registerDevice,
  getDeviceById,
  updateDevice,
  deleteDevice,
  linkDevice
};
