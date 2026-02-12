const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// GET /api/blocked-sites/:profileId
const getByProfile = async (req, res) => {
  try {
    const profileId = parseInt(req.params.profileId);

    // Verify profile belongs to user
    const profile = await prisma.profile.findFirst({
      where: { id: profileId, userId: req.user.userId }
    });

    if (!profile) {
      return res.status(404).json({ error: 'Profile not found' });
    }

    const blockedSites = await prisma.blockedWebsite.findMany({
      where: { profileId },
      orderBy: { createdAt: 'desc' }
    });

    res.json(blockedSites);
  } catch (error) {
    console.error('Get blocked sites error:', error);
    res.status(500).json({ error: 'Failed to get blocked sites' });
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
      return res.status(404).json({ error: 'Profile not found' });
    }

    // Check duplicate
    const existing = await prisma.blockedWebsite.findFirst({
      where: { profileId, blockType, blockValue }
    });

    if (existing) {
      return res.status(409).json({ error: 'This entry already exists' });
    }

    const blockedSite = await prisma.blockedWebsite.create({
      data: { profileId, blockType, blockValue }
    });

    res.status(201).json(blockedSite);
  } catch (error) {
    console.error('Create blocked site error:', error);
    res.status(500).json({ error: 'Failed to create blocked site' });
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
      return res.status(404).json({ error: 'Blocked site not found' });
    }

    await prisma.blockedWebsite.delete({ where: { id } });

    res.json({ message: 'Blocked site removed successfully' });
  } catch (error) {
    console.error('Delete blocked site error:', error);
    res.status(500).json({ error: 'Failed to delete blocked site' });
  }
};

module.exports = { getByProfile, create, remove };
