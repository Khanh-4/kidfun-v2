/**
 * Xác định thiết bị trẻ có đang online hay không.
 *
 * KHÔNG dùng cột `isOnline`. Trên Vercel không còn chỗ nào set nó về `false`:
 * `socketService` (chỗ set khi socket disconnect) đã chết cùng Socket.IO, còn
 * đoạn reset-lúc-boot trong `server.js` chỉ chạy khi NODE_ENV=production trên
 * một server chạy-dài. Hệ quả: máy trẻ hết pin hay mất mạng thì `isOnline` vẫn
 * là `true` vĩnh viễn.
 *
 * `lastSeen` trung thực hơn, nhưng CHỈ được heartbeat 60s của app trẻ cập nhật
 * (và chỉ khi có phiên đang chạy) — độ phân giải 60 giây. Nên nó trả lời được
 * "máy trẻ CÓ đang online" nhưng không trả lời được "máy trẻ KHÔNG đang
 * online": vừa bật máy bay 10 giây thì lastSeen vẫn còn mới tinh.
 *
 * Vì vậy trước khi xoá thiết bị, LUÔN phải DÒ CHỦ ĐỘNG (ghi `pingRequestedAt`,
 * app trẻ nhận qua Realtime rồi gọi lại server) và dùng `hasRespondedToPing()`
 * để chấm. KHÔNG có đường tắt kiểu "lastSeen còn mới nên chắc đang online":
 * cách đó đã sai hai lần (ngưỡng 3 phút ở PR #294, 75 giây ở PR #295) vì máy
 * trẻ có thể mất mạng ngay giây sau lần liên lạc cuối.
 *
 * Việc CHỜ trong lúc dò thuộc về app phụ huynh, không phải server: giữ một
 * request serverless mở để poll DB vừa đốt compute vừa làm màn hình đứng im.
 * Xem deviceController.startLivenessProbe / getLiveness.
 */

const HEARTBEAT_INTERVAL_MS = 60 * 1000;

/**
 * Máy trẻ đã trả lời ping chưa?
 *
 * Chấm bằng cách so `lastSeen` hiện tại với `lastSeen` GỐC (giá trị đọc được
 * ngay trước khi dò), chứ KHÔNG so với đồng hồ lúc bắt đầu dò. Lý do: server
 * mất 1-3 giây truy vấn thiết bị trước khi kịp ghi `pingRequestedAt`, nên máy
 * trẻ hoàn toàn có thể gọi tới trong khoảng đó — dùng mốc đồng hồ thì câu trả
 * lời hợp lệ ấy bị tính là "cũ" và thiết bị đang online bị báo mất kết nối.
 * (Gặp thật khi test lần đầu, 2026-09-15.)
 *
 * @param {Date|string|null} lastSeen       giá trị vừa đọc
 * @param {Date|string|null} baselineLastSeen giá trị trước khi dò
 * @returns {boolean}
 */
function hasRespondedToPing(lastSeen, baselineLastSeen) {
  if (!lastSeen) return false;
  if (!baselineLastSeen) return true; // trước không có, giờ có = vừa liên lạc
  return new Date(lastSeen).getTime() > new Date(baselineLastSeen).getTime();
}

/**
 * Số phút (làm tròn xuống) kể từ lần cuối thấy thiết bị, để hiển thị cho phụ
 * huynh. Tính ở server thay vì để mobile tự trừ, vì đồng hồ máy phụ huynh có
 * thể lệch.
 *
 * @param {Date|string|null} lastSeen
 * @param {Date} [now]
 * @returns {number|null} null khi chưa từng có heartbeat.
 */
function minutesSinceLastSeen(lastSeen, now = new Date()) {
  if (!lastSeen) return null;

  const elapsedMs = now.getTime() - new Date(lastSeen).getTime();
  if (elapsedMs < 0) return 0;

  return Math.floor(elapsedMs / 60000);
}

module.exports = {
  hasRespondedToPing,
  minutesSinceLastSeen,
  HEARTBEAT_INTERVAL_MS,
};
