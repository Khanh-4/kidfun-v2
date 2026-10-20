const prisma = require('../utils/prisma');
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { ownedBy } = require('../utils/ownership');

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
    const id = parseInt(req.params.id);
    if (!(await prisma.aIAlert.findFirst({ where: { id, ...ownedBy(req) }, select: { id: true } }))) {
      return sendError(res, 'Alert not found', 404);
    }
    const alert = await prisma.aIAlert.update({ where: { id }, data: { isRead: true } });
    return sendSuccess(res, { alert });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};
