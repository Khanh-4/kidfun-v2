const prisma = require('./prisma');

/**
 * Kiểm tra quyền sở hữu cho các API của phụ huynh (chặn IDOR: đổi id là xem/sửa được dữ liệu nhà khác).
 * req.user.userId là phụ huynh đăng nhập; token máy trẻ cũng mang userId của phụ huynh sở hữu thiết bị.
 */

/** Profile `profileId` nếu thuộc `userId`, ngược lại null. */
const findOwnedProfile = (profileId, userId) => {
  if (!Number.isInteger(profileId) || !userId) return Promise.resolve(null);
  return prisma.profile.findFirst({ where: { id: profileId, userId }, select: { id: true } });
};

/** Điều kiện Prisma cho bản ghi có quan hệ `profile`: chỉ bản ghi của con phụ huynh đang đăng nhập. */
const ownedBy = (req) => ({ profile: { userId: req.user.userId } });

module.exports = { findOwnedProfile, ownedBy };
