const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { generateDailyReport, generateWeeklyReport } = require('../services/reportService');

// GET /api/profiles/:id/reports/daily?date=YYYY-MM-DD
exports.getDailyReport = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const dateStr = req.query.date || new Date().toISOString().split('T')[0];
    const date = new Date(dateStr);
    date.setHours(0, 0, 0, 0);

    let report = await prisma.reportSnapshot.findUnique({
      where: {
        profileId_type_periodStart: { profileId, type: 'DAILY', periodStart: date },
      },
    });

    const isToday = isSameDay(date, new Date());
    if (!report || isToday) {
      report = await generateDailyReport(profileId, date);
    }

    return sendSuccess(res, { report });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

// GET /api/profiles/:id/reports/weekly?weekStart=YYYY-MM-DD
exports.getWeeklyReport = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    let monday;

    if (req.query.weekStart) {
      monday = new Date(req.query.weekStart);
    } else {
      monday = new Date();
      const diff = monday.getDay() === 0 ? 6 : monday.getDay() - 1;
      monday.setDate(monday.getDate() - diff);
    }
    monday.setHours(0, 0, 0, 0);

    let report = await prisma.reportSnapshot.findUnique({
      where: {
        profileId_type_periodStart: { profileId, type: 'WEEKLY', periodStart: monday },
      },
    });

    const now = new Date();
    const isThisWeek = monday.getTime() + 7 * 24 * 60 * 60 * 1000 > now.getTime();
    if (!report || isThisWeek) {
      report = await generateWeeklyReport(profileId, monday);
    }

    return sendSuccess(res, { report });
  } catch (err) {
    return sendError(res, err.message, 500);
  }
};

function isSameDay(d1, d2) {
  return d1.getFullYear() === d2.getFullYear() &&
    d1.getMonth() === d2.getMonth() &&
    d1.getDate() === d2.getDate();
}
