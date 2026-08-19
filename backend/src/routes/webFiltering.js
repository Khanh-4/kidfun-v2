const express = require('express');
const router = express.Router();
const webFilteringController = require('../controllers/webFilteringController');
const { authenticate } = require('../middleware/auth');

// GET /api/web-categories — public (child cũng cần đọc nếu muốn)
router.get('/', webFilteringController.getCategories);

module.exports = router;
