/**
 * Xác định thiết bị trẻ có đang online hay không, dựa trên `lastSeen`.
 *
 * KHÔNG dùng cột `isOnline` cho việc này. Trên Vercel không còn chỗ nào set nó
 * về `false`: `socketService` (chỗ set khi socket disconnect) đã chết cùng
 * Socket.IO, còn đoạn reset-lúc-boot trong `server.js` bị chặn riêng cho Vercel
 * vì module code chạy lại ở mọi cold start. Hệ quả: máy trẻ hết pin, mất mạng
 * hay bị kill app thì `isOnline` vẫn là `true` vĩnh viễn. Tín hiệu trung thực
 * duy nhất là `lastSeen`, được heartbeat 60s của app trẻ cập nhật.
 */

// 3 nhịp heartbeat. Rộng hơn 1-2 nhịp để mạng chập chờn hoặc một request Vercel
// chậm (1-4s) không làm thiết bị đang dùng bình thường bị báo là mất kết nối.
const HEARTBEAT_INTERVAL_MS = 60 * 1000;
const DEVICE_OFFLINE_THRESHOLD_MS = 3 * HEARTBEAT_INTERVAL_MS;

/**
 * @param {Date|string|null} lastSeen
 * @param {Date} [now]
 * @returns {boolean} true khi đã quá ngưỡng không thấy heartbeat.
 */
function isDeviceOffline(lastSeen, now = new Date()) {
  // Chưa từng có heartbeat nào — không có bằng chứng nào cho thấy máy trẻ đang
  // chạy, nên coi là offline.
  if (!lastSeen) return true;

  const elapsedMs = now.getTime() - new Date(lastSeen).getTime();
  return elapsedMs > DEVICE_OFFLINE_THRESHOLD_MS;
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
  // Đồng hồ máy trẻ chạy nhanh hơn server vài giây là chuyện thường — kẹp về 0
  // thay vì trả số âm.
  if (elapsedMs < 0) return 0;

  return Math.floor(elapsedMs / 60000);
}

module.exports = {
  isDeviceOffline,
  minutesSinceLastSeen,
  DEVICE_OFFLINE_THRESHOLD_MS,
  HEARTBEAT_INTERVAL_MS,
};
