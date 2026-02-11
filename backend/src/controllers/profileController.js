const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

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
    res.json(profiles);
  } catch (error) {
    console.error('Get profiles error:', error);
    res.status(500).json({ error: 'Failed to get profiles' });
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

    res.status(201).json({
      message: 'Profile created successfully',
      profile
    });
  } catch (error) {
    console.error('Create profile error:', error);
    res.status(500).json({ error: 'Failed to create profile' });
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
      return res.status(404).json({ error: 'Profile not found' });
    }

    res.json(profile);
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Failed to get profile' });
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
      return res.status(404).json({ error: 'Profile not found' });
    }

    res.json({ message: 'Profile updated successfully' });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Failed to update profile' });
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
      return res.status(404).json({ error: 'Profile not found' });
    }

    res.json({ message: 'Profile deleted successfully' });
  } catch (error) {
    console.error('Delete profile error:', error);
    res.status(500).json({ error: 'Failed to delete profile' });
  }
};

module.exports = {
  getAllProfiles,
  createProfile,
  getProfileById,
  updateProfile,
  deleteProfile
};