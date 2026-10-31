const request = require('supertest');

// Env do tests/setup-env.js nạp (.env.test, có chặn nếu trỏ vào production).
// GET /api/cron/thesis-data — tác vụ ML ban đêm (T7.1.1a) đọc dữ liệu qua API thay vì nối thẳng DB.

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');

const STAMP = Date.now();
const SECRET = 'test-cron-secret';
const IDENTIFYING = ['email', 'fullName', 'profileName', 'appName', 'reason', 'deviceId', 'latitude', 'longitude', 'message'];
const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

let owner;
let profiles;
let device;
let prevSecret;

const get = (query = '', auth = `Bearer ${SECRET}`) => {
  const req = request(app).get(`/api/cron/thesis-data${query}`);
  return auth ? req.set('Authorization', auth) : req;
};

// Chỉ giữ dữ liệu của test này (DB test có thể còn hồ sơ của test khác).
const mine = (rows) => rows.filter((r) => profiles.some((p) => p.id === r.profileId));

describe('GET /api/cron/thesis-data', () => {
  beforeAll(async () => {
    prevSecret = process.env.CRON_SECRET;
    process.env.CRON_SECRET = SECRET;

    owner = await prisma.user.create({ data: { email: `thesis_${STAMP}@kidfun.test`, fullName: 'Phụ Huynh' } });
    profiles = [];
    for (const profileName of ['Bé Một', 'Bé Hai']) {
      profiles.push(await prisma.profile.create({ data: { userId: owner.id, profileName } }));
    }
    const [p1] = profiles;
    device = await prisma.device.create({
      data: { userId: owner.id, profileId: p1.id, deviceName: 'phone', deviceCode: `thesis_${STAMP}` },
    });

    const now = Date.now();
    await prisma.appUsageHourly.createMany({
      data: [
        // trong cửa sổ 28 ngày
        { profileId: p1.id, deviceId: device.id, packageName: 'com.google.android.youtube', appName: 'YouTube',
          hourStart: new Date(now - 2 * DAY), usageSeconds: 1800, launchCount: 3 },
        // ngoài cửa sổ → không trả
        { profileId: p1.id, deviceId: device.id, packageName: 'com.old.app', appName: 'Old',
          hourStart: new Date(now - 40 * DAY), usageSeconds: 600, launchCount: 1 },
      ],
    });
    await prisma.timeLimit.create({ data: { profileId: p1.id, dayOfWeek: 1, dailyLimitMinutes: 90 } });
    await prisma.timeExtensionRequest.create({
      data: { profileId: p1.id, deviceId: device.id, requestMinutes: 15, reason: 'Con làm bài tập', status: 'APPROVED' },
    });
    const alert = (over) => ({
      profileId: p1.id, deviceId: device.id, source: 'TIER1', rule: 'spike', category: 'game', dayType: 'weekend',
      message: 'Bé Một chơi game nhiều bất thường', ...over,
    });
    await prisma.behaviorAlert.createMany({
      data: [
        alert({ slotStart: new Date(now - 3 * DAY), feedback: 'ALLOWED_WEEKEND', feedbackAt: new Date(now - 3 * DAY + HOUR) }),
        // phản hồi "đúng là bất thường" không nới ngưỡng → không trả
        alert({ slotStart: new Date(now - 2 * DAY), feedback: 'CONFIRMED', feedbackAt: new Date(now - 2 * DAY + HOUR) }),
        // chưa phản hồi → không trả
        alert({ slotStart: new Date(now - DAY) }),
        // M1 không dùng ngưỡng tầng 1 → không trả
        alert({ source: 'M1', rule: 'over_limit', slotStart: new Date(now - DAY), feedback: 'ALLOWED_OTHER', feedbackAt: new Date(now) }),
      ],
    });
  });

  afterAll(async () => {
    process.env.CRON_SECRET = prevSecret;
    await prisma.user.deleteMany({ where: { id: owner.id } }); // cascade
  });

  it('trả 401 khi sai secret hoặc thiếu header', async () => {
    expect((await get('', 'Bearer sai')).status).toBe(401);
    expect((await get('', null)).status).toBe(401);
  });

  it('trả 400 khi days/limit không hợp lệ', async () => {
    expect((await get('?days=0')).status).toBe(400);
    expect((await get('?days=abc')).status).toBe(400);
    expect((await get('?limit=1000')).status).toBe(400);
  });

  it('trả dữ liệu trong cửa sổ ngày, đủ cột ML cần', async () => {
    const res = await get('?days=28&limit=50');

    expect(res.status).toBe(200);
    const { hourly, limits, extRequests, profileIds } = res.body.data;
    expect(profileIds).toEqual(expect.arrayContaining(profiles.map((p) => p.id)));

    const h = mine(hourly);
    expect(h).toHaveLength(1);
    expect(h[0]).toEqual({
      profileId: profiles[0].id,
      packageName: 'com.google.android.youtube',
      hourStart: expect.any(String),
      usageSeconds: 1800,
      launchCount: 3,
    });
    expect(mine(limits)).toEqual([
      { profileId: profiles[0].id, dayOfWeek: 1, dailyLimitMinutes: 90, isActive: true, isGradual: false },
    ]);
    expect(mine(extRequests)).toEqual([
      { profileId: profiles[0].id, createdAt: expect.any(String), requestMinutes: 15, status: 'APPROVED' },
    ]);
  });

  it('trả phản hồi "được phép" của cảnh báo tầng 1 để tác vụ nới ngưỡng', async () => {
    const res = await get('?days=28&limit=50');

    expect(mine(res.body.data.alertFeedback)).toEqual([
      { profileId: profiles[0].id, rule: 'spike', category: 'game', dayType: 'weekend',
        feedback: 'ALLOWED_WEEKEND', feedbackAt: expect.any(String) },
    ]);
  });

  it('không lộ cột định danh (tên, email, appName, lý do, vị trí)', async () => {
    const res = await get('?days=28&limit=50');
    const body = JSON.stringify(res.body);

    for (const key of IDENTIFYING) expect(body).not.toContain(`"${key}"`);
    expect(body).not.toContain('Phụ Huynh');
    expect(body).not.toContain('Bé Một');
    expect(body).not.toContain('Con làm bài tập');
    expect(body).not.toContain('chơi game nhiều bất thường'); // message cảnh báo có tên trẻ
  });

  // Jest chạy song song nhiều worker: test khác có thể tạo hồ sơ có id nằm giữa
  // p1 và p2, nên chỉ khẳng định những gì không phụ thuộc thứ tự đó.
  it('chia trang theo trẻ bằng afterProfileId + limit', async () => {
    const [p1, p2] = profiles;

    const page1 = await get(`?days=28&limit=1&afterProfileId=${p1.id - 1}`);
    expect(page1.body.data.profileIds).toEqual([p1.id]);
    expect(page1.body.data.nextAfterProfileId).toBe(p1.id);
    expect(page1.body.data.hourly.every((r) => r.profileId === p1.id)).toBe(true);
    expect(page1.body.data.limits.every((r) => r.profileId === p1.id)).toBe(true);

    const page2 = await get(`?days=28&limit=50&afterProfileId=${p1.id}`);
    expect(page2.body.data.profileIds).not.toContain(p1.id);
    expect(page2.body.data.profileIds).toContain(p2.id);
    expect(mine(page2.body.data.hourly)).toEqual([]);
  });

  it('hết trẻ thì trả danh sách rỗng và nextAfterProfileId = null', async () => {
    const res = await get('?days=28&afterProfileId=2147483646');

    expect(res.body.data.profileIds).toEqual([]);
    expect(res.body.data.nextAfterProfileId).toBeNull();
  });
});
