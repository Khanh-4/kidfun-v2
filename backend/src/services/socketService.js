const socketService = {
  io: null,

  init(io) {
    this.io = io;

    io.on('connection', (socket) => {
      console.log('🔌 Client connected:', socket.id);

      // Child hoặc Parent tham gia "phòng" của gia đình
      socket.on('joinFamily', ({ userId, role }) => {
        socket.join(`family_${userId}`);
        socket.role = role;
        socket.userId = userId;
        console.log(`👨‍👩‍👧 ${role} joined family_${userId}`);
      });

      // Child gửi yêu cầu thêm thời gian
      socket.on('requestTimeExtension', (data) => {
        console.log('⏰ Time extension request:', data);
        // Gửi đến tất cả Parent trong gia đình
        io.to(`family_${data.userId}`).emit('timeExtensionRequest', {
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
        console.log('✅ Time extension response:', data);
        // Gửi kết quả đến Child
        io.to(`family_${data.userId}`).emit('timeExtensionResponse', {
          approved: data.approved,
          additionalMinutes: data.additionalMinutes || 0,
          message: data.message,
        });
      });

      socket.on('disconnect', () => {
        console.log('❌ Client disconnected:', socket.id);
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