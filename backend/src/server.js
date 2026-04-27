const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const { createServer } = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const app = express();
const httpServer = createServer(app);

// CORS: cho phép tất cả origins trong dev mode để hỗ trợ LAN
const corsOrigins = process.env.NODE_ENV === 'production'
  ? (process.env.SOCKET_CORS_ORIGIN?.split(',').map(s => s.trim()) || ['http://localhost:3000', 'http://localhost:3002'])
  : '*';

console.log('🔒 CORS origins:', corsOrigins);

// Socket.IO setup
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
    credentials: true
  },
  allowEIO3: true, // Support older socket.io-client versions (v2/v3)
  pingInterval: 25000,  // Tăng lên 25s (default) cho ngrok/railway
  pingTimeout: 20000,   // Timeout 20s
  perMessageDeflate: false, // Tắt để tránh conflict proxy
  transports: ['websocket', 'polling'] // Cho phép polling làm fallback khi websocket bị block
});

// Rate limiting
const apiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 phút
  max: 200, // 200 requests/phút/IP (thoải mái cho child heartbeat + parent polling)
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many requests, please try again later' },
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 phút
  max: 20, // 20 login/register attempts per 15 phút
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many login attempts, please try again after 15 minutes' },
});

// Middleware
app.use(helmet());
app.use(cors({ origin: '*' }));
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/api/', apiLimiter);
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);

// Static files — SOS audio uploads
const path = require('path');
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Import routes
const authRoutes = require('./routes/auth');
const profileRoutes = require('./routes/profiles');
const deviceRoutes = require('./routes/devices');
const monitoringRoutes = require('./routes/monitoring');
const blockedSiteRoutes = require('./routes/blockedSites');
const childRoutes = require('./routes/child');
const fcmRoutes = require('./routes/fcm');
const extensionRequestRoutes = require('./routes/extensionRequests');
const geofenceRoutes = require('./routes/geofences');
const sosRoutes = require('./routes/sos');
const webFilteringRoutes = require('./routes/webFiltering');
const youtubeRoutes = require('./routes/youtube');

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/profiles', profileRoutes);
app.use('/api/devices', deviceRoutes);
app.use('/api/monitoring', monitoringRoutes);
app.use('/api/blocked-sites', blockedSiteRoutes);
app.use('/api/child', childRoutes);
app.use('/api/fcm-tokens', fcmRoutes);
app.use('/api/extension-requests', extensionRequestRoutes);
app.use('/api/geofences', geofenceRoutes);
app.use('/api/sos', sosRoutes);
app.use('/api/web-categories', webFilteringRoutes);
app.use('/api', youtubeRoutes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    data: {
      status: 'OK',
      message: 'KidFun V3 API is running',
      timestamp: new Date().toISOString()
    }
  });
});

// Init Firebase (skip nếu không có config — dev mode)
const { initFirebase } = require('./services/firebaseService');
try {
  initFirebase();
  console.log('Firebase initialized');
} catch (err) {
  console.warn('Firebase not configured:', err.message);
}

// Socket.IO - sử dụng socketService
const socketService = require('./services/socketService');
socketService.init(io);

// ── Sprint 9: AI Analysis Worker (runs every 10 minutes) ────────────────
const aiWorker = require('./workers/aiAnalysisWorker');
aiWorker.setSocketIO(io);
setInterval(() => {
  aiWorker.runAnalysisBatch().catch(console.error);
}, 10 * 60 * 1000);
// Run once on startup after 30s delay (wait for DB connection to settle)
setTimeout(() => aiWorker.runAnalysisBatch().catch(console.error), 30 * 1000);

// ── Sprint 9: Report Scheduler (daily + weekly cron) ─────────────────────
const reportWorker = require('./workers/reportWorker');
reportWorker.startScheduler();

// ── Sprint 9: Admin manual trigger endpoints ──────────────────────────────
const { authenticate } = require('./middleware/auth');
const { getProviderStatus } = require('./services/aiService');
app.get('/api/admin/ai-status', authenticate, (req, res) => {
  res.json({ success: true, data: { providers: getProviderStatus() } });
});
app.post('/api/admin/run-ai-analysis', authenticate, (req, res) => {
  aiWorker.runAnalysisBatch().catch(console.error);
  res.json({ success: true, data: { message: 'AI analysis started' } });
});
app.post('/api/admin/run-daily-reports', authenticate, (req, res) => {
  reportWorker.runDailyReports().catch(console.error);
  res.json({ success: true, data: { message: 'Daily reports triggered' } });
});
app.post('/api/admin/run-weekly-reports', authenticate, (req, res) => {
  reportWorker.runWeeklyReports().catch(console.error);
  res.json({ success: true, data: { message: 'Weekly reports triggered' } });
});

// Error handling middleware
const errorHandler = require('./middleware/errorHandler');
app.use(errorHandler);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found', code: 'NOT_FOUND' });
});

// Start server (skip khi chạy test — supertest tự handle)
const PORT = process.env.PORT || 3001;
const HOST = process.env.HOST || '0.0.0.0';

// Reset all devices to offline when server starts
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
prisma.device.updateMany({
  data: { isOnline: false }
}).then(() => {
  console.log('📱 All devices reset to offline');
}).catch(err => {
  console.error('❌ Failed to reset devices:', err);
});

if (process.env.NODE_ENV !== 'test') {
  httpServer.listen(PORT, HOST, () => {
    console.log(`🚀 KidFun V3 Server running on http://${HOST}:${PORT}`);
    if (HOST === '0.0.0.0') {
      const nets = require('os').networkInterfaces();
      for (const name of Object.keys(nets)) {
        for (const net of nets[name]) {
          if (net.family === 'IPv4' && !net.internal) {
            console.log(`🌐 LAN: http://${net.address}:${PORT}`);
          }
        }
      }
    }
    console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
  });
}

module.exports = { app, io };