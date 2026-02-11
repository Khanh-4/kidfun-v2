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

module.exports = router;