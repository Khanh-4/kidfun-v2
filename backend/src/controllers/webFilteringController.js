const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const socketService = require('../services/socketService');

// Helper: notify child devices that blocked domains changed
const notifyChildDomainsUpdated = async (profileId) => {
  const io = socketService.io;
  if (!io) return;

  const devices = await prisma.device.findMany({ where: { profileId } });
  for (const d of devices) {
    io.to(`device_${d.deviceCode}`).emit('blockedDomainsUpdated', { profileId });
  }
};

// ── Categories ──────────────────────────────────────────────────────────────

// GET /api/web-categories — tất cả categories (cho Parent UI)
const getCategories = async (req, res) => {
  try {
    const categories = await prisma.webCategory.findMany({
      include: { domains: { select: { domain: true } } },
      orderBy: { displayName: 'asc' },
    });
    return sendSuccess(res, { categories });
  } catch (err) {
    console.error('getCategories error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// ── Blocked Categories per Profile ─────────────────────────────────────────

// GET /api/profiles/:id/blocked-categories
const getBlockedCategories = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const blocked = await prisma.blockedCategory.findMany({
      where: { profileId },
      include: {
        category: { include: { domains: true } },
        overrides: true,
      },
    });
    return sendSuccess(res, { blockedCategories: blocked });
  } catch (err) {
    console.error('getBlockedCategories error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// POST /api/profiles/:id/blocked-categories — toggle category on/off
const toggleCategory = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { categoryId, isBlocked } = req.body;

    if (!categoryId || typeof isBlocked !== 'boolean') {
      return sendError(res, 'categoryId and isBlocked (boolean) are required', 400, 'INVALID_DATA');
    }

    const blocked = await prisma.blockedCategory.upsert({
      where: { profileId_categoryId: { profileId, categoryId: parseInt(categoryId) } },
      update: { isBlocked },
      create: { profileId, categoryId: parseInt(categoryId), isBlocked },
    });

    await notifyChildDomainsUpdated(profileId);
    return sendSuccess(res, { blocked }, 201);
  } catch (err) {
    console.error('toggleCategory error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// ── Category Overrides ──────────────────────────────────────────────────────

// POST /api/profiles/:id/blocked-categories/:categoryId/override — whitelist 1 domain
const addCategoryOverride = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const categoryId = parseInt(req.params.categoryId);
    const { domain } = req.body;

    if (!domain) {
      return sendError(res, 'domain is required', 400, 'INVALID_DATA');
    }

    const blocked = await prisma.blockedCategory.findUnique({
      where: { profileId_categoryId: { profileId, categoryId } },
    });

    if (!blocked) {
      return sendError(res, 'Category not configured for this profile', 404, 'NOT_FOUND');
    }

    let override;
    try {
      override = await prisma.categoryOverride.upsert({
        where: { blockedCategoryId_domain: { blockedCategoryId: blocked.id, domain } },
        update: {},
        create: { blockedCategoryId: blocked.id, domain },
      });
    } catch (upsertErr) {
      if (upsertErr.code === 'P2002') {
        // Race condition: concurrent request already inserted the same record
        override = await prisma.categoryOverride.findUnique({
          where: { blockedCategoryId_domain: { blockedCategoryId: blocked.id, domain } },
        });
      } else {
        throw upsertErr;
      }
    }

    await notifyChildDomainsUpdated(profileId);
    return sendSuccess(res, { override }, 201);
  } catch (err) {
    console.error('addCategoryOverride error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// DELETE /api/profiles/:id/blocked-categories/:categoryId/override/:domain
const removeCategoryOverride = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const categoryId = parseInt(req.params.categoryId);
    const domain = decodeURIComponent(req.params.domain);

    const blocked = await prisma.blockedCategory.findUnique({
      where: { profileId_categoryId: { profileId, categoryId } },
    });

    if (!blocked) {
      return sendError(res, 'Category not configured for this profile', 404, 'NOT_FOUND');
    }

    await prisma.categoryOverride.deleteMany({
      where: { blockedCategoryId: blocked.id, domain },
    });

    await notifyChildDomainsUpdated(profileId);
    return sendSuccess(res, { message: 'Override removed' });
  } catch (err) {
    console.error('removeCategoryOverride error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// ── Custom Blocked Domains ──────────────────────────────────────────────────

// GET /api/profiles/:id/custom-blocked-domains
const getCustomDomains = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const domains = await prisma.customBlockedDomain.findMany({
      where: { profileId },
      orderBy: { domain: 'asc' },
    });
    return sendSuccess(res, { domains });
  } catch (err) {
    console.error('getCustomDomains error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// POST /api/profiles/:id/custom-blocked-domains
const addCustomDomain = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { domain, reason } = req.body;

    if (!domain) {
      return sendError(res, 'domain is required', 400, 'INVALID_DATA');
    }

    const created = await prisma.customBlockedDomain.upsert({
      where: { profileId_domain: { profileId, domain } },
      update: { reason: reason || null },
      create: { profileId, domain, reason: reason || null },
    });

    await notifyChildDomainsUpdated(profileId);
    return sendSuccess(res, { domain: created }, 201);
  } catch (err) {
    console.error('addCustomDomain error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// DELETE /api/profiles/:id/custom-blocked-domains/:domain
const deleteCustomDomain = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const domain = decodeURIComponent(req.params.domain);

    await prisma.customBlockedDomain.deleteMany({ where: { profileId, domain } });

    await notifyChildDomainsUpdated(profileId);
    return sendSuccess(res, { message: 'Domain removed' });
  } catch (err) {
    console.error('deleteCustomDomain error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// ── Child Sync ──────────────────────────────────────────────────────────────

// GET /api/child/blocked-domains?deviceCode=XXX — danh sách domains cuối cùng
const getChildBlockedDomains = async (req, res) => {
  try {
    const { deviceCode } = req.query;

    if (!deviceCode) {
      return sendError(res, 'deviceCode query param required', 400, 'MISSING_DEVICE_CODE');
    }

    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: {
        profile: {
          include: {
            blockedCategories: {
              where: { isBlocked: true },
              include: {
                category: { include: { domains: true } },
                overrides: true,
              },
            },
            customBlockedDomains: true,
          },
        },
      },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked to any profile', 404, 'DEVICE_NOT_LINKED');
    }

    // Tính danh sách domain cuối cùng (categories - overrides + custom)
    const blockedDomains = new Set();

    for (const bc of device.profile.blockedCategories) {
      const overrideSet = new Set(bc.overrides.map((o) => o.domain));
      for (const d of bc.category.domains) {
        if (!overrideSet.has(d.domain)) {
          blockedDomains.add(d.domain);
        }
      }
    }

    for (const cd of device.profile.customBlockedDomains) {
      blockedDomains.add(cd.domain);
    }

    const domainsArray = Array.from(blockedDomains).sort();

    return sendSuccess(res, {
      domains: domainsArray,
      count: domainsArray.length,
    });
  } catch (err) {
    console.error('getChildBlockedDomains error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = {
  getCategories,
  getBlockedCategories,
  toggleCategory,
  addCategoryOverride,
  removeCategoryOverride,
  getCustomDomains,
  addCustomDomain,
  deleteCustomDomain,
  getChildBlockedDomains,
};
