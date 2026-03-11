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

const sendError = (res, message, status = 400, code = 'BAD_REQUEST') => {
  return res.status(status).json({
    success: false,
    message,
    code
  });
};

module.exports = { sendSuccess, sendError };
