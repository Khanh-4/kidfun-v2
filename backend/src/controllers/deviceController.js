const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');
const prisma = new PrismaClient();

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
        applications: true,
        _count: { select: { sessions: true } }
      }
    });
    res.json(devices);
  } catch (error) {
    console.error('Get devices error:', error);
    res.status(500).json({ error: 'Failed to get devices' });
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

    res.status(201).json({
      message: 'Device registered successfully',
      device
    });
  } catch (error) {
    console.error('Register device error:', error);
    res.status(500).json({ error: 'Failed to register device' });
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
      return res.status(404).json({ error: 'Device not found' });
    }

    res.json(device);
  } catch (error) {
    console.error('Get device error:', error);
    res.status(500).json({ error: 'Failed to get device' });
  }
};

// PUT /api/devices/:id
const updateDevice = async (req, res) => {
  try {
    const { deviceName, osVersion, isOnline } = req.body;

    const device = await prisma.device.updateMany({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      },
      data: {
        deviceName,
        osVersion,
        isOnline,
        lastSeen: isOnline ? new Date() : undefined
      }
    });

    if (device.count === 0) {
      return res.status(404).json({ error: 'Device not found' });
    }

    res.json({ message: 'Device updated successfully' });
  } catch (error) {
    console.error('Update device error:', error);
    res.status(500).json({ error: 'Failed to update device' });
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
      return res.status(404).json({ error: 'Device not found' });
    }

    res.json({ message: 'Device deleted successfully' });
  } catch (error) {
    console.error('Delete device error:', error);
    res.status(500).json({ error: 'Failed to delete device' });
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
      return res.status(404).json({ error: 'Invalid device code' });
    }

    res.json({
      message: 'Device linked successfully',
      device
    });
  } catch (error) {
    console.error('Link device error:', error);
    res.status(500).json({ error: 'Failed to link device' });
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