import { io } from 'socket.io-client';

const SOCKET_URL = import.meta.env.VITE_SOCKET_URL || 'http://localhost:3001';

class SocketService {
    socket = null;
    listeners = {};

    connect(userId) {
        if (this.socket?.connected) return;

        this.socket = io(SOCKET_URL, {
            transports: ['websocket'],
        });

        this.socket.on('connect', () => {
            console.log('🔌 Child connected to server');
            // Tham gia phòng gia đình
            this.socket.emit('joinFamily', { userId, role: 'child' });
        });

        this.socket.on('disconnect', () => {
            console.log('❌ Child disconnected');
        });

        // Lắng nghe khi Parent xóa thiết bị
        this.socket.on('deviceRemoved', () => {
            console.log('🚫 Device removed by parent');
            if (this.listeners.onDeviceRemoved) {
                this.listeners.onDeviceRemoved();
            }
        });

        // Lắng nghe phản hồi từ Parent
        this.socket.on('timeExtensionResponse', (data) => {
            console.log('📩 Received response:', data);
            if (this.listeners.onTimeExtensionResponse) {
                this.listeners.onTimeExtensionResponse(data);
            }
        });

        // Lắng nghe khi Parent thay đổi giới hạn thời gian
        this.socket.on('timeLimitUpdated', (data) => {
            console.log('⏱️ Time limit updated by parent:', data);
            if (this.listeners.onTimeLimitUpdated) {
                this.listeners.onTimeLimitUpdated(data);
            }
        });

        // Lắng nghe khi Parent thay đổi danh sách chặn website
        this.socket.on('blockedSitesUpdated', (data) => {
            console.log('🚫 Blocked sites updated by parent:', data);
            if (this.listeners.onBlockedSitesUpdated) {
                this.listeners.onBlockedSitesUpdated(data);
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
    onTimeExtensionResponse(callback) {
        this.listeners.onTimeExtensionResponse = callback;
    }

    // Lắng nghe khi Parent xóa thiết bị
    onDeviceRemoved(callback) {
        this.listeners.onDeviceRemoved = callback;
    }

    // Lắng nghe khi Parent thay đổi giới hạn thời gian
    onTimeLimitUpdated(callback) {
        this.listeners.onTimeLimitUpdated = callback;
    }

    // Lắng nghe khi Parent thay đổi danh sách chặn website
    onBlockedSitesUpdated(callback) {
        this.listeners.onBlockedSitesUpdated = callback;
    }

    // Child gửi yêu cầu thêm thời gian
    requestTimeExtension(userId, deviceName, reason, requestedMinutes = 30) {
        if (this.socket) {
            this.socket.emit('requestTimeExtension', {
                userId,
                deviceName,
                reason,
                requestedMinutes,
            });
        }
    }
}

export default new SocketService();