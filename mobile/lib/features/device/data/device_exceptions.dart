/// Server từ chối xoá thiết bị vì máy trẻ đang mất kết nối (HTTP 409,
/// `code = DEVICE_OFFLINE`).
///
/// App trẻ chỉ biết mình bị gỡ khi gọi được API, nên gỡ lúc nó offline nghĩa là
/// nó còn khoá máy/giám sát tiếp cho tới khi có mạng trở lại. Phụ huynh cần
/// được hỏi lại trước khi chấp nhận điều đó — xem `?force=true` ở
/// `DeviceRepository.deleteDevice`.
class DeviceOfflineException implements Exception {
  /// Số phút kể từ heartbeat cuối cùng, do server tính (đồng hồ máy phụ huynh
  /// có thể lệch). `null` khi thiết bị chưa từng kết nối lần nào.
  final int? minutesSinceLastSeen;

  const DeviceOfflineException({this.minutesSinceLastSeen});

  @override
  String toString() =>
      'DeviceOfflineException(minutesSinceLastSeen: $minutesSinceLastSeen)';
}
