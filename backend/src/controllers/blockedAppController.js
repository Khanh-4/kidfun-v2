const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const socketService = require('../services/socketService');
const { sendPushNotification } = require('../services/firebaseService');

// Helper: notify child devices of a profile that blocked apps changed
const notifyBlockedAppsUpdated = async (profileId) => {
  const io = socketService.io;
  
  // Get all devices for this profile
  const devices = await prisma.device.findMany({ where: { profileId } });
  
  // Get current blocked apps list to include in FCM payload
  const blockedApps = await prisma.blockedApp.findMany({
    where: { profileId, isBlocked: true },
    select: { packageName: true }
  });
  const packageNames = blockedApps.map(a => a.packageName);
  
  for (const d of devices) {
    // Socket.IO notification (works when Flutter engine is active)
    if (io) {
      io.to(`device_${d.deviceCode}`).emit('blockedAppsUpdated', { profileId });
    }
    
    // FCM data-only push (works even when app is in background/killed)
    // This ensures the first block command reaches the native layer immediately
    const fcmTokens = await prisma.fCMToken.findMany({
      where: { deviceId: d.id }
    });
    
    for (const t of fcmTokens) {
      try {
        await sendPushNotification(
          t.token,
          '', // Empty title = data-only (no visible notification)
          '', // Empty body
          {
            type: 'blocked_apps_update',
            profileId: String(profileId),
            packageNames: JSON.stringify(packageNames),
          }
        );
      } catch (e) {
        console.error(`❌ FCM blocked apps push failed for device ${d.deviceCode}:`, e.message);
      }
    }
  }
  
  console.log(`🚫 [BLOCKED] Notified ${devices.length} devices (socket + FCM) for profile ${profileId}`);
};

// GET /api/profiles/:id/blocked-apps
const getBlockedApps = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const blockedApps = await prisma.blockedApp.findMany({
      where: { profileId },
      orderBy: { appName: 'asc' },
    });
    return sendSuccess(res, { blockedApps });
  } catch (err) {
    console.error('getBlockedApps error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// POST /api/profiles/:id/blocked-apps
const addBlockedApp = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { packageName, appName } = req.body;

    if (!packageName) {
      return sendError(res, 'packageName is required', 400, 'MISSING_FIELDS');
    }

    const blockedApp = await prisma.blockedApp.upsert({
      where: { profileId_packageName: { profileId, packageName } },
      update: { isBlocked: true, ...(appName ? { appName } : {}) },
      create: { profileId, packageName, appName: appName || null, isBlocked: true },
    });

    await notifyBlockedAppsUpdated(profileId);

    return sendSuccess(res, { blockedApp }, 201);
  } catch (err) {
    console.error('addBlockedApp error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// DELETE /api/profiles/:id/blocked-apps/:packageName
const removeBlockedApp = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const packageName = decodeURIComponent(req.params.packageName);

    await prisma.blockedApp.deleteMany({ where: { profileId, packageName } });

    await notifyBlockedAppsUpdated(profileId);

    return sendSuccess(res, { message: 'App unblocked' });
  } catch (err) {
    console.error('removeBlockedApp error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// GET /api/child/blocked-apps?deviceCode=XXX
const getBlockedAppsForChild = async (req, res) => {
  try {
    const { deviceCode } = req.query;

    if (!deviceCode) {
      return sendError(res, 'deviceCode query param required', 400, 'MISSING_DEVICE_CODE');
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: {
        profile: {
          include: { blockedApps: { where: { isBlocked: true } } },
        },
      },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked to any profile', 404, 'DEVICE_NOT_LINKED');
    }

    const blockedApps = device.profile.blockedApps.map((app) => ({
      packageName: app.packageName,
      appName: app.appName,
    }));

    return sendSuccess(res, { blockedApps });
  } catch (err) {
    console.error('getBlockedAppsForChild error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = { getBlockedApps, addBlockedApp, removeBlockedApp, getBlockedAppsForChild };
