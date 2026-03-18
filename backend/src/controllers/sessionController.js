const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

exports.startSession = async (req, res) => {
  try {
    const { deviceCode } = req.body;

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: { profile: true },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked', 404);
    }

    // Đóng session cũ nếu còn active (phòng trường hợp app crash)
    await prisma.usageSession.updateMany({
      where: { deviceId: device.id, isActive: true },
      data: { isActive: false, endTime: new Date() },
    });

    // Tạo session mới
    const session = await prisma.usageSession.create({
      data: {
        profileId: device.profile.id,
        deviceId: device.id,
      },
    });

    return sendSuccess(res, { sessionId: session.id }, 201);
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

exports.heartbeat = async (req, res) => {
  try {
    const { sessionId } = req.body;

    const session = await prisma.usageSession.findUnique({
      where: { id: sessionId },
      include: {
        profile: { include: { timeLimits: true } },
      },
    });

    if (!session || !session.isActive) {
      return sendError(res, 'Session not found or inactive', 404);
    }

    // Cập nhật updatedAt (chứng minh session vẫn active)
    await prisma.usageSession.update({
      where: { id: sessionId },
      data: { updatedAt: new Date() },
    });

    // Tính remaining time
    const vnNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
    const today = vnNow.getDay();
    const todayLimit = session.profile.timeLimits.find(tl => tl.dayOfWeek === today);
    const startOfDay = new Date(vnNow);
    startOfDay.setHours(0, 0, 0, 0);

    const extensions = await prisma.timeExtensionRequest.findMany({
      where: {
        profileId: session.profileId,
        status: 'APPROVED',
        createdAt: { gte: startOfDay },
      }
    });
    const extensionBonus = extensions.reduce((sum, req) => sum + (req.responseMinutes || 0), 0);

    const baseLimit = todayLimit?.dailyLimitMinutes || todayLimit?.limitMinutes || 0;
    const limitMinutes = baseLimit + extensionBonus;

    const sessions = await prisma.usageSession.findMany({
      where: {
        profileId: session.profileId,
        startTime: { gte: startOfDay },
      },
    });

    const usedSeconds = sessions.reduce((total, s) => {
      const end = s.endTime || new Date();
      return total + (end.getTime() - new Date(s.startTime).getTime()) / 1000;
    }, 0);

    const limitSeconds = limitMinutes * 60;
    const remainingSeconds = Math.max(0, Math.round(limitSeconds - usedSeconds));
    const remainingMinutes = Math.ceil(remainingSeconds / 60);
    const usedMinutes = Math.floor(usedSeconds / 60);

    return sendSuccess(res, {
      sessionId,
      remainingMinutes,
      remainingSeconds,
      limitMinutes,
      usedMinutes,
    });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

exports.endSession = async (req, res) => {
  try {
    const { sessionId } = req.body;

    await prisma.usageSession.update({
      where: { id: sessionId },
      data: { isActive: false, endTime: new Date() },
    });

    return sendSuccess(res, { message: 'Session ended' });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
