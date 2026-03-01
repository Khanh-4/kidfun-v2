import { io } from 'socket.io-client';

const SOCKET_URL = import.meta.env.VITE_SOCKET_URL || 'http://localhost:3001';

console.log('[ParentSocket] SOCKET_URL:', SOCKET_URL);

class SocketService {
  socket = null;
  listeners = {};

  connect(userId) {
    if (this.socket?.connected) return;

    console.log('[ParentSocket] Connecting to:', SOCKET_URL, 'userId:', userId);

    this.socket = io(SOCKET_URL, {
      transports: ['websocket', 'polling'],
      reconnectionAttempts: 10,
      reconnectionDelay: 2000,
    });

    this.socket.on('connect', () => {
      console.log('🔌 Parent connected to server, socketId:', this.socket.id);
      // Tham gia phòng gia đình
      console.log('[ParentSocket] Emitting joinFamily:', { userId, role: 'parent' });
      this.socket.emit('joinFamily', { userId, role: 'parent' });
    });

    this.socket.on('connect_error', (err) => {
      console.error('🔴 Parent socket connect_error:', err.message, 'URL:', SOCKET_URL);
    });

    this.socket.on('disconnect', (reason) => {
      console.log('❌ Parent disconnected, reason:', reason);
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