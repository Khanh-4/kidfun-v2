/**
 * Chuẩn hóa response format cho tất cả API
 *
 * Success: { success: true, data: { ... } }
 * Error:   { success: false, message: "...", code: "ERROR_CODE" }
 */

const sendSuccess = (res, data, status = 200) => {
  return res.status(status).json({
    success: true,
    data
  });
};

const sendError = (res, message, status = 400, code = 'BAD_REQUEST', data = null) => {
  return res.status(status).json({
    success: false,
    message,
    code,
    // Một số lỗi cần mang theo dữ liệu để client dựng đúng thông báo (ví dụ
    // DEVICE_OFFLINE trả lastSeen để app phụ huynh hiện "online lần cuối X phút
    // trước"). Bỏ hẳn field khi không có để không đổi shape response cũ.
    ...(data ? { data } : {})
  });
};

module.exports = { sendSuccess, sendError };
