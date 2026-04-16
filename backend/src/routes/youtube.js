const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const youtubeController = require('../controllers/youtubeController');
const aiAlertController = require('../controllers/aiAlertController');

// DELETE /api/blocked-videos/:id — Parent unblock video
router.delete('/blocked-videos/:id', authenticate, youtubeController.unblockVideo);

// PUT /api/ai-alerts/:id/read — Mark alert as read
router.put('/ai-alerts/:id/read', authenticate, aiAlertController.markRead);

module.exports = router;
