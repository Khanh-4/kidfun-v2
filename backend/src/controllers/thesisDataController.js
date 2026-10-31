const prisma = require('../utils/prisma');
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// Đồ án chuyên ngành (T7.1.1a): tác vụ ML ban đêm trên GitHub Actions đọc dữ liệu qua đây
// thay vì nối thẳng DB (lý do ở docs/thesis/ke-hoach/tasks/T7-tich-hop.md, T7.1.1).
// Chỉ trả đúng các cột mà ml/features/ dùng — không tên, email, appName, lý do xin giờ,
// deviceId hay vị trí (dữ liệu tối thiểu, dùng cho chương quyền riêng tư).
//
// Chia trang theo trẻ để response không chạm giới hạn 4,5 MB của Vercel: gọi lại với
// afterProfileId = nextAfterProfileId cho tới khi nó là null.

const DEFAULT_DAYS = 28;
const MAX_DAYS = 90;
const DEFAULT_LIMIT = 10;
const MAX_LIMIT = 50;
const DAY_MS = 24 * 60 * 60 * 1000;
// Vercel cắt response > 4,5 MB; chừa biên cho phần bọc { success, data }.
const MAX_RESPONSE_BYTES = 4 * 1024 * 1024;

// Số nguyên trong [min, max]; thiếu thì lấy mặc định; sai thì null.
const parseIntParam = (raw, fallback, min, max) => {
  if (raw === undefined) return fallback;
  const n = Number(raw);
  return Number.isInteger(n) && n >= min && n <= max ? n : null;
};

// GET /api/cron/thesis-data?days=28&limit=10&afterProfileId=0
const getThesisData = async (req, res) => {
  try {
    const days = parseIntParam(req.query.days, DEFAULT_DAYS, 1, MAX_DAYS);
    const limit = parseIntParam(req.query.limit, DEFAULT_LIMIT, 1, MAX_LIMIT);
    const afterProfileId = parseIntParam(req.query.afterProfileId, 0, 0, Number.MAX_SAFE_INTEGER);
    if (days === null || limit === null || afterProfileId === null) {
      return sendError(res,
        `days (1–${MAX_DAYS}), limit (1–${MAX_LIMIT}), afterProfileId (≥ 0) phải là số nguyên`,
        400, 'INVALID_QUERY');
    }

    const page = await prisma.profile.findMany({
      where: { isActive: true, id: { gt: afterProfileId } },
      orderBy: { id: 'asc' },
      take: limit,
      select: { id: true },
    });
    const profileIds = page.map((p) => p.id);
    const since = new Date(Date.now() - days * DAY_MS);
    const ofPage = { profileId: { in: profileIds } };

    const [hourly, limits, extRequests] = await Promise.all([
      prisma.appUsageHourly.findMany({
        where: { ...ofPage, hourStart: { gte: since } },
        select: { profileId: true, packageName: true, hourStart: true, usageSeconds: true, launchCount: true },
        orderBy: [{ profileId: 'asc' }, { hourStart: 'asc' }],
      }),
      prisma.timeLimit.findMany({
        where: ofPage,
        select: { profileId: true, dayOfWeek: true, dailyLimitMinutes: true, isActive: true, isGradual: true },
        orderBy: [{ profileId: 'asc' }, { dayOfWeek: 'asc' }],
      }),
      prisma.timeExtensionRequest.findMany({
        where: { ...ofPage, createdAt: { gte: since } },
        select: { profileId: true, createdAt: true, requestMinutes: true, status: true },
        orderBy: [{ profileId: 'asc' }, { createdAt: 'asc' }],
      }),
    ]);

    const data = {
      since,
      profileIds,
      nextAfterProfileId: profileIds.length === limit ? profileIds[profileIds.length - 1] : null,
      hourly,
      limits,
      extRequests,
    };
    // Trang quá to thì báo để tác vụ giảm limit rồi gọi lại, thay vì để Vercel cắt ngang.
    if (Buffer.byteLength(JSON.stringify(data)) > MAX_RESPONSE_BYTES) {
      return sendError(res, `Trang vượt ${MAX_RESPONSE_BYTES} byte, hãy giảm limit`, 413, 'PAGE_TOO_LARGE');
    }

    sendSuccess(res, data);
  } catch (error) {
    console.error('getThesisData error:', error);
    sendError(res, 'Failed to load thesis data', 500, 'INTERNAL_ERROR');
  }
};

module.exports = { getThesisData };
