const {
  hasRespondedToPing,
  minutesSinceLastSeen,
} = require('../../src/utils/deviceStatus');

// Lỗi từng gặp thật (2026-09-15): phụ huynh bấm "Xoá thiết bị" lúc máy trẻ đang
// mất mạng, server xoá luôn mà không cảnh báo gì. Không dùng cột `isOnline`:
// trên Vercel không còn chỗ nào set nó về false nên máy trẻ hết pin vẫn mang
// isOnline = true vĩnh viễn (xem src/utils/deviceStatus.js).
//
// Đã sai HAI lần vì cùng một giả định: suy ra "đang online" từ việc lastSeen
// còn mới. Ngưỡng 3 phút (PR #294) trượt khi máy liên kết 17:49:54 rồi bị xoá
// lúc 17:52:02; ngưỡng 75 giây (PR #295) trượt khi máy trẻ vừa heartbeat xong
// mới bật máy bay (log 19:43:45 — DELETE trả thẳng 200, không qua bước dò).
// `lastSeen` chỉ được cập nhật mỗi 60 giây nên không bao giờ phản ánh được
// việc máy trẻ vừa mất mạng. Kết luận: KHÔNG có đường tắt, luôn phải dò chủ
// động và chấm bằng hasRespondedToPing().
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
