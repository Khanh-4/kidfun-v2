const admin = require('firebase-admin');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
let firebaseInitialized = false; // BUG 3 FIX: newline added (was concatenated on one line)

/**
 * Initialize Firebase Admin SDK
 * - Production: đọc env FIREBASE_SERVICE_ACCOUNT (JSON string)
 * - Local: đọc file firebase-service-account.json
 */
function initFirebase() {
  if (firebaseInitialized) return;

  let serviceAccount;

  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } else {
    const path = require('path');
    const fs = require('fs');
    const filePath = path.resolve(__dirname, '../../firebase-service-account.json');

    if (!fs.existsSync(filePath)) {
      throw new Error('Firebase service account file not found and FIREBASE_SERVICE_ACCOUNT env not set');
    }

    serviceAccount = require(filePath);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });

  firebaseInitialized = true;
}

/**
 * Gửi push notification đến 1 device
 * @param {string} token - FCM token
 * @param {string} title - Tiêu đề
 * @param {string} body - Nội dung
 * @param {object} data - Data payload (key-value strings)
 */
async function sendPushNotification(token, title, body, data = {}) {
  if (!firebaseInitialized) {
    console.warn('Firebase not initialized, skipping push notification');
    return null;
  }

  // TEST 9 FIX: `notification` must be explicitly present at the top level for Android
  // to show a popup when the app is in the background. A data-only payload is silently
  // dropped by Android unless delivered via a high-priority FCM message.
  const message = {
    token,
    notification: { title, body }, // REQUIRED FOR BACKGROUND POPUPS
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
    android: {
      priority: 'high', // wake device from Doze mode
      notification: {
        channelId: 'default',
        sound: 'default',
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: { sound: 'default' } },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Push notification sent:', response);
    return response;
  } catch (error) {
    console.error('Failed to send push notification:', error.message);
    // Nếu token invalid, trả về error code để caller có thể xóa token
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      return { error: 'INVALID_TOKEN', token };
    }
    throw error;
  }
}

/**
 * Gửi push notification đến nhiều devices
 * @param {string[]} tokens - Danh sách FCM tokens
 * @param {string} title - Tiêu đề
 * @param {string} body - Nội dung
 * @param {object} data - Data payload (key-value strings)
 */
async function sendToMultipleTokens(tokens, title, body, data = {}) {
  if (!firebaseInitialized) {
    console.warn('Firebase not initialized, skipping push notification');
    return null;
  }

  if (!tokens || tokens.length === 0) return null;

  // TEST 9 FIX: same as sendPushNotification — `notification` + `android.priority: 'high'`
  // required for multicast background delivery on Android.
  const message = {
    tokens,
    notification: { title, body }, // REQUIRED FOR BACKGROUND POPUPS
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
    android: {
      priority: 'high',
      notification: {
        channelId: 'default',
        sound: 'default',
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: { sound: 'default' } },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`🔔 [FCM] sendEachForMulticast → successCount=${response.successCount} failureCount=${response.failureCount} (total tokens: ${tokens.length})`);

    // Collect invalid tokens for cleanup + log each result for debugging
    const invalidTokens = [];
    response.responses.forEach((resp, idx) => {
      if (resp.success) {
        console.log(`✅ [FCM] Token[${idx}] sent OK — messageId: ${resp.messageId}`);
      } else {
        const errCode = resp.error?.code;
        const errMsg = resp.error?.message;
        console.error(`❌ [FCM] Token[${idx}] FAILED — code: ${errCode} | message: ${errMsg}`);
        if (errCode === 'messaging/invalid-registration-token' ||
            errCode === 'messaging/registration-token-not-registered') {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    return { ...response, invalidTokens };
  } catch (error) {
    console.error('Failed to send multicast push:', error.message);
    throw error;
  }
}

/**
 * Gửi push notification cho tất cả devices của 1 user
 */
async function sendPushToUser(userId, { title, body, data = {} }) {
  // BUG 3 FIX: auto-initialize Firebase defensively so FCM works even if startup call fails
  try { initFirebase(); } catch (_) {}
  try {
    const tokens = await prisma.fCMToken.findMany({
      where: { userId },
    });

    if (tokens.length === 0) return;

    const tokenStrings = tokens.map(t => t.token);
    await sendToMultipleTokens(tokenStrings, title, body, data);
  } catch (err) {
    console.error('Push to user failed:', err.message);
  }
}

module.exports = {
  initFirebase,
  sendPushNotification,
  sendToMultipleTokens,
  sendPushToUser
};
