const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const socketService = {
  io: null,

  init(io) {
    this.io = io;

    io.on('connection', (socket) => {
      console.log('🔌 Client connected:', socket.id);

      // Child hoặc Parent tham gia "phòng" của gia đình
      socket.on('joinFamily', ({ userId, role }) => {
        const room = `family_${userId}`;
        socket.join(room);
        socket.role = role;
        socket.userId = userId;
        const clients = io.sockets.adapter.rooms.get(room);
        console.log(`👨‍👩‍👧 ${role} (${socket.id}) joined ${room} — room now has ${clients ? clients.size : 0} members:`, clients ? [...clients] : []);
      });

      // Child gửi yêu cầu thêm thời gian
      socket.on('requestTimeExtension', (data) => {
        console.log('⏰ Time extension request from:', socket.id, 'data:', data);
        const room = `family_${data.userId}`;
        const clients = io.sockets.adapter.rooms.get(room);
        console.log(`⏰ Room ${room} has ${clients ? clients.size : 0} clients:`, clients ? [...clients] : []);
        // Gửi đến tất cả Parent trong gia đình
        io.to(room).emit('timeExtensionRequest', {
          id: Date.now(),
          deviceName: data.deviceName,
          profileName: data.profileName,
          reason: data.reason,
          requestedMinutes: data.requestedMinutes || 30,
          timestamp: new Date().toISOString(),
        });
      });

      // Parent xóa thiết bị
      socket.on('removeDevice', (data) => {
        console.log('🗑️ Device removed:', data);
        // Thông báo đến tất cả client trong gia đình
        io.to(`family_${data.userId}`).emit('deviceRemoved', {
          deviceId: data.deviceId,
          deviceCode: data.deviceCode,
        });
      });

      // Parent phản hồi yêu cầu
      socket.on('respondTimeExtension', (data) => {
        console.log('✅ Time extension response:', data);
        // Gửi kết quả đến Child
        io.to(`family_${data.userId}`).emit('timeExtensionResponse', {
          approved: data.approved,
          additionalMinutes: data.additionalMinutes || 0,
          message: data.message,
        });
      });

      // Child join device room
      socket.on('joinDevice', async ({ deviceCode }) => {
        socket.deviceCode = deviceCode;
        socket.join(`device_${deviceCode}`);
        console.log(`📱 Device ${deviceCode} joined`);

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

            // Notify Parent
            io.to(`family_${device.userId}`).emit('deviceOnline', {
              deviceId: device.id,
              profileId: device.profileId,
              deviceName: device.deviceName,
            });
            
            console.log(`🟢 Device ${device.deviceName} is ONLINE`);
          }
        } catch (err) {
          console.error('joinDevice error:', err);
        }
      });

      socket.on('disconnect', async (reason) => {
        console.log(`❌ Client disconnected: ${socket.id} (${socket.role || 'unknown'} of family_${socket.userId || '?'}), reason: ${reason}`);
        
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

              io.to(`family_${device.userId}`).emit('deviceOffline', {
                deviceId: device.id,
              });
              
              console.log(`🔴 Device ${device.deviceName} is OFFLINE`);
            }
          } catch (err) {
            console.error('disconnect error:', err);
          }
        }
      });
    });
  },

  // Gửi thông báo đến gia đình cụ thể
  notifyFamily(userId, event, data) {
    if (this.io) {
      this.io.to(`family_${userId}`).emit(event, data);
    }
  },
};

module.exports = socketService;