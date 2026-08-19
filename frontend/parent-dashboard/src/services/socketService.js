import { io } from 'socket.io-client';

const SOCKET_URL = import.meta.env.VITE_SOCKET_URL || 'http://localhost:3001';

class SocketService {
  socket = null;
  listeners = {};

  connect(userId) {
    if (this.socket?.connected) return;

    this.socket = io(SOCKET_URL, {
      transports: ['websocket', 'polling'],
      reconnectionAttempts: 10,
      reconnectionDelay: 2000,
    });

    this.socket.on('connect', () => {
      console.log('[ParentSocket] Connected, socketId:', this.socket.id);
      this.socket.emit('joinFamily', { userId, role: 'parent' });
    });

    this.socket.on('connect_error', (err) => {
      console.error('[ParentSocket] connect_error:', err.message);
    });

    this.socket.on('disconnect', (reason) => {
      console.log('[ParentSocket] disconnected:', reason);
    });

    // Time extension request from child
    this.socket.on('timeExtensionRequest', (data) => {
      if (this.listeners.onTimeExtensionRequest) {
        this.listeners.onTimeExtensionRequest(data);
      }
    });

    // Device online/offline events
    this.socket.on('deviceOnline', (data) => {
      if (this.listeners.onDeviceOnline) this.listeners.onDeviceOnline(data);
    });

    this.socket.on('deviceOffline', (data) => {
      if (this.listeners.onDeviceOffline) this.listeners.onDeviceOffline(data);
    });

    this.socket.on('device_status_changed', (data) => {
      if (this.listeners.onDeviceStatusChanged) this.listeners.onDeviceStatusChanged(data);
    });

    // New device linked
    this.socket.on('deviceLinked', (data) => {
      if (this.listeners.onDeviceLinked) this.listeners.onDeviceLinked(data);
    });

    // Soft warning from child
    this.socket.on('softWarning', (data) => {
      if (this.listeners.onSoftWarning) this.listeners.onSoftWarning(data);
    });
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }

  // Register listeners
  onTimeExtensionRequest(callback) {
    this.listeners.onTimeExtensionRequest = callback;
  }

  onDeviceOnline(callback) {
    this.listeners.onDeviceOnline = callback;
  }

  onDeviceOffline(callback) {
    this.listeners.onDeviceOffline = callback;
  }

  onDeviceStatusChanged(callback) {
    this.listeners.onDeviceStatusChanged = callback;
  }

  onDeviceLinked(callback) {
    this.listeners.onDeviceLinked = callback;
  }

  onSoftWarning(callback) {
    this.listeners.onSoftWarning = callback;
  }

  // Parent responds to time extension request
  // Uses correct field names: requestId + responseMinutes (matching backend)
  respondTimeExtension(requestId, approved, responseMinutes) {
    if (this.socket) {
      this.socket.emit('respondTimeExtension', {
        requestId,
        approved,
        responseMinutes,
      });
    }
  }

  // Parent removes device - notify child
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
