const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const socketService = require('../services/socketService');
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// GET /api/profiles
const getAllProfiles = async (req, res) => {
  try {
    const profiles = await prisma.profile.findMany({
      where: { userId: req.user.userId },
      include: {
        timeLimits: true,
        _count: {
          select: { usageLogs: true, warnings: true }
        }
      }
    });
    sendSuccess(res, profiles);
  } catch (error) {
    console.error('Get profiles error:', error);
    sendError(res, 'Failed to get profiles', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/profiles
const createProfile = async (req, res) => {
  try {
    const { profileName, dateOfBirth, avatarUrl } = req.body;

    const profile = await prisma.profile.create({
      data: {
        userId: req.user.userId,
        profileName,
        dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : null,
        avatarUrl
      }
    });

    // Tạo time limits mặc định cho 7 ngày
    const defaultTimeLimits = [];
    for (let day = 0; day < 7; day++) {
      defaultTimeLimits.push({
        profileId: profile.id,
        dayOfWeek: day,
        dailyLimitMinutes: day === 0 || day === 6 ? 180 : 120 // Weekend: 3h, Weekday: 2h
      });
    }

    await prisma.timeLimit.createMany({ data: defaultTimeLimits });

    sendSuccess(res, { profile }, 201);
  } catch (error) {
    console.error('Create profile error:', error);
    sendError(res, 'Failed to create profile', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/profiles/:id
const getProfileById = async (req, res) => {
  try {
    const profile = await prisma.profile.findFirst({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      },
      include: {
        timeLimits: true,
        blockedSites: true,
        warnings: {
          take: 10,
          orderBy: { warnedAt: 'desc' }
        }
      }
    });

    if (!profile) {
      return sendError(res, 'Profile not found', 404, 'NOT_FOUND');
    }

    sendSuccess(res, profile);
  } catch (error) {
    console.error('Get profile error:', error);
    sendError(res, 'Failed to get profile', 500, 'INTERNAL_ERROR');
  }
};

// PUT /api/profiles/:id
const updateProfile = async (req, res) => {
  try {
    const { profileName, dateOfBirth, avatarUrl, isActive } = req.body;

    const profile = await prisma.profile.updateMany({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      },
      data: {
        profileName,
        dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : undefined,
        avatarUrl,
        isActive
      }
    });

    if (profile.count === 0) {
      return sendError(res, 'Profile not found', 404, 'NOT_FOUND');
    }

    sendSuccess(res, { message: 'Profile updated successfully' });
  } catch (error) {
    console.error('Update profile error:', error);
    sendError(res, 'Failed to update profile', 500, 'INTERNAL_ERROR');
  }
};

// DELETE /api/profiles/:id
const deleteProfile = async (req, res) => {
  try {
    const profile = await prisma.profile.deleteMany({
      where: {
        id: parseInt(req.params.id),
        userId: req.user.userId
      }
    });

    if (profile.count === 0) {
      return sendError(res, 'Profile not found', 404, 'NOT_FOUND');
    }

    sendSuccess(res, { message: 'Profile deleted successfully' });
  } catch (error) {
    console.error('Delete profile error:', error);
    sendError(res, 'Failed to delete profile', 500, 'INTERNAL_ERROR');
  }
};

// PUT /api/profiles/:id/time-limits
const updateTimeLimits = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { timeLimits } = req.body;

    // Verify profile belongs to user
    const profile = await prisma.profile.findFirst({
      where: { id: profileId, userId: req.user.userId }
    });

    if (!profile) {
      return sendError(res, 'Profile not found', 404, 'NOT_FOUND');
    }

    // Upsert each day's time limit
    const updates = timeLimits.map((tl) =>
      prisma.timeLimit.upsert({
        where: {
          profileId_dayOfWeek: {
            profileId,
            dayOfWeek: tl.dayOfWeek
          }
        },
        update: { dailyLimitMinutes: tl.dailyLimitMinutes },
        create: {
          profileId,
          dayOfWeek: tl.dayOfWeek,
          dailyLimitMinutes: tl.dailyLimitMinutes
        }
      })
    );

    await prisma.$transaction(updates);

    // Return updated time limits
    const updated = await prisma.timeLimit.findMany({
      where: { profileId },
      orderBy: { dayOfWeek: 'asc' }
    });

    // Tìm tất cả devices thuộc profile này
    const devices = await prisma.device.findMany({
      where: { profileId }
    });

    if (socketService.io) {
      // Emit cho từng device room
      devices.forEach(device => {
        socketService.io.to(`device_${device.deviceCode}`).emit('timeLimitUpdated', {
          profileId,
          timeLimits: updated
        });
      });
    }

    // Cũng emit cho Parent room
    socketService.notifyFamily(req.user.userId, 'timeLimitUpdated', {
      profileId,
      timeLimits: updated
    });

    console.log(`⏰ Time limits updated for profile ${profileId} → notified devices`);

    sendSuccess(res, { timeLimits: updated });
  } catch (error) {
    console.error('Update time limits error:', error);
    sendError(res, 'Failed to update time limits', 500, 'INTERNAL_ERROR');
  }
};

module.exports = {
  getAllProfiles,
  createProfile,
  getProfileById,
  updateProfile,
  deleteProfile,
  updateTimeLimits
};
