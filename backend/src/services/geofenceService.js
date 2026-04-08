const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { haversineDistance } = require('../utils/geoUtils');

// In-memory cache: { "profileId_geofenceId": true/false (isInside) }
const geofenceState = new Map();

/**
 * Kiểm tra ENTER/EXIT cho tất cả geofences active của profile.
 * Gọi mỗi khi nhận GPS mới từ child.
 */
exports.checkGeofenceEvents = async (profileId, lat, lng, _io) => {
  const socketService = require('./socketService');
  const io = socketService.io;
  try {
    const geofences = await prisma.geofence.findMany({
      where: { profileId, isActive: true },
    });

    for (const fence of geofences) {
      const distance = haversineDistance(lat, lng, fence.latitude, fence.longitude);
      const isInside = distance <= fence.radius;
      const cacheKey = `${profileId}_${fence.id}`;
      const wasInside = geofenceState.get(cacheKey);

      // First check → ghi nhớ trạng thái, không emit event
      if (wasInside === undefined) {
        geofenceState.set(cacheKey, isInside);
        continue;
      }

      // Không thay đổi → bỏ qua
      if (wasInside === isInside) continue;

      // Trạng thái thay đổi → tạo GeofenceEvent
      const eventType = isInside ? 'ENTER' : 'EXIT';
      geofenceState.set(cacheKey, isInside);

      const event = await prisma.geofenceEvent.create({
        data: {
          geofenceId: fence.id,
          profileId,
          type: eventType,
          latitude: lat,
          longitude: lng,
        },
      });

      // Lấy thông tin profile để emit Socket.IO
      const profile = await prisma.profile.findUnique({
        where: { id: profileId },
      });

      if (io && profile) {
        io.to(`family_${profile.userId}`).emit('geofenceEvent', {
          eventId: event.id,
          type: eventType,
          geofenceName: fence.name,
          profileName: profile.profileName,
          latitude: lat,
          longitude: lng,
          timestamp: event.createdAt,
        });
      }

      // Push notification (Task 7)
      const { sendGeofencePushNotification } = require('./fcmService');
      await sendGeofencePushNotification(profile, fence, eventType);
    }
  } catch (err) {
    console.error('❌ [checkGeofenceEvents] Error:', err.message);
  }
};
