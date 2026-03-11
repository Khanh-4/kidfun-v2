const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const socketService = require('../services/socketService');
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// GET /api/blocked-sites/:profileId
const getByProfile = async (req, res) => {
  try {
    const profileId = parseInt(req.params.profileId);

    // Verify profile belongs to user
    const profile = await prisma.profile.findFirst({
      where: { id: profileId, userId: req.user.userId }
    });

    if (!profile) {
      return sendError(res, 'Profile not found', 404, 'NOT_FOUND');
    }

    const blockedSites = await prisma.blockedWebsite.findMany({
      where: { profileId },
      orderBy: { createdAt: 'desc' }
    });

    sendSuccess(res, blockedSites);
  } catch (error) {
    console.error('Get blocked sites error:', error);
    sendError(res, 'Failed to get blocked sites', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/blocked-sites
const create = async (req, res) => {
  try {
    const { profileId, blockType, blockValue } = req.body;

    // Verify profile belongs to user
    const profile = await prisma.profile.findFirst({
      where: { id: profileId, userId: req.user.userId }
    });

    if (!profile) {
      return sendError(res, 'Profile not found', 404, 'NOT_FOUND');
    }

    // Check duplicate
    const existing = await prisma.blockedWebsite.findFirst({
      where: { profileId, blockType, blockValue }
    });

    if (existing) {
      return sendError(res, 'This entry already exists', 409, 'DUPLICATE');
    }

    const blockedSite = await prisma.blockedWebsite.create({
      data: { profileId, blockType, blockValue }
    });

    // Notify child devices in real-time via Socket.IO
    const allSites = await prisma.blockedWebsite.findMany({
      where: { profileId }
    });
    socketService.notifyFamily(req.user.userId, 'blockedSitesUpdated', {
      profileId,
      blockedSites: allSites
    });

    sendSuccess(res, blockedSite, 201);
  } catch (error) {
    console.error('Create blocked site error:', error);
    sendError(res, 'Failed to create blocked site', 500, 'INTERNAL_ERROR');
  }
};

// DELETE /api/blocked-sites/:id
const remove = async (req, res) => {
  try {
    const id = parseInt(req.params.id);

    // Verify the blocked site belongs to user's profile
    const blockedSite = await prisma.blockedWebsite.findUnique({
      where: { id },
      include: { profile: true }
    });

    if (!blockedSite || blockedSite.profile.userId !== req.user.userId) {
      return sendError(res, 'Blocked site not found', 404, 'NOT_FOUND');
    }

    const profileId = blockedSite.profile.id;
    await prisma.blockedWebsite.delete({ where: { id } });

    // Notify child devices in real-time via Socket.IO
    const allSites = await prisma.blockedWebsite.findMany({
      where: { profileId }
    });
    socketService.notifyFamily(blockedSite.profile.userId, 'blockedSitesUpdated', {
      profileId,
      blockedSites: allSites
    });

    sendSuccess(res, { message: 'Blocked site removed successfully' });
  } catch (error) {
    console.error('Delete blocked site error:', error);
    sendError(res, 'Failed to delete blocked site', 500, 'INTERNAL_ERROR');
  }
};

module.exports = { getByProfile, create, remove };
