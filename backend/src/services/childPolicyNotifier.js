const prisma = require('../utils/prisma');
const { sendDataMessage } = require('./firebaseService');

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
    const tokens = await prisma.fCMToken.findMany({
      where: { device: { profileId } },
      select: { token: true },
    });
    const results = await Promise.allSettled(
      tokens.map((t) => sendDataMessage(t.token, { type: 'policy_update', profileId: String(profileId) })),
    );
    const invalid = results
      .filter((r) => r.status === 'fulfilled' && r.value?.error === 'INVALID_TOKEN')
      .map((r) => r.value.token);
    if (invalid.length > 0) await prisma.fCMToken.deleteMany({ where: { token: { in: invalid } } });
    console.log(`🌐 [${tag}] policy_update gửi ${results.length - invalid.length}/${tokens.length} token, profile ${profileId}`);
  } catch (err) {
    console.error(`❌ [${tag}] policy_update notify failed:`, err.message);
  }
};

module.exports = { notifyChildPolicyUpdated };
