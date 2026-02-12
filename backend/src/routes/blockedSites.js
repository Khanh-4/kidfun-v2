const express = require('express');
const router = express.Router();
const blockedSiteController = require('../controllers/blockedSiteController');
const { authenticate } = require('../middleware/auth');

// Tất cả routes cần xác thực
router.use(authenticate);

// GET /api/blocked-sites/:profileId - Lấy danh sách chặn theo profile
router.get('/:profileId', blockedSiteController.getByProfile);

// POST /api/blocked-sites - Thêm website/app bị chặn
router.post('/', blockedSiteController.create);

// DELETE /api/blocked-sites/:id - Xóa website/app bị chặn
router.delete('/:id', blockedSiteController.remove);

module.exports = router;
