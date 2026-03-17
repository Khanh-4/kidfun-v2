const express = require('express');
const router = express.Router();
const extensionController = require('../controllers/extensionController');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// GET /api/extension-requests/pending - Lấy các requests đang chờ duyệt
router.get('/pending', extensionController.getPendingRequests);

module.exports = router;
