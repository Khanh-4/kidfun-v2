const express = require('express');
const router = express.Router();
const monitoringController = require('../controllers/monitoringController');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// GET /api/monitoring/usage/:profileId - Lấy thống kê sử dụng
router.get('/usage/:profileId', monitoringController.getUsageStats);

// POST /api/monitoring/usage - Ghi log sử dụng
router.post('/usage', monitoringController.logUsage);

// GET /api/monitoring/warnings/:profileId - Lấy cảnh báo
router.get('/warnings/:profileId', monitoringController.getWarnings);

// POST /api/monitoring/warnings - Tạo cảnh báo mới
router.post('/warnings', monitoringController.createWarning);

// GET /api/monitoring/reports/:profileId - Lấy báo cáo chi tiết
router.get('/reports/:profileId', monitoringController.getReports);

module.exports = router;