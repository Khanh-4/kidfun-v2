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

// POST /api/devices/generate-pairing-code - Tạo mã QR pairing code
router.post('/generate-pairing-code', deviceController.generatePairingCode);

// POST /api/devices/cancel-pairing - Huỷ mã liên kết + xoá device nháp
router.post('/cancel-pairing', deviceController.cancelPairing);

// POST /api/devices - Đăng ký thiết bị mới
router.post('/', deviceController.registerDevice);

// GET /api/devices/:id - Lấy thông tin thiết bị
router.get('/:id', deviceController.getDeviceById);

// PUT /api/devices/:id - Cập nhật thiết bị
router.put('/:id', deviceController.updateDevice);

// GET /api/devices/:id/status - Lấy trạng thái thiết bị
router.get('/:id/status', deviceController.getDeviceStatus);

// GET /api/devices/:id/pairing-status - Mã liên kết đã có thiết bị nào dùng chưa
router.get('/:id/pairing-status', deviceController.getPairingStatus);

// DELETE /api/devices/:id - Xóa thiết bị
router.delete('/:id', deviceController.deleteDevice);

// Chấm xem máy trẻ đã trả lời lệnh đánh thức chưa. Việc đánh thức nằm trong
// chính response 409 của DELETE — xem deviceController.deleteDevice.
router.get('/:id/liveness', deviceController.getLiveness);

module.exports = router;