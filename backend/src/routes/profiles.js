const express = require('express');
const router = express.Router();
const profileController = require('../controllers/profileController');
const { authenticate } = require('../middleware/auth');

// Tất cả routes cần xác thực
router.use(authenticate);

// GET /api/profiles - Lấy tất cả profiles của user
router.get('/', profileController.getAllProfiles);

// POST /api/profiles - Tạo profile mới (con)
router.post('/', profileController.createProfile);

// GET /api/profiles/:id - Lấy thông tin 1 profile
router.get('/:id', profileController.getProfileById);

// PUT /api/profiles/:id - Cập nhật profile
router.put('/:id', profileController.updateProfile);

// DELETE /api/profiles/:id - Xóa profile
router.delete('/:id', profileController.deleteProfile);

// PUT /api/profiles/:id/time-limits - Cập nhật giới hạn thời gian
router.put('/:id/time-limits', profileController.updateTimeLimits);

const warningController = require('../controllers/warningController');
// GET /api/profiles/:id/warnings - Xem lịch sử cảnh báo
router.get('/:id/warnings', warningController.getWarnings);

const extensionController = require('../controllers/extensionController');
// GET /api/profiles/:id/extension-requests - Xem lịch sử xin thêm giờ
router.get('/:id/extension-requests', extensionController.getExtensionRequests);

const appUsageController = require('../controllers/appUsageController');
// GET /api/profiles/:id/app-usage/weekly — phải đứng trước /app-usage để tránh conflict route param
router.get('/:id/app-usage/weekly', appUsageController.getWeeklyUsage);
// GET /api/profiles/:id/app-usage?date=YYYY-MM-DD
router.get('/:id/app-usage', appUsageController.getDailyUsage);
// GET /api/profiles/:id/all-apps — tất cả app đã cài (distinct, tổng usage)
router.get('/:id/all-apps', appUsageController.getAllApps);

const blockedAppController = require('../controllers/blockedAppController');
// GET  /api/profiles/:id/blocked-apps
router.get('/:id/blocked-apps', blockedAppController.getBlockedApps);
// POST /api/profiles/:id/blocked-apps
router.post('/:id/blocked-apps', blockedAppController.addBlockedApp);
// DELETE /api/profiles/:id/blocked-apps/:packageName
router.delete('/:id/blocked-apps/:packageName', blockedAppController.removeBlockedApp);

const timeLimitController = require('../controllers/timeLimitController');
// PUT /api/profiles/:id/time-limits/gradual — bật gradual reduction
router.put('/:id/time-limits/gradual', timeLimitController.setGradualReduction);
// PUT /api/profiles/:id/time-limits/gradual/disable — tắt gradual reduction
router.put('/:id/time-limits/gradual/disable', timeLimitController.disableGradualReduction);

const locationController = require('../controllers/locationController');
// GET /api/profiles/:id/location/current — vị trí GPS mới nhất
router.get('/:id/location/current', locationController.getCurrentLocation);
// GET /api/profiles/:id/location/history?date=YYYY-MM-DD — lịch sử GPS theo ngày
router.get('/:id/location/history', locationController.getLocationHistory);

module.exports = router;