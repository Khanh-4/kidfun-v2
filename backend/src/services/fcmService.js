const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const { sendPushToUser, sendToMultipleTokens } = require('./firebaseService');

/**
 * Push notification khi child vào/ra khỏi geofence.
 * @param {object} profile - Prisma Profile (cần .userId, .profileName, .id)
 * @param {object} geofence - Prisma Geofence (cần .name, .id)
 * @param {string} eventType - "ENTER" | "EXIT"
 */
exports.sendGeofencePushNotification = async (profile, geofence, eventType) => {
  if (!profile) return;
  try {
    const title = eventType === 'ENTER'
      ? `${profile.profileName} đã vào ${geofence.name}`
      : `${profile.profileName} đã rời ${geofence.name}`;

    const body = eventType === 'ENTER'
      ? `Con đã đến ${geofence.name} an toàn`
      : `Con vừa rời khỏi ${geofence.name}`;

    await sendPushToUser(profile.userId, {
      title,
      body,
      data: {
        type: 'GEOFENCE_EVENT',
        eventType,
        profileId: String(profile.id),
        geofenceId: String(geofence.id),
      },
    });
  } catch (err) {
    console.error('❌ [FCM Geofence] Error:', err.message);
  }
};

/**
 * Push notification SOS khẩn cấp — dùng channel sos_critical, priority max.
 * @param {object} user - Prisma User (cần .id)
 * @param {object} profile - Prisma Profile (cần .profileName, .id)
 * @param {object} sos - Prisma SOSAlert (cần .id, .latitude, .longitude)
 */
exports.sendSOSPushNotification = async (user, profile, sos) => {
  if (!user || !profile) return;
  try {
    const tokens = await prisma.fCMToken.findMany({
      where: { userId: user.id },
    });
    if (tokens.length === 0) return;

    const tokenStrings = tokens.map(t => t.token);

    // Override android channel sang sos_critical cho SOS
    await sendToMultipleTokens(
      tokenStrings,
      `🆘 SOS KHẨN CẤP từ ${profile.profileName}`,
      'Con đang cần giúp đỡ! Nhấn để xem vị trí.',
      {
        type: 'SOS_ALERT',
        sosId: String(sos.id),
        profileId: String(profile.id),
        latitude: String(sos.latitude),
        longitude: String(sos.longitude),
      },
    );

    // Log riêng để dễ debug SOS
    console.log(`🆘 [FCM SOS] Sent to ${tokenStrings.length} token(s) for profile ${profile.profileName}`);
  } catch (err) {
    console.error('❌ [FCM SOS] Error:', err.message);
  }
};
