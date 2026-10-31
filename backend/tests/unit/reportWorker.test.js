jest.mock('../../src/utils/prisma', () => ({}));
jest.mock('../../src/services/reportService', () => ({}));

const { vnYesterdayKey } = require('../../src/workers/reportWorker');

// Cron daily-reports chạy 17:05 UTC = 00:05 giờ VN. Trước đây lấy "hôm qua"
// theo ngày UTC nên báo cáo ghi vào hôm kia (lệch 1 ngày so với giờ VN).
describe('vnYesterdayKey', () => {
  test('lúc cron chạy (00:05 VN ngày 29/10) trả khoá ngày 28/10', () => {
    // Arrange
    const cronAt = new Date('2026-10-28T17:05:00Z');

    // Act
    const key = vnYesterdayKey(cronAt);

    // Assert
    expect(key.toISOString()).toBe('2026-10-28T00:00:00.000Z');
  });

  test('giữa ngày VN vẫn trả đúng hôm qua', () => {
    expect(vnYesterdayKey(new Date('2026-10-29T05:00:00Z')).toISOString()).toBe('2026-10-28T00:00:00.000Z');
  });

  test('khớp định dạng khoá periodStart của reportController (new Date("YYYY-MM-DD"))', () => {
    expect(vnYesterdayKey(new Date('2026-10-28T17:05:00Z')).getTime()).toBe(new Date('2026-10-28').getTime());
  });
});
