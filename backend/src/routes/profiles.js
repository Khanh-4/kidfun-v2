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

// PUT /api/profiles/:id/time-limits - Cập nhật giới hạn thời gian
router.put('/:id/time-limits', profileController.updateTimeLimits);

const warningController = require('../controllers/warningController');
// GET /api/profiles/:id/warnings - Xem lịch sử cảnh báo
router.get('/:id/warnings', warningController.getWarnings);

const extensionController = require('../controllers/extensionController');
// GET /api/profiles/:id/extension-requests - Xem lịch sử xin thêm giờ
router.get('/:id/extension-requests', extensionController.getExtensionRequests);

const appUsageController = require('../controllers/appUsageController');
// GET /api/profiles/:id/app-usage/weekly — phải đứng trước /app-usage để tránh conflict route param
router.get('/:id/app-usage/weekly', appUsageController.getWeeklyUsage);
// GET /api/profiles/:id/app-usage?date=YYYY-MM-DD
router.get('/:id/app-usage', appUsageController.getDailyUsage);
// GET /api/profiles/:id/all-apps — tất cả app đã cài (distinct, tổng usage)
router.get('/:id/all-apps', appUsageController.getAllApps);

const blockedAppController = require('../controllers/blockedAppController');
// GET  /api/profiles/:id/blocked-apps
router.get('/:id/blocked-apps', blockedAppController.getBlockedApps);
// POST /api/profiles/:id/blocked-apps
router.post('/:id/blocked-apps', blockedAppController.addBlockedApp);
// DELETE /api/profiles/:id/blocked-apps/:packageName
router.delete('/:id/blocked-apps/:packageName', blockedAppController.removeBlockedApp);

const timeLimitController = require('../controllers/timeLimitController');
// PUT /api/profiles/:id/time-limits/gradual — bật gradual reduction
router.put('/:id/time-limits/gradual', timeLimitController.setGradualReduction);
// PUT /api/profiles/:id/time-limits/gradual/disable — tắt gradual reduction
router.put('/:id/time-limits/gradual/disable', timeLimitController.disableGradualReduction);

const locationController = require('../controllers/locationController');
// GET /api/profiles/:id/location/current — vị trí GPS mới nhất
router.get('/:id/location/current', locationController.getCurrentLocation);
// GET /api/profiles/:id/location/history?date=YYYY-MM-DD — lịch sử GPS theo ngày
router.get('/:id/location/history', locationController.getLocationHistory);

const geofenceController = require('../controllers/geofenceController');
// GET  /api/profiles/:id/geofences — danh sách geofences
// PHẢI đặt /:id/geofences/events TRƯỚC /:id/geofences để tránh conflict
router.get('/:id/geofences/events', geofenceController.getGeofenceEvents);
router.get('/:id/geofences', geofenceController.getGeofences);
// POST /api/profiles/:id/geofences — tạo geofence mới
router.post('/:id/geofences', geofenceController.createGeofence);

const sosController = require('../controllers/sosController');
// GET /api/profiles/:id/sos — lịch sử SOS alerts
router.get('/:id/sos', sosController.getSOSHistory);

const appTimeLimitController = require('../controllers/appTimeLimitController');
// GET  /api/profiles/:id/app-time-limits
router.get('/:id/app-time-limits', appTimeLimitController.getAppTimeLimits);
// POST /api/profiles/:id/app-time-limits — upsert
router.post('/:id/app-time-limits', appTimeLimitController.upsertAppTimeLimit);
// DELETE /api/profiles/:id/app-time-limits/:packageName
router.delete('/:id/app-time-limits/:packageName', appTimeLimitController.deleteAppTimeLimit);

const schoolScheduleController = require('../controllers/schoolScheduleController');
// GET /api/profiles/:id/school-schedule
router.get('/:id/school-schedule', schoolScheduleController.getSchedule);
// PUT /api/profiles/:id/school-schedule — upsert template + overrides + allowed apps
router.put('/:id/school-schedule', schoolScheduleController.upsertSchedule);
// POST /api/profiles/:id/school-schedule/override — manual override (FORCE_ON/FORCE_OFF/CLEAR)
router.post('/:id/school-schedule/override', schoolScheduleController.manualOverride);

const webFilteringController = require('../controllers/webFilteringController');
// GET  /api/profiles/:id/blocked-categories
router.get('/:id/blocked-categories', webFilteringController.getBlockedCategories);
// POST /api/profiles/:id/blocked-categories — toggle category on/off
router.post('/:id/blocked-categories', webFilteringController.toggleCategory);
// POST /api/profiles/:id/blocked-categories/:categoryId/override — whitelist 1 domain
// DELETE /api/profiles/:id/blocked-categories/:categoryId/override/:domain
// NOTE: đặt /override/:domain TRƯỚC /override để tránh conflict route
router.delete('/:id/blocked-categories/:categoryId/override/:domain', webFilteringController.removeCategoryOverride);
router.post('/:id/blocked-categories/:categoryId/override', webFilteringController.addCategoryOverride);
// GET  /api/profiles/:id/custom-blocked-domains
router.get('/:id/custom-blocked-domains', webFilteringController.getCustomDomains);
// POST /api/profiles/:id/custom-blocked-domains
router.post('/:id/custom-blocked-domains', webFilteringController.addCustomDomain);
// DELETE /api/profiles/:id/custom-blocked-domains/:domain
router.delete('/:id/custom-blocked-domains/:domain', webFilteringController.deleteCustomDomain);

// ── Sprint 9: YouTube Monitoring ──────────────────────────────────────────
const youtubeController = require('../controllers/youtubeController');
// GET /api/profiles/:id/youtube/dashboard?days=7
router.get('/:id/youtube/dashboard', youtubeController.getDashboard);
// GET /api/profiles/:id/youtube/logs?date=&minDanger=&channel=&page=&limit=
router.get('/:id/youtube/logs', youtubeController.getLogs);
// POST /api/profiles/:id/blocked-videos — manual block
router.post('/:id/blocked-videos', youtubeController.blockVideo);
// GET /api/profiles/:id/blocked-videos — parent sync blocked videos
router.get('/:id/blocked-videos', youtubeController.getParentBlockedVideos);

// ── Sprint 9: AI Alerts ───────────────────────────────────────────────────
const aiAlertController = require('../controllers/aiAlertController');
// GET /api/profiles/:id/ai-alerts?unread=true
router.get('/:id/ai-alerts', aiAlertController.getAlerts);

// ── Sprint 9: Reports ─────────────────────────────────────────────────────
const reportController = require('../controllers/reportController');
// GET /api/profiles/:id/reports/daily?date=YYYY-MM-DD
router.get('/:id/reports/daily', reportController.getDailyReport);
// GET /api/profiles/:id/reports/weekly?weekStart=YYYY-MM-DD
router.get('/:id/reports/weekly', reportController.getWeeklyReport);

// ── Sprint 9: Activity History ────────────────────────────────────────────
const activityHistoryController = require('../controllers/activityHistoryController');
// GET /api/profiles/:id/activity-history?date=YYYY-MM-DD
router.get('/:id/activity-history', activityHistoryController.getActivityHistory);

module.exports = router;