const { vnDayRange } = require('../../src/utils/vnTime');

// Lỗi từng gặp thật (2026-09-09): trẻ xin thêm giờ lúc 01:40 giờ VN, phụ huynh
// duyệt lúc 01:41, nhưng app trẻ vẫn về đúng giới hạn ngày. Cách tính mốc ngày
// cũ dựng cửa sổ [2026-09-10T00:00Z, 2026-09-10T23:59Z] trong khi bản ghi nằm ở
// 2026-09-09T18:40Z — nằm ngoài cửa sổ nên bonus đọc ra 0. Bug chỉ tái hiện
// trong khung 00:00–06:59 giờ VN nên rất dễ lọt qua các lần test ban ngày.
describe('vnDayRange', () => {
  test('mốc ngày VN là 17:00Z hôm trước cho tới 16:59:59Z hôm sau', () => {
    // Arrange
    const at = new Date('2026-09-09T18:41:08Z'); // 01:41 ngày 10/09 giờ VN

    // Act
    const { startOfDay, endOfDay } = vnDayRange(at);

    // Assert
    expect(startOfDay.toISOString()).toBe('2026-09-09T17:00:00.000Z');
    expect(endOfDay.toISOString()).toBe('2026-09-10T16:59:59.999Z');
  });

  test('bản ghi tạo ngay trước đó nằm TRONG ngày VN hiện tại', () => {
    // Arrange
    const at = new Date('2026-09-09T18:41:08Z');
    const createdAt = new Date('2026-09-09T18:40:53Z'); // req #201 của lần test thật

    // Act
    const { startOfDay, endOfDay } = vnDayRange(at);

    // Assert
    expect(createdAt >= startOfDay && createdAt <= endOfDay).toBe(true);
  });

  test('thời điểm ngay trước nửa đêm VN thuộc về ngày hôm trước', () => {
    // Arrange
    const at = new Date('2026-09-09T16:59:59Z'); // 23:59:59 ngày 09/09 giờ VN

    // Act
    const { startOfDay, dayOfWeek } = vnDayRange(at);

    // Assert
    expect(startOfDay.toISOString()).toBe('2026-09-08T17:00:00.000Z');
    expect(dayOfWeek).toBe(3); // thứ Tư 09/09
  });

  test('thời điểm ngay sau nửa đêm VN sang ngày mới', () => {
    // Arrange
    const at = new Date('2026-09-09T17:00:00Z'); // 00:00:00 ngày 10/09 giờ VN

    // Act
    const { startOfDay, dayOfWeek } = vnDayRange(at);

    // Assert
    expect(startOfDay.toISOString()).toBe('2026-09-09T17:00:00.000Z');
    expect(dayOfWeek).toBe(4); // thứ Năm 10/09
  });

  test('dayOfWeek theo giờ VN, không theo UTC', () => {
    // Arrange — 22:30Z Chủ nhật ở UTC nhưng đã là 05:30 thứ Hai ở VN
    const at = new Date('2026-09-06T22:30:00Z');

    // Act
    const { dayOfWeek } = vnDayRange(at);

    // Assert
    expect(dayOfWeek).toBe(1);
    expect(at.getUTCDay()).toBe(0); // UTC vẫn là Chủ nhật
  });

  test('kết quả không phụ thuộc timezone của server', () => {
    // Arrange
    const at = new Date('2026-09-09T18:41:08Z');
    const original = process.env.TZ;

    // Act
    process.env.TZ = 'America/New_York';
    const fromNy = vnDayRange(at);
    process.env.TZ = 'Asia/Ho_Chi_Minh';
    const fromVn = vnDayRange(at);
    process.env.TZ = original;

    // Assert
    expect(fromNy.startOfDay.toISOString()).toBe(fromVn.startOfDay.toISOString());
    expect(fromNy.dayOfWeek).toBe(fromVn.dayOfWeek);
  });
});
