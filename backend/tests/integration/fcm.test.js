const request = require('supertest');

require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });

const { app } = require('../../src/server');

const TEST_EMAIL = `fcm_test_${Date.now()}@kidfun.test`;
const TEST_PASSWORD = 'TestPass123!';
const FAKE_FCM_TOKEN = 'fake-fcm-token-' + Date.now();

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

    it('should fail with invalid platform', async () => {
      const res = await request(app)
        .post('/api/fcm-tokens/register')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          token: 'another-token',
          platform: 'WINDOWS'
        });

      expect(res.status).toBe(400);
      expect(res.body.code).toBe('INVALID_INPUT');
    });
  });

  describe('DELETE /api/fcm-tokens/unregister', () => {
    it('should unregister FCM token successfully', async () => {
      const res = await request(app)
        .delete('/api/fcm-tokens/unregister')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ token: FAKE_FCM_TOKEN });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.message).toBe('Token removed');
    });

    it('should fail when token not found', async () => {
      const res = await request(app)
        .delete('/api/fcm-tokens/unregister')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ token: 'nonexistent-token' });

      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
    });

    it('should fail without auth', async () => {
      const res = await request(app)
        .delete('/api/fcm-tokens/unregister')
        .send({ token: 'some-token' });

      expect(res.status).toBe(401);
    });
  });

  // Cleanup
  afterAll(async () => {
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    try {
      await prisma.fCMToken.deleteMany({ where: { token: FAKE_FCM_TOKEN } });
      await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    } catch (e) {
      // ignore
    }
    await prisma.$disconnect();
  });
});
