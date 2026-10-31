const express = require('express');
const router = express.Router();
const webFilteringController = require('../controllers/webFilteringController');

// GET /api/web-categories — public (child cũng cần đọc nếu muốn)
router.get('/', webFilteringController.getCategories);

module.exports = router;
