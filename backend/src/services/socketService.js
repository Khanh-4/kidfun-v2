const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const socketService = {
  io: null,

  init(io) {
    this.io = io;

    io.on('connection', (socket) => {
      console.log(`🔌 [SOCKET] Client connected: ${socket.id} (Total: ${io.engine.clientsCount})`);

      // Child hoặc Parent tham gia "phòng" của gia đình
      socket.on('joinFamily', ({ userId, role }) => {
        if (!userId) return;
        const room = `family_${userId}`;
        socket.join(room);
        socket.role = role || 'parent';
        socket.userId = userId;
        const clients = io.sockets.adapter.rooms.get(room);
        console.log(`👨‍👩‍👧 [SOCKET] ${socket.role} (${socket.id}) joined ${room}. Room size: ${clients ? clients.size : 0}`);
      });

      // Child join device room
      socket.on('joinDevice', async ({ deviceCode }) => {
        if (!deviceCode) return;
        socket.deviceCode = deviceCode;
        socket.role = 'child';
        socket.join(`device_${deviceCode}`);
        console.log(`📱 [SOCKET] Device ${deviceCode} joined room`);

        try {
          const device = await prisma.device.findFirst({ 
            where: { deviceCode },
            include: { profile: true }
          });
          
          if (device) {
            // Update status online
            await prisma.device.update({
              where: { id: device.id },
              data: { isOnline: true, lastSeen: new Date() }
            });

            // Gán userId cho socket để khi disconnect biết báo cho ai
            socket.userId = device.userId;

            // Notify Parent
            const familyRoom = `family_${device.userId}`;
            console.log(`🟢 [SOCKET] Device ${device.deviceName} (ID: ${device.id}) is ONLINE. Notifying ${familyRoom}`);
            
            io.to(familyRoom).emit('deviceOnline', {
              deviceId: device.id,
              profileId: device.profileId,
              deviceName: device.deviceName,
            });
          } else {
            console.warn(`⚠️ [SOCKET] joinDevice: No device found for code ${deviceCode}`);
          }
        } catch (err) {
          console.error('❌ [SOCKET] joinDevice error:', err);
        }
      });

      // Child gửi yêu cầu thêm thời gian
      socket.on('requestTimeExtension', (data) => {
        console.log('⏰ [SOCKET] Time extension request:', data);
        const room = `family_${data.userId || socket.userId}`;
        io.to(room).emit('timeExtensionRequest', {
          id: Date.now(),
          deviceName: data.deviceName,
          profileName: data.profileName,
          reason: data.reason,
          requestedMinutes: data.requestedMinutes || 30,
          timestamp: new Date().toISOString(),
        });
      });

      // Parent phản hồi yêu cầu
      socket.on('respondTimeExtension', (data) => {
        console.log('✅ [SOCKET] Time extension response:', data);
        const room = `family_${data.userId || socket.userId}`;
        io.to(room).emit('timeExtensionResponse', {
          approved: data.approved,
          additionalMinutes: data.additionalMinutes || 0,
          message: data.message,
        });
      });

      // Parent xóa thiết bị
      socket.on('removeDevice', (data) => {
        console.log('🗑️ [SOCKET] Device removed:', data);
        const room = `family_${data.userId || socket.userId}`;
        io.to(room).emit('deviceRemoved', {
          deviceId: data.deviceId,
          deviceCode: data.deviceCode,
        });
      });

      socket.on('disconnect', async (reason) => {
        console.log(`❌ [SOCKET] Client disconnected: ${socket.id} (Role: ${socket.role || 'unknown'}, Family: ${socket.userId || '?'}). Reason: ${reason}`);
        
        if (socket.deviceCode) {
          try {
            const device = await prisma.device.findFirst({ 
              where: { deviceCode: socket.deviceCode } 
            });
            
            if (device) {
              await prisma.device.update({
                where: { id: device.id },
                data: { isOnline: false, lastSeen: new Date() }
              });

              const familyRoom = `family_${device.userId}`;
              console.log(`🔴 [SOCKET] Device ${device.deviceName} is OFFLINE. Notifying ${familyRoom}`);
              io.to(familyRoom).emit('deviceOffline', {
                deviceId: device.id,
              });
            }
          } catch (err) {
            console.error('❌ [SOCKET] disconnect error:', err);
          }
        }
      });
    });
  },

  notifyFamily(userId, event, data) {
    if (this.io) {
      console.log(`📣 [SOCKET] Notifying family_${userId} of event ${event}`);
      this.io.to(`family_${userId}`).emit(event, data);
    }
  },
};

module.exports = socketService;