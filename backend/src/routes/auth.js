const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticate } = require('../middleware/auth');

// POST /api/auth/register - Đăng ký tài khoản
router.post('/register', authController.register);

// POST /api/auth/login - Đăng nhập
router.post('/login', authController.login);

// POST /api/auth/refresh-token - Làm mới token (không cần auth, dùng refresh token trong body)
router.post('/refresh-token', authController.refreshToken);

// POST /api/auth/logout - Đăng xuất (cần JWT)
router.post('/logout', authenticate, authController.logout);

// POST /api/auth/forgot-password - Quên mật khẩu
router.post('/forgot-password', authController.forgotPassword);

// POST /api/auth/reset-password - Đặt lại mật khẩu (link cũ, giữ lại tương thích)
router.post('/reset-password', authController.resetPassword);

// POST /api/auth/reset-password-otp - Đặt lại mật khẩu bằng OTP 6 số
router.post('/reset-password-otp', authController.resetPasswordWithOtp);

// PUT /api/auth/profile - Cập nhật thông tin (cần đăng nhập)
router.put('/profile', authenticate, authController.updateProfile);

// PUT /api/auth/change-password - Đổi mật khẩu (cần đăng nhập)
router.put('/change-password', authenticate, authController.changePassword);

module.exports = router;
