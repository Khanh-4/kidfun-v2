const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const socketService = require('../services/socketService');
const { sendPushToUser } = require('../services/firebaseService');

// GET /api/profiles/:id/extension-requests
exports.getExtensionRequests = async (req, res) => {
  try {
    const requests = await prisma.timeExtensionRequest.findMany({
      where: { profileId: parseInt(req.params.id) },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    return sendSuccess(res, { requests });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// GET /api/extension-requests/pending
exports.getPendingRequests = async (req, res) => {
  try {
    const profiles = await prisma.profile.findMany({
      where: { userId: req.user.userId },
      select: { id: true },
    });
    const profileIds = profiles.map(p => p.id);

    const requests = await prisma.timeExtensionRequest.findMany({
      where: {
        profileId: { in: profileIds },
        status: 'PENDING',
      },
      include: {
        profile: { select: { profileName: true } },
        device: { select: { deviceName: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return sendSuccess(res, { requests });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// POST /api/child/extension-request  (BUG 2 FIX)
// REST endpoint for Child to request more time — creates DB record + socket + FCM push
exports.createExtensionRequest = async (req, res) => {
  try {
    const deviceCode = req.headers['x-device-code'];
    const { requestMinutes, reason } = req.body;

    if (!deviceCode) {
      return sendError(res, 'Device code required in X-Device-Code header', 400, 'MISSING_DEVICE_CODE');
    }

    if (!requestMinutes || requestMinutes <= 0) {
      return sendError(res, 'requestMinutes must be a positive integer', 400, 'INVALID_INPUT');
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not found or not linked to profile', 404, 'DEVICE_NOT_FOUND');
    }

    // Create the request in DB
    const request = await prisma.timeExtensionRequest.create({
      data: {
        profileId: device.profile.id,
        deviceId: device.id,
        requestMinutes,
        reason: reason || '',
      },
    });

    // Emit Socket.IO event to Parent room
    if (socketService.io) {
      socketService.io.to(`family_${device.userId}`).emit('timeExtensionRequest', {
        requestId: request.id,
        profileId: device.profile.id,
        profileName: device.profile.profileName,
        deviceName: device.deviceName,
        requestMinutes,
        reason: reason || '',
        createdAt: request.createdAt,
      });
    }

    // Send FCM push notification to Parent (BUG 2 FIX: the critical missing step)
    try {
      await sendPushToUser(device.userId, {
        title: `⏳ ${device.profile.profileName} xin thêm giờ`,
        body: `Xin thêm ${requestMinutes} phút${reason ? ': ' + reason : ''}`,
        data: {
          type: 'time_extension',
          requestId: String(request.id),
          profileId: String(device.profile.id),
        },
      });
      console.log(`🔔 FCM push sent to userId ${device.userId} for extension request ${request.id}`);
    } catch (fcmErr) {
      // Non-fatal: log but still return success to the child
      console.error('FCM push failed (non-fatal):', fcmErr.message);
    }

    return sendSuccess(res, {
      requestId: request.id,
      profileId: device.profile.id,
      requestMinutes,
      status: 'PENDING',
    }, 201);
  } catch (err) {
    console.error('createExtensionRequest error:', err.message);
    return sendError(res, err.message, 500);
  }
};

// PUT /api/extension-requests/:id/approve  (BUG 2 FIX)
// REST endpoint: Parent approves a time extension — DB write FIRST, socket event AFTER
exports.approveExtension = async (req, res) => {
  try {
    const requestId = parseInt(req.params.id);
    const { responseMinutes } = req.body;

    // ── Step 1: Update DB record so heartbeat sees the bonus immediately ────
    const request = await prisma.timeExtensionRequest.update({
      where: { id: requestId },
      data: {
        status: 'APPROVED',
        responseMinutes: responseMinutes || null,
        respondedAt: new Date(),
      },
      include: {
        device: true,
        profile: true,
      },
    });

    const actualMinutes = responseMinutes || request.requestMinutes;

    // ── Step 2: Verify caller is the owning parent ───────────────────────────
    const profiles = await prisma.profile.findMany({
      where: { userId: req.user.userId },
      select: { id: true },
    });
    const profileIds = profiles.map(p => p.id);
    if (!profileIds.includes(request.profileId)) {
      return sendError(res, 'Forbidden', 403);
    }

    // ── Step 3: Notify child device via Socket.IO AFTER DB write ────────────
    if (socketService.io) {
      socketService.io
        .to(`device_${request.device.deviceCode}`)
        .emit('timeExtensionResponse', {
          requestId: request.id,
          approved: true,
          responseMinutes: actualMinutes,
          status: 'APPROVED',
        });
    }

    console.log(`✅ [REST] Extension APPROVED: ${request.profile.profileName} +${actualMinutes}min (req #${requestId})`);

    return sendSuccess(res, {
      requestId: request.id,
      status: 'APPROVED',
      responseMinutes: actualMinutes,
    });
  } catch (err) {
    console.error('approveExtension error:', err.message);
    return sendError(res, err.message, 500);
  }
};
