const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const { sendOtpEmail } = require('../services/emailService');
const { sendSuccess, sendError } = require('../middleware/responseHandler');
const { OAuth2Client } = require('google-auth-library');

const prisma = new PrismaClient();
const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID || '130046544171-q4pllsneq42l2cbgc577mah6c6hvjgto.apps.googleusercontent.com');

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

    if (!fullName || typeof fullName !== 'string' || fullName.trim().length === 0) {
      return sendError(res, 'fullName là bắt buộc', 400, 'MISSING_FULL_NAME');
    }
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return sendError(res, 'Email không hợp lệ', 400, 'INVALID_EMAIL');
    }
    if (!password || password.length < 6) {
      return sendError(res, 'Mật khẩu phải có ít nhất 6 ký tự', 400, 'INVALID_PASSWORD');
    }

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

    if (!email || !password) {
      return sendError(res, 'Email và mật khẩu là bắt buộc', 400, 'MISSING_CREDENTIALS');
    }

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

// Helper: Xử lý tạo/liên kết user từ Google payload
const _handleGoogleUser = async (googleId, email, fullName) => {
  let user = await prisma.user.findUnique({ where: { email } });
  let isNewUser = false;
  let missingPhoneNumber = false;

  if (user) {
    if (!user.googleId) {
      user = await prisma.user.update({
        where: { email },
        data: { googleId }
      });
    }
    if (!user.phoneNumber) {
      missingPhoneNumber = true;
    }
  } else {
    user = await prisma.user.create({
      data: {
        email,
        googleId,
        fullName,
        passwordHash: null,
        phoneNumber: null
      }
    });
    isNewUser = true;
    missingPhoneNumber = true;
  }

  return { user, isNewUser, missingPhoneNumber };
};

// POST /api/auth/google (giữ lại cho tương thích — nhận idToken trực tiếp)
const loginWithGoogle = async (req, res) => {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      return sendError(res, 'ID Token là bắt buộc', 400, 'MISSING_TOKEN');
    }

    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID || '130046544171-q4pllsneq42l2cbgc577mah6c6hvjgto.apps.googleusercontent.com',
    });
    const payload = ticket.getPayload();
    const { sub: googleId, email, name: fullName } = payload;

    if (!email) {
      return sendError(res, 'Không thể lấy email từ Google', 400, 'MISSING_EMAIL');
    }

    const { user, isNewUser, missingPhoneNumber } = await _handleGoogleUser(googleId, email, fullName);
    const token = generateToken(user);
    const rt = generateRefreshToken(user);

    sendSuccess(res, {
      token,
      refreshToken: rt,
      user: { id: user.id, email: user.email, fullName: user.fullName, phoneNumber: user.phoneNumber, googleId: user.googleId },
      isNewUser,
      missingPhoneNumber
    });
  } catch (error) {
    console.error('Google Login error:', error);
    sendError(res, 'Google Login failed', 500, 'INTERNAL_ERROR');
  }
};

// GET /api/auth/google/callback — Nhận authorization code từ Google, đổi lấy token, redirect về app
const googleCallback = async (req, res) => {
  try {
    const { code } = req.query;
    if (!code) {
      return res.status(400).send('Missing authorization code');
    }

    const clientId = process.env.GOOGLE_CLIENT_ID || '130046544171-q4pllsneq42l2cbgc577mah6c6hvjgto.apps.googleusercontent.com';
    const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
    const redirectUri = `${process.env.BACKEND_URL || 'https://kidfun-backend-production.up.railway.app'}/api/auth/google/callback`;

    // Đổi authorization code lấy tokens từ Google
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
        grant_type: 'authorization_code',
      }),
    });
    const tokens = await tokenResponse.json();

    if (!tokens.id_token) {
      console.error('Google token exchange failed:', tokens);
      return res.redirect(`com.kidfun.mobile://oauth2callback?error=token_exchange_failed`);
    }

    // Verify ID token
    const ticket = await googleClient.verifyIdToken({
      idToken: tokens.id_token,
      audience: clientId,
    });
    const payload = ticket.getPayload();
    const { sub: googleId, email, name: fullName } = payload;

    if (!email) {
      return res.redirect(`com.kidfun.mobile://oauth2callback?error=missing_email`);
    }

    const { user, isNewUser, missingPhoneNumber } = await _handleGoogleUser(googleId, email, fullName);
    const token = generateToken(user);
    const rt = generateRefreshToken(user);

    // Redirect về app với token trong URL
    const params = new URLSearchParams({
      token,
      refreshToken: rt,
      userId: user.id.toString(),
      email: user.email,
      fullName: user.fullName,
      missingPhoneNumber: missingPhoneNumber.toString(),
      isNewUser: isNewUser.toString(),
    });

    return res.redirect(`com.kidfun.mobile://oauth2callback?${params.toString()}`);
  } catch (error) {
    console.error('Google Callback error:', error);
    return res.redirect(`com.kidfun.mobile://oauth2callback?error=server_error`);
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
  loginWithGoogle,
  googleCallback,
  refreshToken,
  logout,
  updateProfile,
  changePassword,
  forgotPassword,
  resetPassword,
  resetPasswordWithOtp,
};
