const prisma = require('../utils/prisma');
const { computeSchoolMode } = require('../utils/schoolMode');
const { quotaLogDate, quotaAppUsageSeconds } = require('../utils/appQuotaUsage');
const { vnQuotaDayRange, VN_OFFSET_MS } = require('../utils/vnTime');
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
    // Ngày hạn mức bắt đầu 06:00 giờ VN, tính riêng từng app (xem utils/appQuotaUsage).
    // Trước đây `setHours(0)` trên server UTC lệch ngày trong khung 00:00–06:59 VN.
    const d0 = quotaLogDate();
    const d1 = new Date(d0.getTime() + 24 * 60 * 60 * 1000);
    const d0StartUtc = new Date(d0.getTime() - VN_OFFSET_MS); // 00:00 VN của D0
    const { startOfDay: quotaStart } = vnQuotaDayRange();     // 06:00 VN của D0
    const [usageLogs, earlyHourly] = await Promise.all([
      prisma.appUsageLog.findMany({
        where: { profileId: profile.id, date: { in: [d0, d1] } },
        select: { packageName: true, date: true, usageSeconds: true },
      }),
      prisma.appUsageHourly.findMany({
        where: { profileId: profile.id, hourStart: { gte: d0StartUtc, lt: quotaStart } },
        select: { packageName: true, usageSeconds: true },
      }),
    ]);
    const usedByPackage = quotaAppUsageSeconds(usageLogs, earlyHourly, d0);

    const appTimeLimits = profile.appTimeLimits.map((limit) => {
      const usedSeconds = usedByPackage.get(limit.packageName) || 0;
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
    // Kèm khung giờ hôm nay + override để native tự bật/tắt đúng giờ (xem utils/schoolMode).
    const schoolMode = computeSchoolMode(profile.schoolSchedule);

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
