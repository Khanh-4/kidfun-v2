const express = require('express');
const router = express.Router();
const childController = require('../controllers/childController');

// Tất cả routes PUBLIC - Child không cần authentication
// Dùng deviceCode từ X-Device-Code header để identify

// GET /api/child/status - Lấy thông tin thời gian, profile, session
router.get('/status', childController.getStatus);

// POST /api/child/session/start - Bắt đầu session mới
router.post('/session/start', childController.startSession);

// POST /api/child/session/heartbeat - Cập nhật session (mỗi 60s)
router.post('/session/heartbeat', childController.heartbeat);

// POST /api/child/session/end - Kết thúc session
router.post('/session/end', childController.endSession);

// POST /api/child/bonus - Lưu bonus minutes khi Parent duyệt
router.post('/bonus', childController.addBonus);

// POST /api/child/warnings - Ghi log warning
router.post('/warnings', childController.createWarning);

module.exports = router;
