const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticate } = require('../middleware/auth');

// POST /api/auth/register - Đăng ký tài khoản
router.post('/register', authController.register);

// POST /api/auth/login - Đăng nhập
router.post('/login', authController.login);

// POST /api/auth/refresh - Làm mới token
router.post('/refresh', authenticate, authController.refreshToken);

// POST /api/auth/logout - Đăng xuất
router.post('/logout', authController.logout);

// PUT /api/auth/profile - Cập nhật thông tin (cần đăng nhập)
router.put('/profile', authenticate, authController.updateProfile);

// PUT /api/auth/change-password - Đổi mật khẩu (cần đăng nhập)
router.put('/change-password', authenticate, authController.changePassword);

module.exports = router;