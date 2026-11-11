const { effectiveDailyLimit, DEFAULT_DAILY_LIMIT_MINUTES } = require('../../src/utils/dailyLimit');

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const NOW = new Date('2026-11-11T08:00:00Z');

// Lỗi test 11/11: phụ huynh đặt hạn mức 0 phút + duyệt thêm 15 phút. today-limit
// trả 158s còn lại, nhưng heartbeat trả 7298s vì `0 || 120` = 120 → bộ đếm nhảy ~2 tiếng.
describe('effectiveDailyLimit', () => {
  it('hạn mức 0 phút là 0, không bị đổi thành mặc định', () => {
    expect(effectiveDailyLimit({ dailyLimitMinutes: 0, limitMinutes: 0 }, NOW)).toBe(0);
  });

  it('hạn mức 0 phút không rơi về cột limitMinutes cũ', () => {
    expect(effectiveDailyLimit({ dailyLimitMinutes: 0, limitMinutes: 350 }, NOW)).toBe(0);
  });

  it('chưa có bản ghi hạn mức → mặc định', () => {
    expect(effectiveDailyLimit(null, NOW)).toBe(DEFAULT_DAILY_LIMIT_MINUTES);
    expect(effectiveDailyLimit(undefined, NOW)).toBe(DEFAULT_DAILY_LIMIT_MINUTES);
  });

  it('hạn mức thường → trả đúng số phút', () => {
    expect(effectiveDailyLimit({ dailyLimitMinutes: 350 }, NOW)).toBe(350);
  });

  describe('giảm dần', () => {
    const gradual = (startOffsetWeeks) => ({
      dailyLimitMinutes: 120,
      isGradual: true,
      gradualTarget: 60,
      gradualWeeks: 4,
      gradualStartDate: new Date(NOW.getTime() - startOffsetWeeks * WEEK_MS),
    });

    it('tuần đầu → chưa giảm', () => {
      expect(effectiveDailyLimit(gradual(0), NOW)).toBe(120);
    });

    it('đã qua 2/4 tuần → giảm một nửa khoảng cách', () => {
      expect(effectiveDailyLimit(gradual(2), NOW)).toBe(90);
    });

    it('hết thời gian giảm → bằng mục tiêu', () => {
      expect(effectiveDailyLimit(gradual(5), NOW)).toBe(60);
    });

    it('thiếu thông tin giảm dần → dùng hạn mức gốc', () => {
      expect(effectiveDailyLimit({ ...gradual(2), gradualWeeks: null }, NOW)).toBe(120);
    });
  });
});
