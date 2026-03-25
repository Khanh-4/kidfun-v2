const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const { sendOtpEmail } = require('../services/emailService');
const { sendSuccess, sendError } = require('../middleware/responseHandler');

const prisma = new PrismaClient();

// Tạo JWT access token
const generateToken = (user) => {
  return jwt.sign(
    { userId: user.id, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
  );
};

// Tạo JWT refresh token (secret riêng, expire 7d)
const generateRefreshToken = (user) => {
  return jwt.sign(
    { userId: user.id },
    process.env.JWT_SECRET + '_refresh',
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' }
  );
};

// POST /api/auth/register
const register = async (req, res) => {
  try {
    const { email, password, fullName, phoneNumber } = req.body;

    // Kiểm tra email đã tồn tại
    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      return sendError(res, 'Email already registered', 400, 'EMAIL_EXISTS');
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Tạo user mới
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        fullName,
        phoneNumber
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        phoneNumber: true,
        createdAt: true
      }
    });

    const token = generateToken(user);
    const refreshToken = generateRefreshToken(user);

    sendSuccess(res, { token, refreshToken, user }, 201);
  } catch (error) {
    console.error('Register error:', error);
    sendError(res, 'Registration failed', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/auth/login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Tìm user
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return sendError(res, 'Email chưa được đăng ký', 401, 'EMAIL_NOT_FOUND');
    }

    // Kiểm tra password
    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      return sendError(res, 'Mật khẩu nhập sai. Xin nhập lại', 401, 'INVALID_CREDENTIALS');
    }

    const token = generateToken(user);
    const refreshToken = generateRefreshToken(user);

    sendSuccess(res, {
      token,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        phoneNumber: user.phoneNumber
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    sendError(res, 'Login failed', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/auth/refresh-token
const refreshToken = async (req, res) => {
  try {
    const { refreshToken: token } = req.body;

    if (!token) {
      return sendError(res, 'Refresh token is required', 400, 'MISSING_TOKEN');
    }

    // Verify refresh token
    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET + '_refresh');
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return sendError(res, 'Refresh token expired', 401, 'TOKEN_EXPIRED');
      }
      return sendError(res, 'Invalid refresh token', 401, 'INVALID_TOKEN');
    }

    const user = await prisma.user.findUnique({ where: { id: decoded.userId } });
    if (!user) {
      return sendError(res, 'User not found', 404, 'USER_NOT_FOUND');
    }

    // Tạo access token mới + refresh token mới
    const newToken = generateToken(user);
    const newRefreshToken = generateRefreshToken(user);

    sendSuccess(res, { token: newToken, refreshToken: newRefreshToken });
  } catch (error) {
    console.error('Refresh token error:', error);
    sendError(res, 'Token refresh failed', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/auth/logout
const logout = async (req, res) => {
  sendSuccess(res, { message: 'Logged out' });
};

// PUT /api/auth/profile - Cập nhật thông tin cá nhân
const updateProfile = async (req, res) => {
  try {
    const { fullName, phoneNumber } = req.body;
    const userId = req.user.userId;

    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        fullName,
        phoneNumber,
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        phoneNumber: true,
      },
    });

    sendSuccess(res, { user });
  } catch (error) {
    console.error('Update profile error:', error);
    sendError(res, 'Failed to update profile', 500, 'INTERNAL_ERROR');
  }
};

// PUT /api/auth/change-password - Đổi mật khẩu
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.userId;

    // Lấy user hiện tại
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return sendError(res, 'User not found', 404, 'USER_NOT_FOUND');
    }

    // Kiểm tra mật khẩu hiện tại
    const isValidPassword = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isValidPassword) {
      return sendError(res, 'Mật khẩu hiện tại không đúng', 400, 'INVALID_PASSWORD');
    }

    // Hash mật khẩu mới
    const newPasswordHash = await bcrypt.hash(newPassword, 10);

    // Cập nhật mật khẩu
    await prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newPasswordHash },
    });

    sendSuccess(res, { message: 'Password changed successfully' });
  } catch (error) {
    console.error('Change password error:', error);
    sendError(res, 'Failed to change password', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/auth/forgot-password
const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    // Luôn trả OK để tránh leak email tồn tại hay không
    const successMsg = 'Nếu email tồn tại, chúng tôi đã gửi mã OTP đến email của bạn.';

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return sendSuccess(res, { message: successMsg });
    }

    // Tạo OTP 6 chữ số, hết hạn sau 15 phút
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const resetOtpExpiry = new Date(Date.now() + 15 * 60 * 1000);

    await prisma.user.update({
      where: { id: user.id },
      data: { resetOtp: otp, resetOtpExpiry },
    });

    try {
      await sendOtpEmail(email, otp);
    } catch (emailError) {
      console.error('Forgot password - send OTP email error:', emailError);
      // Vẫn trả success để không leak thông tin user
    }

    return sendSuccess(res, { message: successMsg });
  } catch (error) {
    console.error('Forgot password error:', error);
    sendError(res, 'Không thể gửi OTP. Vui lòng thử lại.', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/auth/reset-password-otp
const resetPasswordWithOtp = async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;

    if (!email || !otp || !newPassword) {
      return sendError(res, 'email, otp và newPassword là bắt buộc.', 400, 'MISSING_FIELDS');
    }

    const user = await prisma.user.findUnique({ where: { email } });

    if (
      !user ||
      !user.resetOtp ||
      !user.resetOtpExpiry ||
      user.resetOtp !== otp ||
      new Date() > user.resetOtpExpiry
    ) {
      return sendError(res, 'OTP không hợp lệ hoặc đã hết hạn.', 400, 'INVALID_OTP');
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);

    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        resetOtp: null,
        resetOtpExpiry: null,
      },
    });

    return sendSuccess(res, { message: 'Mật khẩu đã được đặt lại thành công.' });
  } catch (error) {
    console.error('Reset password with OTP error:', error);
    sendError(res, 'Không thể đặt lại mật khẩu. Vui lòng thử lại.', 500, 'INTERNAL_ERROR');
  }
};

// POST /api/auth/reset-password
const resetPassword = async (req, res) => {
  try {
    const { token, newPassword } = req.body;

    const user = await prisma.user.findFirst({
      where: {
        resetToken: token,
        resetTokenExpiry: { gt: new Date() },
      },
    });

    if (!user) {
      return sendError(res, 'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.', 400, 'INVALID_RESET_TOKEN');
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);

    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        resetToken: null,
        resetTokenExpiry: null,
      },
    });

    sendSuccess(res, { message: 'Mật khẩu đã được đặt lại thành công.' });
  } catch (error) {
    console.error('Reset password error:', error);
    sendError(res, 'Không thể đặt lại mật khẩu. Vui lòng thử lại.', 500, 'INTERNAL_ERROR');
  }
};

module.exports = {
  register,
  login,
  refreshToken,
  logout,
  updateProfile,
  changePassword,
  forgotPassword,
  resetPassword,
  resetPasswordWithOtp,
};
