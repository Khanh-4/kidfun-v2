const { computeSchoolMode } = require('../../src/utils/schoolMode');

// 2026-11-10 là thứ Ba (dayOfWeek 2). Giờ VN = UTC+7.
const vn = (hhmm, date = '2026-11-10') => new Date(`${date}T${hhmm}:00+07:00`);

const baseSchedule = (over = {}) => ({
  isEnabled: true,
  templateStartTime: '07:00',
  templateEndTime: '11:30',
  daySchedules: [],
  allowedApps: [{ packageName: 'com.edu.app' }],
  manualOverride: null,
  overrideUntil: null,
  ...over,
});

describe('computeSchoolMode', () => {
  it('chưa cấu hình lịch → tắt', () => {
    expect(computeSchoolMode(null, vn('08:00'))).toEqual({ isActive: false, allowedApps: [] });
  });

  it('trong khung giờ → bật, kèm khung giờ hôm nay để máy trẻ tự tính', () => {
    expect(computeSchoolMode(baseSchedule(), vn('08:00'))).toEqual({
      isActive: true,
      reason: 'SCHEDULED',
      serverTime: vn('08:00').toISOString(),
      scheduleDate: '2026-11-10',
      startTime: '07:00',
      endTime: '11:30',
      allowedApps: [{ packageName: 'com.edu.app' }],
    });
  });

  it('trước giờ học → tắt nhưng VẪN gửi khung giờ (máy trẻ tự bật lúc 07:00)', () => {
    const r = computeSchoolMode(baseSchedule(), vn('06:58'));
    expect(r.isActive).toBe(false);
    expect(r).toMatchObject({ scheduleDate: '2026-11-10', startTime: '07:00', endTime: '11:30' });
    expect(r.allowedApps).toHaveLength(1);
  });

  it('đúng giờ kết thúc → tắt (khung [start, end))', () => {
    expect(computeSchoolMode(baseSchedule(), vn('11:30')).isActive).toBe(false);
  });

  it('ngày theo giờ VN, không theo UTC (01:00 VN thứ Tư = 18:00 UTC thứ Ba)', () => {
    const s = baseSchedule({ daySchedules: [{ dayOfWeek: 3, startTime: '00:30', endTime: '02:00', isEnabled: true }] });
    const r = computeSchoolMode(s, vn('01:00', '2026-11-11'));
    expect(r).toMatchObject({ isActive: true, scheduleDate: '2026-11-11', startTime: '00:30' });
  });

  it('hôm nay bị tắt trong lịch tuần → không có khung giờ', () => {
    const s = baseSchedule({ daySchedules: [{ dayOfWeek: 2, startTime: '07:00', endTime: '11:30', isEnabled: false }] });
    expect(computeSchoolMode(s, vn('08:00'))).toMatchObject({ isActive: false, startTime: null, endTime: null });
  });

  it('lịch bị tắt hẳn → tắt, có scheduleDate, không khung giờ', () => {
    expect(computeSchoolMode(baseSchedule({ isEnabled: false }), vn('08:00'))).toEqual({
      isActive: false,
      reason: 'DISABLED',
      serverTime: vn('08:00').toISOString(),
      scheduleDate: '2026-11-10',
      startTime: null,
      endTime: null,
      allowedApps: [],
    });
  });

  it('bật ngay (FORCE_ON) còn hạn → bật, gửi hạn override + khung giờ để dùng khi hết hạn', () => {
    const until = vn('09:00');
    const r = computeSchoolMode(baseSchedule({ manualOverride: 'FORCE_ON', overrideUntil: until }), vn('06:00'));
    expect(r).toMatchObject({
      isActive: true,
      reason: 'MANUAL_OVERRIDE',
      overrideMode: 'FORCE_ON',
      overrideUntil: until.toISOString(),
      startTime: '07:00',
      endTime: '11:30',
    });
  });

  it('tắt ngay (FORCE_OFF) trong giờ học → tắt', () => {
    const r = computeSchoolMode(baseSchedule({ manualOverride: 'FORCE_OFF', overrideUntil: vn('09:00') }), vn('08:00'));
    expect(r).toMatchObject({ isActive: false, overrideMode: 'FORCE_OFF' });
  });

  it('override đã hết hạn → theo lịch, không gửi override', () => {
    const r = computeSchoolMode(baseSchedule({ manualOverride: 'FORCE_OFF', overrideUntil: vn('07:30') }), vn('08:00'));
    expect(r.isActive).toBe(true);
    expect(r.overrideMode).toBeUndefined();
  });
});
