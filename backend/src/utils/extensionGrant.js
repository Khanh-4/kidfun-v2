/**
 * Số phút thật sự cộng vào hạn mức khi phụ huynh duyệt thêm giờ.
 *
 * Lỗi test 10/11: trẻ đã dùng 688p trong khi hạn mức 465p — duyệt +15p chỉ đẩy
 * hạn mức lên 480p, vẫn thấp hơn số đã dùng nên remaining = 0 và máy vẫn khoá.
 * Phụ huynh bấm "+15 phút" nghĩa là "cho con dùng thêm 15 phút kể từ bây giờ",
 * nên nếu trẻ đã vượt hạn mức thì bù phần vượt (làm tròn lên) rồi mới cộng.
 *
 * @param {{ approvedMinutes: number, usedSeconds: number, limitMinutes: number }} input
 *   limitMinutes = hạn mức hiện tại đã gồm mọi bonus được duyệt trước đó
 * @returns {number}
 */
const grantedMinutesFor = ({ approvedMinutes, usedSeconds, limitMinutes }) => {
  const overSeconds = usedSeconds - limitMinutes * 60;
  const overMinutes = overSeconds > 0 ? Math.ceil(overSeconds / 60) : 0;
  return approvedMinutes + overMinutes;
};

/**
 * Số phút một yêu cầu đã duyệt đóng góp vào hạn mức. `grantedMinutes` gồm cả
 * phần bù; bản ghi trước khi có cột này chỉ có `responseMinutes`.
 * @param {{ grantedMinutes?: number|null, responseMinutes?: number|null }} req
 * @returns {number}
 */
const extensionMinutes = (req) => req.grantedMinutes ?? req.responseMinutes ?? 0;

module.exports = { grantedMinutesFor, extensionMinutes };
