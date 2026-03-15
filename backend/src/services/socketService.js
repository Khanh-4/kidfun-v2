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

      // ── joinFamily: Parent hoặc Child tham gia phòng gia đình ──────────────
      socket.on('joinFamily', ({ userId, role }) => {
        if (userId === undefined || userId === null || userId === 0) {
          console.warn(`⚠️ [SOCKET] joinFamily: Invalid userId received: ${userId}`);
          return;
        }

        const room = `family_${userId}`;
        socket.join(room);
        socket.role = role || 'parent';
        socket.userId = userId;

        const clients = io.sockets.adapter.rooms.get(room);
        console.log(`👨‍👩‍👧 [SOCKET] ${socket.role} (${socket.id}) JOINED ${room}. Total in room: ${clients ? clients.size : 0}`);

        socket.emit('roomJoined', { room, size: clients ? clients.size : 0 });
      });

      // ── joinDevice: Child tham gia phòng thiết bị ─────────────────────────
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
            await prisma.device.update({
              where: { id: device.id },
              data: { isOnline: true, lastSeen: new Date() }
            });

            // Cache device info để dùng khi disconnect (tránh query DB lại)
            socket.deviceId = device.id;
            socket.deviceUserId = device.userId;
            socket.userId = device.userId;

            const familyRoom = `family_${device.userId}`;
            const parentClients = io.sockets.adapter.rooms.get(familyRoom);

            console.log(`🟢 [SOCKET] Device ${device.deviceName} (ID: ${device.id}) is ONLINE.`);
            console.log(`📣 [SOCKET] Notifying ${familyRoom}. Active parents in room: ${parentClients ? parentClients.size : 0}`);

            // Notify Parent: device is online
            io.to(familyRoom).emit('deviceOnline', {
              deviceId: device.id,
              profileId: device.profileId,
              deviceName: device.deviceName,
              profileName: device.profile?.profileName || null,
            });

            // Also emit device_status_changed for real-time status update
            io.to(familyRoom).emit('device_status_changed', {
              deviceId: device.id,
              isOnline: true,
              deviceName: device.deviceName,
            });

          } else {
            console.warn(`⚠️ [SOCKET] joinDevice: No device found in DB for code ${deviceCode}`);
          }
        } catch (err) {
          console.error('❌ [SOCKET] joinDevice error:', err);
        }
      });

      // ── Heartbeat: cập nhật lastSeen ──────────────────────────────────────
      socket.on('heartbeat', async ({ deviceCode }) => {
        const code = deviceCode || socket.deviceCode;
        if (!code) return;
        try {
          await prisma.device.updateMany({
            where: { deviceCode: code },
            data: { lastSeen: new Date(), isOnline: true },
          });
        } catch (err) { /* silent fail */ }
      });

      // ── Time Extension ─────────────────────────────────────────────────────
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

      // ── Remove Device ──────────────────────────────────────────────────────
      socket.on('removeDevice', (data) => {
        const uId = data.userId || socket.userId;
        const room = `family_${uId}`;
        console.log(`🗑️ [SOCKET] Device removed for family: ${room}`);
        io.to(room).emit('deviceRemoved', {
          deviceId: data.deviceId,
          deviceCode: data.deviceCode,
        });
      });

      // ── Disconnect ─────────────────────────────────────────────────────────
      socket.on('disconnect', async (reason) => {
        console.log(`❌ [SOCKET] Client disconnected: ${socket.id} (Role: ${socket.role || 'unknown'}, Family: ${socket.userId || '?'}). Reason: ${reason}`);

        if (socket.deviceCode) {
          try {
            // Use cached deviceId (fast path)
            let deviceId = socket.deviceId;
            let deviceUserId = socket.deviceUserId;

            if (!deviceId) {
              // Fallback: query DB
              const device = await prisma.device.findFirst({
                where: { deviceCode: socket.deviceCode }
              });
              if (device) {
                deviceId = device.id;
                deviceUserId = device.userId;
              }
            }

            if (deviceId) {
              await prisma.device.update({
                where: { id: deviceId },
                data: { isOnline: false, lastSeen: new Date() }
              });

              const familyRoom = `family_${deviceUserId}`;
              console.log(`🔴 [SOCKET] Device ID ${deviceId} is OFFLINE. Notifying ${familyRoom}`);

              io.to(familyRoom).emit('deviceOffline', { deviceId });

              // Also emit device_status_changed
              io.to(familyRoom).emit('device_status_changed', {
                deviceId,
                isOnline: false,
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