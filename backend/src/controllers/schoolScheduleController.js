const prisma = require('../utils/prisma');
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { notifyChildPolicyUpdated } = require('../services/childPolicyNotifier');
const { computeSchoolMode } = require('../utils/schoolMode');

// Báo máy trẻ lịch học đổi qua FCM (bản Socket.IO cũ không gửi gì trên Vercel).
const notifyChildScheduleUpdated = (profileId) => notifyChildPolicyUpdated(profileId, 'SCHOOL');

// GET /api/profiles/:id/school-schedule
const getSchedule = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const schedule = await prisma.schoolSchedule.findUnique({
      where: { profileId },
      include: { daySchedules: true, allowedApps: true },
    });
    return sendSuccess(res, { schedule });
  } catch (err) {
    console.error('getSchedule error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// PUT /api/profiles/:id/school-schedule — upsert template + day overrides + allowed apps
const upsertSchedule = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const {
      isEnabled,
      templateStartTime,
      templateEndTime,
      dayOverrides,  // [{ dayOfWeek, startTime, endTime, isEnabled }]
      allowedApps,   // [{ packageName, appName }]
    } = req.body;

    // Upsert schedule record
    const schedule = await prisma.schoolSchedule.upsert({
      where: { profileId },
      update: { isEnabled: isEnabled ?? true, templateStartTime, templateEndTime },
      create: { profileId, isEnabled: isEnabled ?? true, templateStartTime, templateEndTime },
    });

    // Replace day overrides
    await prisma.schoolDaySchedule.deleteMany({ where: { scheduleId: schedule.id } });
    if (dayOverrides && dayOverrides.length > 0) {
      await prisma.schoolDaySchedule.createMany({
        data: dayOverrides.map((d) => ({
          scheduleId: schedule.id,
          dayOfWeek: parseInt(d.dayOfWeek),
          startTime: d.startTime,
          endTime: d.endTime,
          isEnabled: d.isEnabled ?? true,
        })),
      });
    }

    // Replace allowed apps
    await prisma.allowedSchoolApp.deleteMany({ where: { scheduleId: schedule.id } });
    if (allowedApps && allowedApps.length > 0) {
      await prisma.allowedSchoolApp.createMany({
        data: allowedApps.map((a) => ({
          scheduleId: schedule.id,
          packageName: a.packageName,
          appName: a.appName || null,
        })),
      });
    }

    await notifyChildScheduleUpdated(profileId);

    const updated = await prisma.schoolSchedule.findUnique({
      where: { profileId },
      include: { daySchedules: true, allowedApps: true },
    });
    return sendSuccess(res, { schedule: updated });
  } catch (err) {
    console.error('upsertSchedule error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// POST /api/profiles/:id/school-schedule/override — manual override
const manualOverride = async (req, res) => {
  try {
    const profileId = parseInt(req.params.id);
    const { action, durationMinutes } = req.body;
    // action: "FORCE_ON" | "FORCE_OFF" | "CLEAR"

    if (!['FORCE_ON', 'FORCE_OFF', 'CLEAR'].includes(action)) {
      return sendError(res, 'action must be FORCE_ON, FORCE_OFF, or CLEAR', 400, 'INVALID_DATA');
    }

    const schedule = await prisma.schoolSchedule.findUnique({ where: { profileId } });
    if (!schedule) {
      return sendError(res, 'School schedule not configured for this profile', 404, 'NOT_FOUND');
    }

    const overrideUntil = action === 'CLEAR'
      ? null
      : new Date(Date.now() + (durationMinutes || 60) * 60 * 1000);

    const updated = await prisma.schoolSchedule.update({
      where: { profileId },
      data: {
        manualOverride: action === 'CLEAR' ? null : action,
        overrideUntil,
      },
    });

    await notifyChildScheduleUpdated(profileId);
    return sendSuccess(res, { schedule: updated });
  } catch (err) {
    console.error('manualOverride error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

// GET /api/child/school-mode?deviceCode=XXX — trạng thái School Mode hiện tại
const getChildSchoolMode = async (req, res) => {
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

    return sendSuccess(res, computeSchoolMode(device.profile.schoolSchedule));
  } catch (err) {
    console.error('getChildSchoolMode error:', err);
    return sendError(res, err.message, 500, 'INTERNAL_ERROR');
  }
};

module.exports = { getSchedule, upsertSchedule, manualOverride, getChildSchoolMode };
