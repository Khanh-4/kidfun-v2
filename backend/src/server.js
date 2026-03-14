const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
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
  }
});

// Middleware
app.use(helmet());
app.use(cors({ origin: '*' }));
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Import routes
const authRoutes = require('./routes/auth');
const profileRoutes = require('./routes/profiles');
const deviceRoutes = require('./routes/devices');
const monitoringRoutes = require('./routes/monitoring');
const blockedSiteRoutes = require('./routes/blockedSites');
const childRoutes = require('./routes/child');
const fcmRoutes = require('./routes/fcm');

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/profiles', profileRoutes);
app.use('/api/devices', deviceRoutes);
app.use('/api/monitoring', monitoringRoutes);
app.use('/api/blocked-sites', blockedSiteRoutes);
app.use('/api/child', childRoutes);
app.use('/api/fcm-tokens', fcmRoutes);

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