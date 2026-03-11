const request = require('supertest');

require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });

const { app } = require('../../src/server');

const TEST_EMAIL = `profile_test_${Date.now()}@kidfun.test`;
const TEST_EMAIL_2 = `profile_test2_${Date.now()}@kidfun.test`;
const TEST_PASSWORD = 'TestPass123!';

let token;
let token2;
let createdProfileId;

describe('Profile API on PostgreSQL', () => {
  // Setup: register 2 users
  beforeAll(async () => {
    const res1 = await request(app)
      .post('/api/auth/register')
      .send({ email: TEST_EMAIL, password: TEST_PASSWORD, fullName: 'Profile Test User' });
    token = res1.body.data.token;

    const res2 = await request(app)
      .post('/api/auth/register')
      .send({ email: TEST_EMAIL_2, password: TEST_PASSWORD, fullName: 'Profile Test User 2' });
    token2 = res2.body.data.token;
  });

  // GET /api/profiles → trả danh sách (array rỗng nếu chưa có)
  describe('GET /api/profiles', () => {
    it('should return empty array initially', async () => {
      const res = await request(app)
        .get('/api/profiles')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBe(0);
    });
  });

  // POST /api/profiles → tạo profile
  describe('POST /api/profiles', () => {
    it('should create profile successfully', async () => {
      const res = await request(app)
        .post('/api/profiles')
        .set('Authorization', `Bearer ${token}`)
        .send({ profileName: 'Bé An', dateOfBirth: '2015-06-15' });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.profile).toBeDefined();
      expect(res.body.data.profile.profileName).toBe('Bé An');
      createdProfileId = res.body.data.profile.id;
    });

    it('should fail without profileName', async () => {
      const res = await request(app)
        .post('/api/profiles')
        .set('Authorization', `Bearer ${token}`)
        .send({ dateOfBirth: '2015-06-15' });

      // Prisma will reject null profileName
      expect(res.status).toBeGreaterThanOrEqual(400);
      expect(res.body.success).toBe(false);
    });
  });

  // GET /api/profiles/:id → trả chi tiết profile vừa tạo
  describe('GET /api/profiles/:id', () => {
    it('should return profile with details', async () => {
      const res = await request(app)
        .get(`/api/profiles/${createdProfileId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.profileName).toBe('Bé An');
      expect(res.body.data.timeLimits).toBeDefined();
      expect(res.body.data.timeLimits.length).toBe(7); // 7 days auto-created
      expect(res.body.data.blockedSites).toBeDefined();
    });

    it('should return 404 for non-existent profile', async () => {
      const res = await request(app)
        .get('/api/profiles/99999')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
      expect(res.body.code).toBe('NOT_FOUND');
    });

    it('should return 404 when accessing another user profile (403 scenario)', async () => {
      // User 2 tries to access User 1's profile
      const res = await request(app)
        .get(`/api/profiles/${createdProfileId}`)
        .set('Authorization', `Bearer ${token2}`);

      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
    });
  });

  // PUT /api/profiles/:id → sửa tên
  describe('PUT /api/profiles/:id', () => {
    it('should update profile name', async () => {
      const res = await request(app)
        .put(`/api/profiles/${createdProfileId}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ profileName: 'Bé An Nguyễn' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('should verify updated name', async () => {
      const res = await request(app)
        .get(`/api/profiles/${createdProfileId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.body.data.profileName).toBe('Bé An Nguyễn');
    });

    it('should return 404 when updating another user profile', async () => {
      const res = await request(app)
        .put(`/api/profiles/${createdProfileId}`)
        .set('Authorization', `Bearer ${token2}`)
        .send({ profileName: 'Hacked Name' });

      expect(res.status).toBe(404);
    });
  });

  // PUT /api/profiles/:id/time-limits → set time limits 7 ngày
  describe('PUT /api/profiles/:id/time-limits', () => {
    it('should update time limits for all 7 days', async () => {
      const timeLimits = [];
      for (let day = 0; day < 7; day++) {
        timeLimits.push({
          dayOfWeek: day,
          dailyLimitMinutes: day === 0 || day === 6 ? 150 : 90
        });
      }

      const res = await request(app)
        .put(`/api/profiles/${createdProfileId}/time-limits`)
        .set('Authorization', `Bearer ${token}`)
        .send({ timeLimits });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.timeLimits).toBeDefined();
      expect(res.body.data.timeLimits.length).toBe(7);

      // Verify weekend = 150, weekday = 90
      const sunday = res.body.data.timeLimits.find(t => t.dayOfWeek === 0);
      const monday = res.body.data.timeLimits.find(t => t.dayOfWeek === 1);
      expect(sunday.dailyLimitMinutes).toBe(150);
      expect(monday.dailyLimitMinutes).toBe(90);
    });
  });

  // DELETE /api/profiles/:id → xóa profile
  describe('DELETE /api/profiles/:id', () => {
    it('should delete profile', async () => {
      const res = await request(app)
        .delete(`/api/profiles/${createdProfileId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('should confirm profile is deleted', async () => {
      const res = await request(app)
        .get(`/api/profiles/${createdProfileId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
    });
  });

  // Cleanup
  afterAll(async () => {
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    try {
      await prisma.user.deleteMany({
        where: { email: { in: [TEST_EMAIL, TEST_EMAIL_2] } }
      });
    } catch (e) { /* ignore */ }
    await prisma.$disconnect();
  });
});
