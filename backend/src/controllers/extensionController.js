const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

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
