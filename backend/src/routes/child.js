const express = require('express');
const router = express.Router();
const childController = require('../controllers/childController');
const sessionController = require('../controllers/sessionController');
const warningController = require('../controllers/warningController');
const extensionController = require('../controllers/extensionController');
const appUsageController = require('../controllers/appUsageController');

// Tất cả routes PUBLIC - Child không cần authentication
// Dùng deviceCode từ X-Device-Code header để identify

// GET /api/child/status - Lấy thông tin thời gian, profile, session
router.get('/status', childController.getStatus);

// GET /api/child/today-limit - Lấy time limit hôm nay
router.get('/today-limit', childController.getTodayLimit);

// POST /api/child/session/start - Bắt đầu session mới
router.post('/session/start', sessionController.startSession);

// POST /api/child/session/heartbeat - Cập nhật session (mỗi 60s)
router.post('/session/heartbeat', sessionController.heartbeat);

// POST /api/child/session/end - Kết thúc session
router.post('/session/end', sessionController.endSession);

// POST /api/child/bonus - Lưu bonus minutes khi Parent duyệt
router.post('/bonus', childController.addBonus);

// POST /api/child/warnings - Ghi log warning
router.post('/warning', warningController.logWarning);
router.post('/warnings', warningController.logWarning);

// POST /api/child/extension-request - Child xin thêm giờ (REST + FCM push to Parent)
router.post('/extension-request', extensionController.createExtensionRequest);

// GET /api/child/blocked-sites - Lấy danh sách blocked sites (dùng deviceCode)
router.get('/blocked-sites', childController.getBlockedSites);

// POST /api/child/app-usage - Child gửi batch app usage data
router.post('/app-usage', appUsageController.syncAppUsage);

module.exports = router;
