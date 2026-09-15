const {
  isDeviceOffline,
  minutesSinceLastSeen,
  DEVICE_OFFLINE_THRESHOLD_MS,
} = require('../../src/utils/deviceStatus');

// Lỗi từng gặp thật (2026-09-15): phụ huynh bấm "Xoá thiết bị" lúc máy trẻ đang
// mất mạng, server xoá luôn mà không cảnh báo gì. Không thể dựa vào cột
// `isOnline` để biết trẻ có online hay không: trên Vercel không còn chỗ nào set
// nó về false (socketService đã chết cùng Socket.IO, reset-lúc-boot bị chặn
// riêng cho Vercel), nên máy trẻ hết pin vẫn mang isOnline = true vĩnh viễn.
// Tín hiệu trung thực duy nhất là `lastSeen`, do heartbeat 60s cập nhật.
describe('isDeviceOffline', () => {
  const now = new Date('2026-09-15T10:00:00Z');

  test('heartbeat vừa chạy 30 giây trước thì vẫn là online', () => {
    // Arrange
    const lastSeen = new Date('2026-09-15T09:59:30Z');

    // Act
    const offline = isDeviceOffline(lastSeen, now);

    // Assert
    expect(offline).toBe(false);
  });

  test('bỏ lỡ 2 nhịp heartbeat (2 phút 59 giây) vẫn chưa coi là offline', () => {
    // Arrange — mạng chập chờn vài nhịp không được phép báo nhầm
    const lastSeen = new Date('2026-09-15T09:57:01Z');

    // Act
    const offline = isDeviceOffline(lastSeen, now);

    // Assert
    expect(offline).toBe(false);
  });

  test('đúng mốc 3 phút chẵn vẫn tính là online (chỉ vượt mới offline)', () => {
    // Arrange
    const lastSeen = new Date(now.getTime() - DEVICE_OFFLINE_THRESHOLD_MS);

    // Act
    const offline = isDeviceOffline(lastSeen, now);

    // Assert
    expect(offline).toBe(false);
  });

  test('quá 3 phút không thấy heartbeat thì là offline', () => {
    // Arrange
    const lastSeen = new Date('2026-09-15T09:56:59Z');

    // Act
    const offline = isDeviceOffline(lastSeen, now);

    // Assert
    expect(offline).toBe(true);
  });

  test('chưa từng có heartbeat (lastSeen null) thì là offline', () => {
    // Arrange
    const lastSeen = null;

    // Act
    const offline = isDeviceOffline(lastSeen, now);

    // Assert
    expect(offline).toBe(true);
  });

  test('lastSeen ở tương lai (lệch đồng hồ) không được coi là offline', () => {
    // Arrange — máy trẻ báo giờ nhanh hơn server vài giây
    const lastSeen = new Date('2026-09-15T10:00:20Z');

    // Act
    const offline = isDeviceOffline(lastSeen, now);

    // Assert
    expect(offline).toBe(false);
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
