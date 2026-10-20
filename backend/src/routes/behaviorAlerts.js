const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const behaviorAlertController = require('../controllers/behaviorAlertController');

// POST /api/behavior-alerts/:id/feedback - Phụ huynh xác nhận "Đúng là bất thường" / "Được phép" (đồ án chuyên ngành)
router.post('/:id/feedback', authenticate, behaviorAlertController.setFeedback);

module.exports = router;
