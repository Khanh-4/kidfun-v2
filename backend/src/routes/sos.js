const express = require('express');
const router = express.Router();
const sosController = require('../controllers/sosController');
const { authenticate } = require('../middleware/auth');

// PUT /api/sos/:id/acknowledge — Parent xác nhận đã nhận SOS
router.put('/:id/acknowledge', authenticate, sosController.acknowledgeSOS);

// PUT /api/sos/:id/resolve — Parent đánh dấu đã giải quyết
router.put('/:id/resolve', authenticate, sosController.resolveSOS);

module.exports = router;
