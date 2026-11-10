const { VN_OFFSET_MS } = require('./vnTime');

/** Ngày "YYYY-MM-DD", giờ "HH:mm" và thứ (0 = CN) theo giờ VN tại `at`. */
function vnClock(at) {
  const iso = new Date(at.getTime() + VN_OFFSET_MS).toISOString();
  return { date: iso.slice(0, 10), time: iso.slice(11, 16), dayOfWeek: new Date(iso).getUTCDay() };
}

/**
 * Trạng thái Chế độ đi học gửi cho máy trẻ.
 *
 * `isActive` là trạng thái lúc fetch (APK cũ chỉ dùng trường này). Ngoài ra luôn
 * gửi khung giờ HÔM NAY (`scheduleDate`, `startTime`, `endTime`) và override còn
 * hạn (`overrideMode`, `overrideUntil`) để native tự tính theo giờ thực — trước
 * đây lúc tới giờ bắt đầu/kết thúc máy trẻ chậm tới 5 phút (chờ lượt đồng bộ).
 * `startTime`/`endTime` = null nghĩa là hôm nay không có giờ học. `serverTime` để
 * native tính giờ theo server, không theo đồng hồ máy trẻ.
 *
 * @param {object|null} s SchoolSchedule kèm daySchedules, allowedApps
 * @param {Date} now
 */
function computeSchoolMode(s, now = new Date()) {
  if (!s) return { isActive: false, allowedApps: [] };

  const { date, time, dayOfWeek } = vnClock(now);
  const day = s.daySchedules.find((d) => d.dayOfWeek === dayOfWeek);
  const start = day?.startTime || s.templateStartTime;
  const end = day?.endTime || s.templateEndTime;
  const hasClassToday = !!(s.isEnabled && (day ? day.isEnabled : true) && start && end);

  const window = {
    // Mốc giờ server: native neo vào đồng hồ đơn điệu, trẻ chỉnh giờ máy không lách được.
    serverTime: now.toISOString(),
    scheduleDate: date,
    startTime: hasClassToday ? start : null,
    endTime: hasClassToday ? end : null,
  };

  if (s.manualOverride && s.overrideUntil && now < s.overrideUntil) {
    return {
      isActive: s.manualOverride === 'FORCE_ON',
      reason: 'MANUAL_OVERRIDE',
      ...window,
      overrideMode: s.manualOverride,
      overrideUntil: s.overrideUntil.toISOString(),
      allowedApps: s.allowedApps,
    };
  }

  if (!s.isEnabled) {
    return { isActive: false, reason: 'DISABLED', ...window, allowedApps: [] };
  }

  return {
    isActive: hasClassToday && time >= start && time < end,
    reason: 'SCHEDULED',
    ...window,
    allowedApps: s.allowedApps,
  };
}

module.exports = { computeSchoolMode };
