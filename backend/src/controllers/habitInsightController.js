/**
 * Nhóm thói quen (M3) + gợi ý cho phụ huynh (M4) — đồ án chuyên ngành, T7.5.3.
 *
 * PUT /api/cron/habit-insights (CRON_SECRET) — tác vụ ban đêm ghi, upsert theo (profileId, date).
 *   Body: { modelVersion, insights: [{ profileId, date 'YYYY-MM-DD', habitSummary?, clusterId?, clusterCount?,
 *           suggestions: [{ code, text }] }] }
 * GET /api/profiles/:id/habit-insight — app phụ huynh đọc bản mới nhất (null khi chưa có).
 */

const prisma = require('../utils/prisma');
const { sendSuccess, sendError } = require('../middleware/responseHandler');

const MAX_INSIGHTS = 500;
const MAX_SUGGESTIONS = 5;
const MAX_TEXT = 500;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const CODE_RE = /^[a-z_]{1,40}$/;

const isOptInt = (v) => v === undefined || v === null || (Number.isInteger(v) && v >= 0 && v < 1000);
const isOptText = (v) => v === undefined || v === null || (typeof v === 'string' && v.length <= MAX_TEXT);
const isSuggestion = (s) =>
  s && typeof s.code === 'string' && CODE_RE.test(s.code) && typeof s.text === 'string' && s.text.length > 0 &&
  s.text.length <= MAX_TEXT;

const isValidInsight = (i) =>
  i && Number.isInteger(i.profileId) && typeof i.date === 'string' && DATE_RE.test(i.date) &&
  isOptText(i.habitSummary) && isOptInt(i.clusterId) && isOptInt(i.clusterCount) &&
  Array.isArray(i.suggestions) && i.suggestions.length <= MAX_SUGGESTIONS && i.suggestions.every(isSuggestion);

const upsertInsight = (i, modelVersion) => {
  const data = {
    habitSummary: i.habitSummary ?? null,
    clusterId: i.clusterId ?? null,
    clusterCount: i.clusterCount ?? null,
    suggestions: i.suggestions.map(({ code, text }) => ({ code, text })),
    modelVersion,
  };
  const date = new Date(`${i.date}T00:00:00Z`);
  return prisma.habitInsight.upsert({
    where: { profileId_date: { profileId: i.profileId, date } },
    update: data,
    create: { profileId: i.profileId, date, ...data },
  });
};

const saveInsights = async (req, res) => {
  try {
    const { modelVersion, insights } = req.body;
    if (typeof modelVersion !== 'string' || !modelVersion) {
      return sendError(res, 'modelVersion is required', 400, 'INVALID_INSIGHTS');
    }
    if (!Array.isArray(insights) || insights.length > MAX_INSIGHTS || !insights.every(isValidInsight)) {
      return sendError(res, `insights must be an array of 0..${MAX_INSIGHTS} valid entries`, 400, 'INVALID_INSIGHTS');
    }

    const ids = [...new Set(insights.map((i) => i.profileId))];
    const found = await prisma.profile.findMany({ where: { id: { in: ids } }, select: { id: true } });
    const known = new Set(found.map((p) => p.id));
    const rows = insights.filter((i) => known.has(i.profileId));
    await prisma.$transaction(rows.map((i) => upsertInsight(i, modelVersion)));

    return sendSuccess(res, { saved: rows.length, unknownProfiles: ids.length - known.size });
  } catch (err) {
    console.error('saveInsights error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

const latestInsight = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id, 10);
    const profile = await prisma.profile.findFirst({ where: { id: profileId, userId: req.user.userId } });
    if (!profile) return sendError(res, 'Profile not found', 404, 'NOT_FOUND');

    const row = await prisma.habitInsight.findFirst({ where: { profileId }, orderBy: { date: 'desc' } });
    const insight = row && {
      date: row.date.toISOString().slice(0, 10),
      habitSummary: row.habitSummary,
      clusterId: row.clusterId,
      clusterCount: row.clusterCount,
      suggestions: row.suggestions,
      modelVersion: row.modelVersion,
    };
    return sendSuccess(res, { insight });
  } catch (err) {
    console.error('latestInsight error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = { saveInsights, latestInsight };
