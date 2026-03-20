const express = require('express');
const router = express.Router();
const extensionController = require('../controllers/extensionController');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// GET /api/extension-requests/pending - Lấy các requests đang chờ duyệt
router.get('/pending', extensionController.getPendingRequests);

// PUT /api/extension-requests/:id/approve - Parent duyệt yêu cầu thêm giờ (BUG 2 FIX)
router.put('/:id/approve', extensionController.approveExtension);

module.exports = router;
