const request = require('supertest');
const jwt = require('jsonwebtoken');

// Env do tests/setup-env.js nạp (.env.test, có chặn nếu trỏ vào production).
// .env.test không có CRON_SECRET -> đặt giá trị riêng cho test (middleware đọc env lúc nhận request).
process.env.CRON_SECRET = process.env.CRON_SECRET || 'test-cron-secret';

jest.mock('../../src/services/fcmService', () => ({
  ...jest.requireActual('../../src/services/fcmService'),
  sendBehaviorAlertPush: jest.fn().mockResolvedValue(undefined),
}));
const { sendBehaviorAlertPush } = require('../../src/services/fcmService');

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');

const HOUR_MS = 60 * 60 * 1000;
const DEVICE_CODE = `behavior_test_${Date.now()}`;
const previousHour = new Date(Math.floor(Date.now() / HOUR_MS) * HOUR_MS - HOUR_MS).toISOString();

let parent;
let other;
let profileId;
let otherProfileId;

const tokenOf = (user) => jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET);
const spike = (overrides = {}) => ({
  rule: 'spike',
  category: 'game',
  dayType: 'school',
  slotStart: previousHour,
  minutes: 40,
  usualMinutes: 10,
  ...overrides,
});

describe('Cảnh báo hành vi (đồ án chuyên ngành, M2 tầng 1)', () => {
  beforeAll(async () => {
    parent = await prisma.user.create({ data: { email: `${DEVICE_CODE}@kidfun.test`, fullName: 'Behavior Parent' } });
    other = await prisma.user.create({ data: { email: `${DEVICE_CODE}_x@kidfun.test`, fullName: 'Other Parent' } });
    profileId = (await prisma.profile.create({ data: { userId: parent.id, profileName: 'Bé An' } })).id;
    otherProfileId = (await prisma.profile.create({ data: { userId: other.id, profileName: 'Bé Khác' } })).id;
    await prisma.device.create({
      data: { userId: parent.id, profileId, deviceName: 'Test phone', deviceCode: DEVICE_CODE },
    });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: { in: [parent.id, other.id] } } }); // cascade
    await prisma.$disconnect();
  });

  beforeEach(() => sendBehaviorAlertPush.mockClear());

  describe('POST /api/child/behavior-alerts', () => {
    it('lưu cảnh báo, dựng câu tiếng Việt ở server và đẩy FCM cho phụ huynh', async () => {
      const res = await request(app)
        .post('/api/child/behavior-alerts')
        .send({ deviceCode: DEVICE_CODE, alerts: [spike(), spike({ category: 'banking' })] });

      expect(res.status).toBe(200);
      expect(res.body.data).toEqual({ created: 1, duplicates: 0, rejected: 1 });
      const [row] = await prisma.behaviorAlert.findMany({ where: { profileId } });
      expect(row).toMatchObject({ source: 'TIER1', rule: 'spike', category: 'game' });
      expect(row.message).toMatch(/^Bé chơi game lúc \d+h gấp 4 lần so với bình thường/);
      expect(row.notifiedAt).not.toBeNull();
      expect(sendBehaviorAlertPush).toHaveBeenCalledTimes(1);
      expect(sendBehaviorAlertPush.mock.calls[0][0]).toMatchObject({ id: profileId, profileName: 'Bé An' });
    });

    it('máy trẻ gửi lại cùng cảnh báo thì không tạo trùng, không báo lại', async () => {
      const res = await request(app)
        .post('/api/child/behavior-alerts')
        .send({ deviceCode: DEVICE_CODE, alerts: [spike()] });

      expect(res.body.data).toEqual({ created: 0, duplicates: 1, rejected: 0 });
      expect(sendBehaviorAlertPush).not.toHaveBeenCalled();
      expect(await prisma.behaviorAlert.count({ where: { profileId } })).toBe(1);
    });

    it('404 khi máy chưa liên kết, 400 khi lô rỗng', async () => {
      const unknown = await request(app)
        .post('/api/child/behavior-alerts')
        .send({ deviceCode: 'no_such_device', alerts: [spike()] });
      expect(unknown.status).toBe(404);
      const empty = await request(app).post('/api/child/behavior-alerts').send({ deviceCode: DEVICE_CODE, alerts: [] });
      expect(empty.status).toBe(400);
    });
  });

  describe('GET /api/profiles/:id/behavior-alerts + POST /api/behavior-alerts/:id/feedback', () => {
    it('phụ huynh xem được cảnh báo của con mình, không xem được của người khác', async () => {
      const mine = await request(app)
        .get(`/api/profiles/${profileId}/behavior-alerts`)
        .set('Authorization', `Bearer ${tokenOf(parent)}`);
      expect(mine.status).toBe(200);
      expect(mine.body.data.alerts).toHaveLength(1);

      const notMine = await request(app)
        .get(`/api/profiles/${otherProfileId}/behavior-alerts`)
        .set('Authorization', `Bearer ${tokenOf(parent)}`);
      expect(notMine.status).toBe(404);
    });

    it('lưu phản hồi; chặn giá trị lạ và chặn phụ huynh khác', async () => {
      const { id } = await prisma.behaviorAlert.findFirst({ where: { profileId } });

      const ok = await request(app)
        .post(`/api/behavior-alerts/${id}/feedback`)
        .set('Authorization', `Bearer ${tokenOf(parent)}`)
        .send({ feedback: 'ALLOWED_WEEKEND' });
      expect(ok.status).toBe(200);
      expect(ok.body.data.alert).toMatchObject({ feedback: 'ALLOWED_WEEKEND' });

      const bad = await request(app)
        .post(`/api/behavior-alerts/${id}/feedback`)
        .set('Authorization', `Bearer ${tokenOf(parent)}`)
        .send({ feedback: 'WHATEVER' });
      expect(bad.status).toBe(400);

      const stranger = await request(app)
        .post(`/api/behavior-alerts/${id}/feedback`)
        .set('Authorization', `Bearer ${tokenOf(other)}`)
        .send({ feedback: 'CONFIRMED' });
      expect(stranger.status).toBe(404);
      expect((await prisma.behaviorAlert.findUnique({ where: { id } })).feedback).toBe('ALLOWED_WEEKEND');
    });
  });

  describe('PUT /api/cron/behavior-baselines + GET /api/child/behavior-baseline', () => {
    const payload = { profileId: 0, baseline: [{ dayType: 'school', hour: 20, cat: 'game', mean: 10, std: 3 }] };
    const entry = (id) => ({ profileId: id, payload, validUntil: '2026-10-21T00:00:00+07:00' });

    it('máy trẻ nhận null khi server chưa tính', async () => {
      const res = await request(app).get('/api/child/behavior-baseline').query({ deviceCode: DEVICE_CODE });
      expect(res.status).toBe(200);
      expect(res.body.data.baseline).toBeNull();
    });

    it('từ chối khi thiếu CRON_SECRET', async () => {
      const res = await request(app).put('/api/cron/behavior-baselines').send({ baselines: [entry(profileId)] });
      expect(res.status).toBe(401);
    });

    it('tác vụ ban đêm ghi, bỏ qua profile không tồn tại, máy trẻ đọc lại đúng JSON', async () => {
      const res = await request(app)
        .put('/api/cron/behavior-baselines')
        .set('Authorization', `Bearer ${process.env.CRON_SECRET}`)
        .send({ baselines: [entry(profileId), entry(999999999)] });
      expect(res.body.data).toEqual({ saved: 1, unknownProfiles: 1 });

      const got = await request(app).get('/api/child/behavior-baseline').query({ deviceCode: DEVICE_CODE });
      expect(got.body.data.baseline).toEqual(payload);
    });
  });
});
