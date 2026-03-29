import { io } from 'socket.io-client';

const SOCKET_URL = import.meta.env.VITE_SOCKET_URL || 'http://localhost:3001';

class SocketService {
    socket = null;
    listeners = {};

    connect(userId, deviceCode) {
        if (this.socket?.connected) return;

        this.socket = io(SOCKET_URL, {
            transports: ['websocket', 'polling'],
            reconnectionAttempts: 10,
            reconnectionDelay: 2000,
        });

        this.socket.on('connect', () => {
            console.log('[ChildSocket] Connected, socketId:', this.socket.id);
            // Join family room
            this.socket.emit('joinFamily', { userId, role: 'child' });
            // Join device room so we receive device-targeted events
            // (timeExtensionResponse, timeLimitUpdated from controller, etc.)
            if (deviceCode) {
                this.socket.emit('joinDevice', { deviceCode });
            }
        });

        this.socket.on('connect_error', (err) => {
            console.error('[ChildSocket] connect_error:', err.message);
        });

        this.socket.on('disconnect', (reason) => {
            console.log('[ChildSocket] disconnected:', reason);
        });

        // Parent removed this device
        this.socket.on('deviceRemoved', () => {
            if (this.listeners.onDeviceRemoved) {
                this.listeners.onDeviceRemoved();
            }
        });

        // Parent responded to time extension request
        this.socket.on('timeExtensionResponse', (data) => {
            console.log('[ChildSocket] timeExtensionResponse:', data);
            if (this.listeners.onTimeExtensionResponse) {
                this.listeners.onTimeExtensionResponse(data);
            }
        });

        // Parent changed time limit
        this.socket.on('timeLimitUpdated', (data) => {
            console.log('[ChildSocket] timeLimitUpdated:', data);
            if (this.listeners.onTimeLimitUpdated) {
                this.listeners.onTimeLimitUpdated(data);
            }
        });

        // Parent updated blocked sites
        this.socket.on('blockedSitesUpdated', (data) => {
            console.log('[ChildSocket] blockedSitesUpdated:', data);
            if (this.listeners.onBlockedSitesUpdated) {
                this.listeners.onBlockedSitesUpdated(data);
            }
        });

        // Parent updated blocked apps
        this.socket.on('blockedAppsUpdated', (data) => {
            console.log('[ChildSocket] blockedAppsUpdated:', data);
            if (this.listeners.onBlockedAppsUpdated) {
                this.listeners.onBlockedAppsUpdated(data);
            }
        });
    }

    disconnect() {
        if (this.socket) {
            this.socket.disconnect();
            this.socket = null;
        }
    }

    // Register listeners
    onTimeExtensionResponse(callback) {
        this.listeners.onTimeExtensionResponse = callback;
    }

    onDeviceRemoved(callback) {
        this.listeners.onDeviceRemoved = callback;
    }

    onTimeLimitUpdated(callback) {
        this.listeners.onTimeLimitUpdated = callback;
    }

    onBlockedSitesUpdated(callback) {
        this.listeners.onBlockedSitesUpdated = callback;
    }

    onBlockedAppsUpdated(callback) {
        this.listeners.onBlockedAppsUpdated = callback;
    }

    // Child requests more time via socket
    // Uses correct field names matching backend: deviceCode + requestMinutes
    requestTimeExtension(deviceCode, requestMinutes, reason) {
        if (this.socket) {
            this.socket.emit('requestTimeExtension', {
                deviceCode,
                requestMinutes,
                reason,
            });
        } else {
            console.error('[ChildSocket] Cannot emit - socket is null!');
        }
    }
}

export default new SocketService();
