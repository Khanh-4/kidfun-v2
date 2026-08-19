const request = require('supertest');
const jwt = require('jsonwebtoken');

// Setup: load env before importing app
require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });

const { app } = require('../../src/server');

const TEST_EMAIL = `test_${Date.now()}@kidfun.test`;
const TEST_PASSWORD = 'TestPass123!';

let accessToken;
let refreshTokenValue;

describe('Auth API', () => {
  // Task 1.4: Test register
  describe('POST /api/auth/register', () => {
    it('should register and return success with token + refreshToken + user', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          fullName: 'Test User'
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.token).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
      expect(res.body.data.user).toBeDefined();
      expect(res.body.data.user.email).toBe(TEST_EMAIL);

      accessToken = res.body.data.token;
      refreshTokenValue = res.body.data.refreshToken;
    });

    it('should fail with duplicate email', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({
          email: TEST_EMAIL,
          password: TEST_PASSWORD,
          fullName: 'Test User'
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('EMAIL_EXISTS');
    });
  });

  // Task 1.4: Test login
  describe('POST /api/auth/login', () => {
    it('should login and return success with token + refreshToken + user', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: TEST_EMAIL,
          password: TEST_PASSWORD
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.token).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
      expect(res.body.data.user).toBeDefined();

      accessToken = res.body.data.token;
      refreshTokenValue = res.body.data.refreshToken;
    });

    it('should fail with wrong password', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: TEST_EMAIL,
          password: 'wrongpassword'
        });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('INVALID_CREDENTIALS');
    });

    it('should fail with non-existent email', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'nonexistent@test.com',
          password: TEST_PASSWORD
        });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });

  // Task 1.4: Test refresh-token
  describe('POST /api/auth/refresh-token', () => {
    it('should return new tokens with valid refresh token', async () => {
      const res = await request(app)
        .post('/api/auth/refresh-token')
        .send({ refreshToken: refreshTokenValue });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.token).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
      // New tokens should be different
      expect(res.body.data.token).not.toBe(accessToken);
    });

    it('should fail without refresh token', async () => {
      const res = await request(app)
        .post('/api/auth/refresh-token')
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('MISSING_TOKEN');
    });

    it('should fail with invalid refresh token', async () => {
      const res = await request(app)
        .post('/api/auth/refresh-token')
        .send({ refreshToken: 'invalid.token.here' });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('INVALID_TOKEN');
    });

    it('should fail with expired refresh token', async () => {
      // Create an expired token
      const expiredToken = jwt.sign(
        { userId: 1 },
        process.env.JWT_SECRET + '_refresh',
        { expiresIn: '0s' }
      );

      const res = await request(app)
        .post('/api/auth/refresh-token')
        .send({ refreshToken: expiredToken });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('TOKEN_EXPIRED');
    });
  });

  // Task 1.4: Test logout
  describe('POST /api/auth/logout', () => {
    it('should logout successfully with valid token', async () => {
      const res = await request(app)
        .post('/api/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.message).toBe('Logged out');
    });

    it('should fail without token', async () => {
      const res = await request(app)
        .post('/api/auth/logout');

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });

  // Task 1.4: Test with expired access token
  describe('Protected routes with expired token', () => {
    it('should return 401 with expired access token', async () => {
      const expiredToken = jwt.sign(
        { userId: 1, email: 'test@test.com' },
        process.env.JWT_SECRET,
        { expiresIn: '0s' }
      );

      const res = await request(app)
        .post('/api/auth/logout')
        .set('Authorization', `Bearer ${expiredToken}`);

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('TOKEN_EXPIRED');
    });
  });

  // Test standardized response format
  describe('Response format standardization', () => {
    it('health check should return standardized format', async () => {
      const res = await request(app).get('/api/health');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('OK');
    });

    it('404 should return standardized error format', async () => {
      const res = await request(app).get('/api/nonexistent');

      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('NOT_FOUND');
    });
  });

  // Cleanup: delete test user after all tests
  afterAll(async () => {
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    try {
      await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    } catch (e) {
      // ignore
    }
    await prisma.$disconnect();
  });
});
