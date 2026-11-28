// Quy tắc đồng bộ cờ khoá native (KidFunService) với nguồn sự thật là server.
//
// Sự cố 28/11: màn hình tắt lúc 21:59 → app xuống nền hẹn khoá native theo
// đồng hồ thật (≈00:25), dù server đã ngừng đếm giờ khi tắt màn hình. Native
// tự khoá lúc nửa đêm, Flutter không hề biết; sáng hôm sau màn hình bật lại
// chỉ khởi động lại đồng hồ đếm ngược → máy bị khoá mãi tới khi cài lại app.

/// Native đang khoá ngầm (Flutter không hiện màn hình hết giờ) nhưng server
/// báo vẫn còn giờ hoặc đã tắt giới hạn → phải gỡ cờ native.
bool shouldReleaseNativeLock({
  required bool nativeLocked,
  required bool timeUpShowing,
  required bool limitEnabled,
  required int remainingSeconds,
}) {
  if (!nativeLocked || timeUpShowing) return false;
  return !limitEnabled || remainingSeconds > 0;
}

/// Chỉ hẹn khoá native khi giờ thật sự đang trôi: màn hình tắt thì server đã
/// tạm dừng đếm, hẹn khoá theo đồng hồ lúc đó sẽ khoá oan.
bool shouldScheduleNativeLock({
  required bool limitEnabled,
  required bool screenOff,
  required DateTime? endTime,
  required DateTime now,
}) {
  if (!limitEnabled || screenOff || endTime == null) return false;
  return endTime.isAfter(now);
}
