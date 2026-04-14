const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// GET /api/child/policy?deviceCode=XXX — tất cả policy trong 1 request
const getChildPolicy = async (req, res) => {
  try {
    const { deviceCode } = req.query;

    if (!deviceCode) {
      return sendError(res, 'deviceCode query param required', 400, 'MISSING_DEVICE_CODE');
    }

    // Load device + profile + all related data trong 1 query
    const device = await prisma.device.findFirst({
      where: { deviceCode },
      include: {
        profile: {
          include: {
            appTimeLimits: { where: { isActive: true } },
            blockedCategories: {
              where: { isBlocked: true },
              include: {
                category: { include: { domains: true } },
                overrides: true,
              },
            },
            customBlockedDomains: true,
            schoolSchedule: {
              include: { daySchedules: true, allowedApps: true },
            },
          },
        },
      },
    });

    if (!device || !device.profile) {
      return sendError(res, 'Device not linked to any profile', 404, 'DEVICE_NOT_LINKED');
    }

    const profile = device.profile;

    // ── 1. Per-app Time Limits ──────────────────────────────────────────────
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todayUsage = await prisma.appUsageLog.findMany({
      where: { profileId: profile.id, date: today },
    });

    const appTimeLimits = profile.appTimeLimits.map((limit) => {
      const usage = todayUsage.find((u) => u.packageName === limit.packageName);
      const usedSeconds = usage?.usageSeconds || 0;
      const remainingSeconds = Math.max(0, limit.dailyLimitMinutes * 60 - usedSeconds);
      return {
        packageName: limit.packageName,
        appName: limit.appName,
        dailyLimitMinutes: limit.dailyLimitMinutes,
        usedSeconds,
        remainingSeconds,
      };
    });

    // ── 2. Blocked Domains ─────────────────────────────────────────────────
    const blockedDomains = new Set();

    for (const bc of profile.blockedCategories) {
      const overrideSet = new Set(bc.overrides.map((o) => o.domain));
      for (const d of bc.category.domains) {
        if (!overrideSet.has(d.domain)) {
          blockedDomains.add(d.domain);
        }
      }
    }

    for (const cd of profile.customBlockedDomains) {
      blockedDomains.add(cd.domain);
    }

    const domainsArray = Array.from(blockedDomains).sort();

    // ── 3. School Mode ─────────────────────────────────────────────────────
    let schoolMode = { isActive: false, allowedApps: [] };

    const s = profile.schoolSchedule;
    if (s) {
      // Manual override còn hiệu lực
      if (s.manualOverride && s.overrideUntil && new Date() < s.overrideUntil) {
        schoolMode = {
          isActive: s.manualOverride === 'FORCE_ON',
          reason: 'MANUAL_OVERRIDE',
          allowedApps: s.allowedApps,
        };
      } else if (!s.isEnabled) {
        schoolMode = { isActive: false, allowedApps: [] };
      } else {
        // Tính theo lịch (timezone VN)
        const now = new Date();
        const vnNow = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
        const today = vnNow.getDay();
        const currentTime = `${String(vnNow.getHours()).padStart(2, '0')}:${String(vnNow.getMinutes()).padStart(2, '0')}`;

        const override = s.daySchedules.find((d) => d.dayOfWeek === today);
        const start = override?.startTime || s.templateStartTime;
        const end = override?.endTime || s.templateEndTime;
        const enabled = override ? override.isEnabled : true;

        const isActive = !!(enabled && start && end && currentTime >= start && currentTime < end);

        schoolMode = {
          isActive,
          reason: 'SCHEDULED',
          startTime: start,
          endTime: end,
          allowedApps: s.allowedApps,
        };
      }
    }

    return sendSuccess(res, {
      appTimeLimits,
      blockedDomains: domainsArray,
      schoolMode,
    });
  } catch (err) {
    console.error('getChildPolicy error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = { getChildPolicy };
