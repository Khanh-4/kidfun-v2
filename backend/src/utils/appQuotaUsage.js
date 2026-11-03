// Usage từng app trong NGÀY HẠN MỨC (06:00 → 05:59 hôm sau, giờ VN).
//
// AppUsageLog lưu tổng theo ngày lịch VN (cập nhật ~5 phút/lần) nên không cắt
// được ở 06:00. Cách ghép: log ngày D0 − phần 00:00–06:00 của D0 (lấy từ
// AppUsageHourly) + log ngày D1 (chỉ có khi đang ở 00:00–05:59 hôm sau).
// Thiếu dữ liệu theo giờ thì phần sáng sớm bị tính vào ngày mới — lệch về
// phía chặt hơn, không cho trẻ thêm giờ.
const { vnQuotaDayRange, VN_OFFSET_MS } = require('./vnTime');

/** Khoá `date` của AppUsageLog (UTC 00:00 của ngày lịch VN) cho ngày hạn mức chứa `at`. */
function quotaLogDate(at = new Date()) {
  const { startOfDay } = vnQuotaDayRange(at);
  const vn = new Date(startOfDay.getTime() + VN_OFFSET_MS);
  return new Date(Date.UTC(vn.getUTCFullYear(), vn.getUTCMonth(), vn.getUTCDate()));
}

/**
 * @param {{packageName: string, date: Date, usageSeconds: number}[]} logs AppUsageLog của D0 và D1
 * @param {{packageName: string, usageSeconds: number}[]} earlyHourly AppUsageHourly trong 00:00–06:00 VN của D0
 * @param {Date} d0 khoá date của ngày hạn mức (quotaLogDate)
 * @returns {Map<string, number>} packageName → giây đã dùng
 */
function quotaAppUsageSeconds(logs, earlyHourly, d0) {
  const early = new Map();
  for (const h of earlyHourly) {
    early.set(h.packageName, (early.get(h.packageName) || 0) + h.usageSeconds);
  }
  const used = new Map();
  for (const l of logs) {
    const isD0 = l.date.getTime() === d0.getTime();
    const secs = isD0 ? Math.max(0, l.usageSeconds - (early.get(l.packageName) || 0)) : l.usageSeconds;
    used.set(l.packageName, (used.get(l.packageName) || 0) + secs);
  }
  return used;
}

module.exports = { quotaLogDate, quotaAppUsageSeconds };
