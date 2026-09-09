// Mốc thời gian theo giờ Việt Nam (UTC+7, không có DST).
//
// Trước đây mỗi chỗ tự tính bằng:
//   const vnNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
//   const startOfDay = new Date(vnNow); startOfDay.setHours(0, 0, 0, 0);
//
// Cách đó SAI khi dùng để query DB. `toLocaleString` trả chuỗi giờ tường VN,
// rồi `new Date(...)` parse chuỗi đó theo timezone của server (UTC trên Vercel)
// — nên vnNow là một Date bị dịch +7h so với thời điểm thật, và startOfDay/
// endOfDay dựng từ nó cũng lệch +7h so với cột DateTime trong DB (lưu UTC thật).
//
// Hậu quả: mỗi ngày trong khung 00:00–06:59 giờ VN, cửa sổ query nằm hoàn toàn
// ở tương lai so với dữ liệu vừa ghi, nên usage và giờ được cộng thêm đều đọc
// ra 0 — trẻ xin thêm giờ, phụ huynh duyệt xong, app vẫn về đúng giới hạn ngày.
const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Khoảng [startOfDay, endOfDay] của NGÀY THEO GIỜ VN chứa thời điểm `at`,
 * trả về Date UTC thật để so trực tiếp với cột DateTime của Prisma.
 * Kèm `dayOfWeek` theo giờ VN (0 = Chủ nhật) để tra TimeLimit.
 */
function vnDayRange(at = new Date()) {
  // Dịch +7h rồi đọc bằng getUTC*: các trường UTC lúc này chính là giờ tường VN.
  const shifted = new Date(at.getTime() + VN_OFFSET_MS);
  const startMs =
    Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate()) -
    VN_OFFSET_MS;

  return {
    startOfDay: new Date(startMs),
    endOfDay: new Date(startMs + DAY_MS - 1),
    dayOfWeek: shifted.getUTCDay(),
  };
}

module.exports = { vnDayRange, VN_OFFSET_MS };
