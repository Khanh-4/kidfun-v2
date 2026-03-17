const admin = require('firebase-admin');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();let firebaseInitialized = false;

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

  const message = {
    token,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    )
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

  const message = {
    tokens,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    )
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`Push sent: ${response.successCount} success, ${response.failureCount} failure`);

    // Collect invalid tokens for cleanup
    const invalidTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const errCode = resp.error?.code;
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
