const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// POST /api/auth/register - Đăng ký tài khoản
router.post('/register', authController.register);

// POST /api/auth/login - Đăng nhập
router.post('/login', authController.login);

// POST /api/auth/refresh - Làm mới token
router.post('/refresh', authController.refreshToken);

// POST /api/auth/logout - Đăng xuất
router.post('/logout', authController.logout);

module.exports = router;