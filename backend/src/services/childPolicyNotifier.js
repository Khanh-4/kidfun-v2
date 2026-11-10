const prisma = require('../utils/prisma');
const { sendDataMessage } = require('./firebaseService');

/**
 * Gửi FCM data tới mọi token khớp `where`, dọn token chết. Trả về số token gửi được.
 * @param {object} where điều kiện prisma.fCMToken
 * @param {Record<string,string>} data
 */
const sendDataToTokens = async (where, data) => {
  const tokens = await prisma.fCMToken.findMany({ where, select: { token: true } });
  const results = await Promise.allSettled(tokens.map((t) => sendDataMessage(t.token, data)));
  const invalid = results
    .filter((r) => r.status === 'fulfilled' && r.value?.error === 'INVALID_TOKEN')
    .map((r) => r.value.token);
  if (invalid.length > 0) await prisma.fCMToken.deleteMany({ where: { token: { in: invalid } } });
  return { sent: results.length - invalid.length, total: tokens.length };
};

/**
 * Báo máy trẻ của profile rằng chính sách đã đổi (lọc web, lịch học, giới hạn
 * từng app) bằng FCM data `policy_update` → app trẻ gọi lại GET /api/child/policy
 * và áp xuống native ngay, kể cả khi đang chạy nền.
 *
 * Thay cho Socket.IO: trên Vercel `socketService.io` luôn null nên các bản emit
 * cũ không gửi gì — máy trẻ phải chờ lượt đồng bộ 5 phút (lỗi test 10/11).
 *
 * Không bao giờ ném lỗi: dữ liệu của phụ huynh đã lưu, máy trẻ vẫn lấy được ở
 * lần mở app / đồng bộ định kỳ kế tiếp.
 *
 * @param {number} profileId
 * @param {string} tag nhãn log, vd. 'WEBFILTER', 'SCHOOL', 'APPLIMIT'
 */
const notifyChildPolicyUpdated = async (profileId, tag) => {
  try {
    const { sent, total } = await sendDataToTokens(
      { device: { profileId } },
      { type: 'policy_update', profileId: String(profileId) },
    );
    console.log(`🌐 [${tag}] policy_update gửi ${sent}/${total} token, profile ${profileId}`);
  } catch (err) {
    console.error(`❌ [${tag}] policy_update notify failed:`, err.message);
  }
};

/**
 * Báo máy trẻ (đúng máy đã xin) kết quả duyệt/từ chối thêm giờ bằng FCM data
 * `extension_response` → app trẻ refetch latest-response + today-limit, hiện
 * kết quả và gỡ khoá nếu được duyệt.
 *
 * Thay cho Socket.IO (null trên Vercel) và bổ sung cho tín hiệu Realtime vốn
 * hay rớt: lỗi test 10/11 duyệt 4 lần, máy trẻ chỉ biết được 1 lần.
 * Không bao giờ ném lỗi — kết quả đã lưu DB, app trẻ vẫn tự hỏi lại định kỳ.
 *
 * @param {number} deviceId
 * @param {{ requestId: number, status: 'APPROVED'|'REJECTED' }} result
 */
const notifyChildExtensionResponse = async (deviceId, { requestId, status }) => {
  try {
    const { sent, total } = await sendDataToTokens(
      { deviceId },
      { type: 'extension_response', requestId: String(requestId), status },
    );
    console.log(`⏳ [EXTENSION] extension_response ${status} gửi ${sent}/${total} token, device ${deviceId}`);
  } catch (err) {
    console.error('❌ [EXTENSION] extension_response notify failed:', err.message);
  }
};

module.exports = { notifyChildPolicyUpdated, notifyChildExtensionResponse };
