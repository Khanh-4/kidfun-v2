const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// GET /api/profiles/:id/geofences — Danh sách geofences của profile
exports.getGeofences = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const geofences = await prisma.geofence.findMany({
      where: { profileId },
      orderBy: { createdAt: 'desc' },
    });
    return sendSuccess(res, { geofences });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// POST /api/profiles/:id/geofences — Tạo geofence mới
exports.createGeofence = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { name, latitude, longitude, radius } = req.body;

    if (!name || typeof latitude !== 'number' || typeof longitude !== 'number' || !radius) {
      return sendError(res, 'Missing required fields', 400);
    }

    if (radius < 50 || radius > 5000) {
      return sendError(res, 'Radius must be between 50 and 5000 meters', 400);
    }

    const geofence = await prisma.geofence.create({
      data: { profileId, name, latitude, longitude, radius, isActive: true },
    });

    return sendSuccess(res, { geofence }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// PUT /api/geofences/:id — Cập nhật geofence
exports.updateGeofence = async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const { name, latitude, longitude, radius, isActive } = req.body;

    if (radius !== undefined && (radius < 50 || radius > 5000)) {
      return sendError(res, 'Radius must be between 50 and 5000 meters', 400);
    }

    const geofence = await prisma.geofence.update({
      where: { id },
      data: {
        ...(name !== undefined && { name }),
        ...(latitude !== undefined && { latitude }),
        ...(longitude !== undefined && { longitude }),
        ...(radius !== undefined && { radius }),
        ...(isActive !== undefined && { isActive }),
      },
    });

    return sendSuccess(res, { geofence });
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'Geofence not found', 404);
    return sendError(res, err.message, 500);
  }
};

// DELETE /api/geofences/:id — Xóa geofence
exports.deleteGeofence = async (req, res) => {
  try {
    await prisma.geofence.delete({ where: { id: parseInt(req.params.id) } });
    return sendSuccess(res, { message: 'Geofence deleted' });
  } catch (err) {
    if (err.code === 'P2025') return sendError(res, 'Geofence not found', 404);
    return sendError(res, err.message, 500);
  }
};

// GET /api/profiles/:id/geofences/events?date=YYYY-MM-DD — Lịch sử ENTER/EXIT
exports.getGeofenceEvents = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const dateStr = req.query.date || new Date().toISOString().split('T')[0];

    const startOfDay = new Date(dateStr);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(startOfDay);
    endOfDay.setDate(endOfDay.getDate() + 1);

    const events = await prisma.geofenceEvent.findMany({
      where: {
        profileId,
        createdAt: { gte: startOfDay, lt: endOfDay },
      },
      include: { geofence: true },
      orderBy: { createdAt: 'desc' },
    });

    return sendSuccess(res, { events });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
