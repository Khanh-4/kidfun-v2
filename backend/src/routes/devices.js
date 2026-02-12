const express = require('express');
const router = express.Router();
const deviceController = require('../controllers/deviceController');
const { authenticate } = require('../middleware/auth');

// POST /api/devices/link - Liên kết thiết bị (KHÔNG cần đăng nhập)
router.post('/link', deviceController.linkDevice);

// Các routes bên dưới CẦN đăng nhập
router.use(authenticate);

// GET /api/devices - Lấy tất cả thiết bị
router.get('/', deviceController.getAllDevices);

// POST /api/devices - Đăng ký thiết bị mới
router.post('/', deviceController.registerDevice);

// GET /api/devices/:id - Lấy thông tin thiết bị
router.get('/:id', deviceController.getDeviceById);

// PUT /api/devices/:id - Cập nhật thiết bị
router.put('/:id', deviceController.updateDevice);

// DELETE /api/devices/:id - Xóa thiết bị
router.delete('/:id', deviceController.deleteDevice);

module.exports = router;