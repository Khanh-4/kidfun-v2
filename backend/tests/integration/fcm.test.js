const request = require('supertest');

// Env do tests/setup-env.js nạp (.env.test, có chặn nếu trỏ vào production)

const app = require('../../src/server');

const TEST_EMAIL = `fcm_test_${Date.now()}@kidfun.test`;
const TEST_PASSWORD = 'TestPass123!';
const FAKE_FCM_TOKEN = 'fake-fcm-token-' + Date.now();
const UNKNOWN_PLATFORM_TOKEN = 'unknown-platform-token-' + Date.now();

let accessToken;

describe('FCM Token API', () => {
  // Setup: register a user and get token
  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
        fullName: 'FCM Test User'
      });
    accessToken = res.body.data.token;
  });

  describe('POST /api/fcm-tokens/register', () => {
    it('should register FCM token successfully', async () => {
      const res = await request(app)
        .post('/api/fcm-tokens/register')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          token: FAKE_FCM_TOKEN,
          platform: 'ANDROID'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.message).toBe('Token registered');
    });

    it('should upsert if same token registered again', async () => {
      const res = await request(app)
        .post('/api/fcm-tokens/register')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          token: FAKE_FCM_TOKEN,
          platform: 'IOS'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('should fail without auth', async () => {
      const res = await request(app)
        .post('/api/fcm-tokens/register')
        .send({
          token: 'some-token',
          platform: 'ANDROID'
        });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it('should fail without token field', async () => {
      const res = await request(app)
        .post('/api/fcm-tokens/register')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ platform: 'ANDROID' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('INVALID_INPUT');
    });

    // fcmController CỐ Ý không từ chối platform lạ mà fallback về ANDROID
    // ("Gracefully resolve platform and safe fallback"): mất token FCM đồng
    // nghĩa với mất toàn bộ push notification của thiết bị đó, tệ hơn nhiều so
    // với việc lưu sai nhãn platform. Test cũ kỳ vọng 400 là viết theo thiết kế
    // trước đó, không phải hành vi hiện tại.
    it('should fall back to ANDROID for an unknown platform', async () => {
      const res = await request(app)
        .post('/api/fcm-tokens/register')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          token: UNKNOWN_PLATFORM_TOKEN,
          platform: 'WINDOWS'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('should fail when token is missing', async () => {
      const res = await request(app)
        .post('/api/fcm-tokens/register')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ platform: 'ANDROID' });

      expect(res.status).toBe(400);
      expect(res.body.code).toBe('INVALID_INPUT');
    });
  });

  describe('POST /api/fcm-tokens/unregister', () => {
    it('should unregister FCM token successfully', async () => {
      const res = await request(app)
        .post('/api/fcm-tokens/unregister')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ token: FAKE_FCM_TOKEN });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.message).toBe('Token removed');
    });

    it('should fail when token not found', async () => {
      const res = await request(app)
        .post('/api/fcm-tokens/unregister')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ token: 'nonexistent-token' });

      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
    });

    it('should fail without auth', async () => {
      const res = await request(app)
        .post('/api/fcm-tokens/unregister')
        .send({ token: 'some-token' });

      expect(res.status).toBe(401);
    });
  });

  // Cleanup
  afterAll(async () => {
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    try {
      await prisma.fCMToken.deleteMany({
      where: { token: { in: [FAKE_FCM_TOKEN, UNKNOWN_PLATFORM_TOKEN] } }
    });
      await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    } catch (e) {
      // ignore
    }
    await prisma.$disconnect();
  });
});
