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

module.exports = router;