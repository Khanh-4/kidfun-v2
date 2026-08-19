const express = require('express');
const router = express.Router();
const geofenceController = require('../controllers/geofenceController');
const { authenticate } = require('../middleware/auth');

// PUT  /api/geofences/:id — cập nhật geofence
router.put('/:id', authenticate, geofenceController.updateGeofence);

// DELETE /api/geofences/:id — xóa geofence
router.delete('/:id', authenticate, geofenceController.deleteGeofence);

module.exports = router;
