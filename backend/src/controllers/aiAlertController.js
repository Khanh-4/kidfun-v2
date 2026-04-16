const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// GET /api/profiles/:id/ai-alerts?unread=true
exports.getAlerts = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const onlyUnread = req.query.unread === 'true';

    const alerts = await prisma.aIAlert.findMany({
      where: {
        profileId,
        ...(onlyUnread ? { isRead: false } : {}),
      },
      include: { youtubeLog: true },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    return sendSuccess(res, { alerts });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// PUT /api/ai-alerts/:id/read
exports.markRead = async (req, res) => {
  try {
    const alert = await prisma.aIAlert.update({
      where: { id: parseInt(req.params.id) },
      data: { isRead: true },
    });
    return sendSuccess(res, { alert });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
