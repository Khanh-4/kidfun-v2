const express = require('express');
const router = express.Router();
const fcmController = require('../controllers/fcmController');
const { authenticate } = require('../middleware/auth');

// POST /api/fcm-tokens/register - Đăng ký FCM token
router.post('/register', authenticate, fcmController.registerToken);

// POST /api/fcm-tokens/unregister - Hủy đăng ký FCM token
router.post('/unregister', authenticate, fcmController.unregisterToken);

module.exports = router;
