import { io } from 'socket.io-client';

const SOCKET_URL = 'http://localhost:3001';

class SocketService {
  socket = null;
  listeners = {};

  connect(userId) {
    if (this.socket?.connected) return;

    this.socket = io(SOCKET_URL, {
      transports: ['websocket'],
    });

    this.socket.on('connect', () => {
      console.log('🔌 Parent connected to server');
      // Tham gia phòng gia đình
      this.socket.emit('joinFamily', { userId, role: 'parent' });
    });

    this.socket.on('disconnect', () => {
      console.log('❌ Parent disconnected');
    });

    // Lắng nghe yêu cầu thêm thời gian từ Child
    this.socket.on('timeExtensionRequest', (data) => {
      console.log('📩 Received time extension request:', data);
      if (this.listeners.onTimeExtensionRequest) {
        this.listeners.onTimeExtensionRequest(data);
      }
    });
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }

  // Đăng ký listener
  onTimeExtensionRequest(callback) {
    this.listeners.onTimeExtensionRequest = callback;
  }

  // Parent phản hồi yêu cầu
  respondTimeExtension(userId, approved, additionalMinutes, message) {
    if (this.socket) {
      this.socket.emit('respondTimeExtension', {
        userId,
        approved,
        additionalMinutes,
        message,
      });
    }
  }

  // Parent xóa thiết bị - thông báo đến Child
  removeDevice(userId, deviceId, deviceCode) {
    if (this.socket) {
      this.socket.emit('removeDevice', {
        userId,
        deviceId,
        deviceCode,
      });
    }
  }

}

export default new SocketService();