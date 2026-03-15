const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const socketService = {
  io: null,

  init(io) {
    this.io = io;

    io.on('connection', (socket) => {
      console.log(`🔌 [SOCKET] Client connected: ${socket.id} (Total: ${io.engine.clientsCount})`);

      // Heartbeat
      socket.on('ping', (data) => {
        socket.emit('pong', data);
      });

      // Child hoặc Parent tham gia "phòng" của gia đình
      socket.on('joinFamily', ({ userId, role }) => {
        // Tránh lỗi với userId = 0 hoặc null
        if (userId === undefined || userId === null || userId === 0) {
          console.warn(`⚠️ [SOCKET] joinFamily: Invalid userId received: ${userId}`);
          return;
        }

        const room = `family_${userId}`;
        socket.join(room);
        socket.role = role || 'parent';
        socket.userId = userId;
        
        // Kiểm tra room size
        const clients = io.sockets.adapter.rooms.get(room);
        console.log(`👨‍👩‍👧 [SOCKET] ${socket.role} (${socket.id}) JOINED ${room}. Total in room: ${clients ? clients.size : 0}`);
        
        // Notify socket that join was successful
        socket.emit('roomJoined', { room, size: clients ? clients.size : 0 });
      });

      // Child join device room
      socket.on('joinDevice', async ({ deviceCode }) => {
        if (!deviceCode) {
          console.warn('⚠️ [SOCKET] joinDevice: No deviceCode provided');
          return;
        }
        
        socket.deviceCode = deviceCode;
        socket.role = 'child';
        socket.join(`device_${deviceCode}`);
        console.log(`📱 [SOCKET] Child Device ${deviceCode} JOINED room device_${deviceCode}`);

        try {
          const device = await prisma.device.findFirst({ 
            where: { deviceCode },
            include: { profile: true }
          });
          
          if (device) {
            // Update status online trong DB
            await prisma.device.update({
              where: { id: device.id },
              data: { isOnline: true, lastSeen: new Date() }
            });

            socket.userId = device.userId;

            // Notify Parent
            const familyRoom = `family_${device.userId}`;
            const parentClients = io.sockets.adapter.rooms.get(familyRoom);
            
            console.log(`🟢 [SOCKET] Device ${device.deviceName} (ID: ${device.id}) is ONLINE.`);
            console.log(`📣 [SOCKET] Notifying ${familyRoom}. Active parents in room: ${parentClients ? parentClients.size : 0}`);
            
            // Emit to family room
            io.to(familyRoom).emit('deviceOnline', {
              deviceId: device.id,
              profileId: device.profileId,
              deviceName: device.deviceName,
            });
            
            // Broadcast to the specifically joined device room too (if any other part of app listens)
            io.to(`device_${deviceCode}`).emit('statusUpdated', { isOnline: true });

          } else {
            console.warn(`⚠️ [SOCKET] joinDevice: No device found in DB for code ${deviceCode}`);
          }
        } catch (err) {
          console.error('❌ [SOCKET] joinDevice error:', err);
        }
      });

      // Child gửi yêu cầu thêm thời gian
      socket.on('requestTimeExtension', (data) => {
        const uId = data.userId || socket.userId;
        const room = `family_${uId}`;
        console.log(`⏰ [SOCKET] Time extension request for family: ${room}`);
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
        const uId = data.userId || socket.userId;
        const room = `family_${uId}`;
        console.log(`✅ [SOCKET] Time extension response for family: ${room}`);
        io.to(room).emit('timeExtensionResponse', {
          approved: data.approved,
          additionalMinutes: data.additionalMinutes || 0,
          message: data.message,
        });
      });

      // Parent xóa thiết bị
      socket.on('removeDevice', (data) => {
        const uId = data.userId || socket.userId;
        const room = `family_${uId}`;
        console.log(`🗑️ [SOCKET] Device removed for family: ${room}`);
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
      const room = `family_${userId}`;
      console.log(`📣 [SOCKET] External Notification: ${room} -> ${event}`);
      this.io.to(room).emit(event, data);
    }
  },
};

module.exports = socketService;