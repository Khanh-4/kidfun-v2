const request = require('supertest');
const jwt = require('jsonwebtoken');

// T7.2.3 — tác vụ ML ban đêm gửi dự đoán M1 (+ cảnh báo tầng 2) lên server.
process.env.CRON_SECRET = process.env.CRON_SECRET || 'test-cron-secret';

jest.mock('../../src/services/fcmService', () => ({
  ...jest.requireActual('../../src/services/fcmService'),
  sendBehaviorAlertPush: jest.fn().mockResolvedValue(undefined),
}));
const { sendBehaviorAlertPush } = require('../../src/services/fcmService');

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');

const HOUR_MS = 60 * 60 * 1000;
const TAG = `results_test_${Date.now()}`;
const previousHour = new Date(Math.floor(Date.now() / HOUR_MS) * HOUR_MS - HOUR_MS).toISOString();
const DATE = '2026-11-06';

let parent;
let profileId;

const post = (body) =>
  request(app).post('/api/cron/behavior-results').set('Authorization', `Bearer ${process.env.CRON_SECRET}`).send(body);
const prediction = (overrides = {}) => ({
  profileId,
  date: DATE,
  predictedMinutes: 150,
  pOverLimit: 0.3,
  limitMinutes: 120,
  ...overrides,
});

describe('POST /api/cron/behavior-results (đồ án chuyên ngành, T7.2.3)', () => {
  beforeAll(async () => {
    parent = await prisma.user.create({ data: { email: `${TAG}@kidfun.test`, fullName: 'Results Parent' } });
    profileId = (await prisma.profile.create({ data: { userId: parent.id, profileName: 'Bé Bình' } })).id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: parent.id } }); // cascade
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    sendBehaviorAlertPush.mockClear();
    await prisma.usagePrediction.deleteMany({ where: { profileId } });
    await prisma.behaviorAlert.deleteMany({ where: { profileId } });
  });

  it('thiếu CRON_SECRET → 401', async () => {
    const res = await request(app).post('/api/cron/behavior-results').send({ modelVersion: 'v', predictions: [] });
    expect(res.status).toBe(401);
  });

  it.each([
    ['thiếu modelVersion', { predictions: [] }],
    ['predictions không phải mảng', { modelVersion: 'v', predictions: 'x' }],
    ['ngày sai định dạng', { modelVersion: 'v', predictions: [{ profileId: 1, date: '06/11/2026', predictedMinutes: 1 }] }],
    ['xác suất ngoài [0,1]', { modelVersion: 'v', predictions: [{ profileId: 1, date: DATE, predictedMinutes: 1, pOverLimit: 1.2 }] }],
    ['số phút âm', { modelVersion: 'v', predictions: [{ profileId: 1, date: DATE, predictedMinutes: -5 }] }],
  ])('dữ liệu sai (%s) → 400', async (_name, body) => {
    const res = await post(body);
    expect(res.status).toBe(400);
  });

  it('ghi dự đoán, chạy lại trong ngày thì ghi đè (không tạo trùng)', async () => {
    await post({ modelVersion: 'v1', predictions: [prediction()] });
    const res = await post({ modelVersion: 'v2', predictions: [prediction({ predictedMinutes: 90 })] });

    expect(res.status).toBe(200);
    const rows = await prisma.usagePrediction.findMany({ where: { profileId } });
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ predictedMinutes: 90, modelVersion: 'v2', limitMinutes: 120 });
    expect(rows[0].date.toISOString().slice(0, 10)).toBe(DATE);
  });

  it('xác suất < 0,6 → chỉ lưu dự đoán, không cảnh báo', async () => {
    const res = await post({ modelVersion: 'v', predictions: [prediction({ pOverLimit: 0.59 })] });

    expect(res.body.data).toMatchObject({ predictions: 1, alertsCreated: 0 });
    expect(await prisma.behaviorAlert.count({ where: { profileId } })).toBe(0);
    expect(sendBehaviorAlertPush).not.toHaveBeenCalled();
  });

  it('xác suất ≥ 0,6 → tạo cảnh báo M1 + FCM một lần; gửi lại không báo trùng', async () => {
    const first = await post({ modelVersion: 'v', predictions: [prediction({ pOverLimit: 0.72 })] });
    const again = await post({ modelVersion: 'v', predictions: [prediction({ pOverLimit: 0.75 })] });

    expect(first.body.data).toMatchObject({ alertsCreated: 1, alertDuplicates: 0 });
    expect(again.body.data).toMatchObject({ alertsCreated: 0, alertDuplicates: 1 });
    const alerts = await prisma.behaviorAlert.findMany({ where: { profileId } });
    expect(alerts).toHaveLength(1);
    expect(alerts[0]).toMatchObject({ source: 'M1', rule: 'over_limit', category: 'all' });
    expect(alerts[0].slotStart.toISOString()).toBe('2026-11-05T17:00:00.000Z'); // 00:00 ngày 06/11 giờ VN
    expect(alerts[0].message).toMatch(/72%/);
    expect(alerts[0].notifiedAt).not.toBeNull();
    expect(sendBehaviorAlertPush).toHaveBeenCalledTimes(1);
  });

  it('bỏ qua profile không tồn tại, vẫn ghi phần còn lại', async () => {
    const res = await post({ modelVersion: 'v', predictions: [prediction(), prediction({ profileId: 999999999 })] });

    expect(res.body.data).toMatchObject({ predictions: 1, unknownProfiles: 1 });
  });

  it('nhận cảnh báo tầng 2 (TIER2), dựng câu ở server', async () => {
    const tier2 = { profileId, rule: 'spike', category: 'game', dayType: 'school', slotStart: previousHour, minutes: 40, usualMinutes: 10 };
    const res = await post({ modelVersion: 'v', predictions: [], alerts: [tier2] });

    expect(res.status).toBe(200);
    const alerts = await prisma.behaviorAlert.findMany({ where: { profileId } });
    expect(alerts).toHaveLength(1);
    expect(alerts[0]).toMatchObject({ source: 'TIER2', rule: 'spike' });
    expect(alerts[0].message).toMatch(/chơi game/);
    expect(sendBehaviorAlertPush).toHaveBeenCalledTimes(1);
  });

  describe('GET /api/profiles/:id/predictions (T7.2.4)', () => {
    const DAY_MS = 24 * HOUR_MS;
    const vnDate = (offsetDays) => new Date(Date.now() + 7 * HOUR_MS + offsetDays * DAY_MS).toISOString().slice(0, 10);
    const tokenOf = (user) => jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET);
    const get = (id, user, query = {}) =>
      request(app).get(`/api/profiles/${id}/predictions`).query(query).set('Authorization', `Bearer ${tokenOf(user)}`);
    let stranger;

    beforeAll(async () => {
      stranger = await prisma.user.create({ data: { email: `${TAG}_x@kidfun.test`, fullName: 'Stranger' } });
    });

    afterAll(async () => {
      await prisma.user.deleteMany({ where: { id: stranger.id } });
    });

    beforeEach(async () => {
      await post({
        modelVersion: 'v',
        predictions: [1, 0, -3, -20].map((d) => prediction({ date: vnDate(d), predictedMinutes: 100 + d })),
      });
    });

    it('chưa đăng nhập → 401', async () => {
      const res = await request(app).get(`/api/profiles/${profileId}/predictions`);
      expect(res.status).toBe(401);
    });

    it('hồ sơ của người khác → 404 (không lộ là có tồn tại)', async () => {
      const res = await get(profileId, stranger);
      expect(res.status).toBe(404);
    });

    it('trả dự đoán trong N ngày gần nhất + ngày mai, mới nhất trước', async () => {
      const res = await get(profileId, parent, { days: 14 });

      expect(res.status).toBe(200);
      expect(res.body.data.predictions.map((p) => p.date)).toEqual([vnDate(1), vnDate(0), vnDate(-3)]);
      expect(res.body.data.predictions[0]).toMatchObject({ predictedMinutes: 101, pOverLimit: 0.3, limitMinutes: 120 });
    });

    it('days ngoài khoảng bị kẹp lại (mặc định 14, tối đa 60)', async () => {
      const def = await get(profileId, parent);
      const wide = await get(profileId, parent, { days: 9999 });

      expect(def.body.data.predictions).toHaveLength(3);
      expect(wide.body.data.predictions).toHaveLength(4);
    });
  });
});
