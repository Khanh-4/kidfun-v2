const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');

// PUT /api/profiles/:id/time-limits/gradual
// Parent bật gradual reduction cho 1 ngày cụ thể hoặc tất cả các ngày
const setGradualReduction = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { dayOfWeek, targetMinutes, weeks } = req.body;

    if (targetMinutes == null || !weeks) {
      return sendError(res, 'targetMinutes and weeks are required', 400, 'MISSING_FIELDS');
    }

    if (weeks <= 0 || targetMinutes < 0) {
      return sendError(res, 'weeks must be > 0 and targetMinutes must be >= 0', 400, 'INVALID_VALUES');
    }

    const where =
      dayOfWeek != null
        ? { profileId, dayOfWeek: parseInt(dayOfWeek) }
        : null;

    const data = {
      isGradual: true,
      gradualTarget: parseInt(targetMinutes),
      gradualWeeks: parseInt(weeks),
      gradualStartDate: new Date(),
    };

    if (where) {
      // Áp dụng cho 1 ngày cụ thể
      await prisma.timeLimit.updateMany({ where, data });
    } else {
      // Áp dụng cho tất cả 7 ngày trong tuần của profile
      await prisma.timeLimit.updateMany({ where: { profileId }, data });
    }

    return sendSuccess(res, { message: 'Gradual reduction enabled' });
  } catch (err) {
    console.error('setGradualReduction error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// PUT /api/profiles/:id/time-limits/gradual/disable
const disableGradualReduction = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { dayOfWeek } = req.body;

    const where = dayOfWeek != null ? { profileId, dayOfWeek: parseInt(dayOfWeek) } : { profileId };

    await prisma.timeLimit.updateMany({
      where,
      data: {
        isGradual: false,
        gradualTarget: null,
        gradualWeeks: null,
        gradualStartDate: null,
      },
    });

    return sendSuccess(res, { message: 'Gradual reduction disabled' });
  } catch (err) {
    console.error('disableGradualReduction error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = { setGradualReduction, disableGradualReduction };
