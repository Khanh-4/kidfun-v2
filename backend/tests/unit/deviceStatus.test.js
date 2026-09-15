const {
  isDeviceFresh,
  hasRespondedToPing,
  minutesSinceLastSeen,
} = require('../../src/utils/deviceStatus');

// Lỗi từng gặp thật (2026-09-15): phụ huynh bấm "Xoá thiết bị" lúc máy trẻ đang
// mất mạng, server xoá luôn mà không cảnh báo gì. Không dùng cột `isOnline`:
// trên Vercel không còn chỗ nào set nó về false nên máy trẻ hết pin vẫn mang
// isOnline = true vĩnh viễn (xem src/utils/deviceStatus.js).
//
// Vòng 1 (2026-09-15) dùng ngưỡng 3 phút không thấy heartbeat. Log production
// cho thấy nó KHÔNG đủ: bạn test liên kết máy lúc 17:49:54 rồi bật máy bay và
// xoá lúc 17:52:02 — mới 2 phút 08 giây nên guard cho qua. Vì `lastSeen` chỉ
// được heartbeat 60s cập nhật, MỌI ngưỡng kiểu này đều mù trong vòng 1 phút
// đầu sau khi mất mạng. Nay: tươi < 75s thì chắc chắn online, ngoài ra phải
// DÒ CHỦ ĐỘNG (ghi pingRequestedAt → app trẻ trả lời → lastSeen mới).
describe('isDeviceFresh', () => {
  const now = new Date('2026-09-15T10:00:00Z');

  test('heartbeat vừa chạy 30 giây trước → chắc chắn đang online', () => {
    // Arrange
    const lastSeen = new Date('2026-09-15T09:59:30Z');

    // Act
    const fresh = isDeviceFresh(lastSeen, now);

    // Assert
    expect(fresh).toBe(true);
  });

  test('đúng 74 giây (trong 1 nhịp heartbeat + lề) vẫn coi là tươi', () => {
    // Arrange — heartbeat 60s cộng lề cho độ trễ Vercel 1-4s
    const lastSeen = new Date('2026-09-15T09:58:46Z');

    // Act
    const fresh = isDeviceFresh(lastSeen, now);

    // Assert
    expect(fresh).toBe(true);
  });

  test('quá 75 giây thì KHÔNG còn chắc chắn — phải dò lại mới biết', () => {
    // Arrange
    const lastSeen = new Date('2026-09-15T09:58:44Z');

    // Act
    const fresh = isDeviceFresh(lastSeen, now);

    // Assert
    expect(fresh).toBe(false);
  });

  test('chưa từng có heartbeat (lastSeen null) thì không tươi', () => {
    // Arrange
    const lastSeen = null;

    // Act
    const fresh = isDeviceFresh(lastSeen, now);

    // Assert
    expect(fresh).toBe(false);
  });

  test('lastSeen ở tương lai (lệch đồng hồ) vẫn tính là tươi', () => {
    // Arrange — máy trẻ báo giờ nhanh hơn server vài giây
    const lastSeen = new Date('2026-09-15T10:00:20Z');

    // Act
    const fresh = isDeviceFresh(lastSeen, now);

    // Assert
    expect(fresh).toBe(true);
  });
});

describe('hasRespondedToPing', () => {
  // Mốc so sánh là lastSeen GỐC trước khi dò, không phải đồng hồ lúc bắt đầu
  // dò — server mất 1-3 giây mới ghi được pingRequestedAt, máy trẻ trả lời
  // trong khoảng đó vẫn phải được tính là còn sống.
  const baseline = new Date('2026-09-15T09:52:00Z');

  test('lastSeen mới hơn giá trị gốc → máy trẻ đã trả lời', () => {
    // Arrange
    const lastSeen = new Date('2026-09-15T10:00:02Z');

    // Act
    const responded = hasRespondedToPing(lastSeen, baseline);

    // Assert
    expect(responded).toBe(true);
  });

  test('lastSeen y nguyên như trước lúc dò → chưa trả lời', () => {
    // Arrange
    const lastSeen = new Date('2026-09-15T09:52:00Z');

    // Act
    const responded = hasRespondedToPing(lastSeen, baseline);

    // Assert
    expect(responded).toBe(false);
  });

  test('lastSeen null → chưa trả lời', () => {
    // Arrange / Act
    const responded = hasRespondedToPing(null, baseline);

    // Assert
    expect(responded).toBe(false);
  });

  test('trước không có lastSeen, giờ có → vừa liên lạc lần đầu', () => {
    // Arrange / Act
    const responded = hasRespondedToPing(new Date('2026-09-15T10:00:02Z'), null);

    // Assert
    expect(responded).toBe(true);
  });
});

describe('minutesSinceLastSeen', () => {
  const now = new Date('2026-09-15T10:00:00Z');

  test('làm tròn xuống số phút đã trôi qua', () => {
    // Arrange
    const lastSeen = new Date('2026-09-15T09:54:30Z'); // 5 phút 30 giây

    // Act
    const minutes = minutesSinceLastSeen(lastSeen, now);

    // Assert
    expect(minutes).toBe(5);
  });

  test('trả về null khi chưa từng có heartbeat', () => {
    // Arrange
    const lastSeen = null;

    // Act
    const minutes = minutesSinceLastSeen(lastSeen, now);

    // Assert
    expect(minutes).toBeNull();
  });

  test('không trả số âm khi lastSeen ở tương lai', () => {
    // Arrange
    const lastSeen = new Date('2026-09-15T10:00:20Z');

    // Act
    const minutes = minutesSinceLastSeen(lastSeen, now);

    // Assert
    expect(minutes).toBe(0);
  });
});
