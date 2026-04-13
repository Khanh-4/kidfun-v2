const express = require('express');
const router = express.Router();
const childController = require('../controllers/childController');
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
router.post('/session/start', childController.startSession);

// POST /api/child/session/heartbeat - Cập nhật session (mỗi 60s)
router.post('/session/heartbeat', childController.heartbeat);

// POST /api/child/session/end - Kết thúc session
router.post('/session/end', childController.endSession);

// POST /api/child/session/pause - Tạm dừng session (màn hình tắt)
router.post('/session/pause', childController.pauseSession);

// POST /api/child/session/resume - Tiếp tục session (màn hình bật)
router.post('/session/resume', childController.resumeSession);

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

const blockedAppController = require('../controllers/blockedAppController');
// GET /api/child/blocked-apps?deviceCode=XXX - Child lấy danh sách app bị chặn
router.get('/blocked-apps', blockedAppController.getBlockedAppsForChild);

const appTimeLimitController = require('../controllers/appTimeLimitController');
// GET /api/child/app-time-limits?deviceCode=XXX — per-app limits với remaining hôm nay
router.get('/app-time-limits', appTimeLimitController.getChildAppTimeLimits);

const webFilteringController = require('../controllers/webFilteringController');
// GET /api/child/blocked-domains?deviceCode=XXX — danh sách blocked domains cuối cùng
router.get('/blocked-domains', webFilteringController.getChildBlockedDomains);

const locationController = require('../controllers/locationController');
// POST /api/child/location - Child gửi GPS (no auth)
router.post('/location', locationController.postLocation);

const { uploadAudio } = require('../middleware/uploadMiddleware');
const sosController = require('../controllers/sosController');
// POST /api/child/sos - Child gửi SOS với audio (multipart/form-data, no auth)
router.post('/sos', uploadAudio, sosController.createSOS);

module.exports = router;
