const request = require('supertest');

// Env do tests/setup-env.js nạp (.env.test, có chặn nếu trỏ vào production)

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');

const HOUR_MS = 60 * 60 * 1000;
const DEVICE_CODE = `hourly_test_${Date.now()}`;

// Giờ vừa qua (đã đóng) và giờ hiện tại, tính theo đồng hồ thật vì API so với `new Date()`
const currentHour = new Date(Math.floor(Date.now() / HOUR_MS) * HOUR_MS);
const previousHour = new Date(currentHour.getTime() - HOUR_MS);

let userId;
let profileId;
let deviceId;

const post = (body) => request(app).post('/api/child/app-usage/hourly').send(body);

const rowsOf = () =>
  prisma.appUsageHourly.findMany({
    where: { deviceId },
    orderBy: [{ hourStart: 'asc' }, { packageName: 'asc' }],
  });

describe('POST /api/child/app-usage/hourly', () => {
  beforeAll(async () => {
    const user = await prisma.user.create({
      data: { email: `${DEVICE_CODE}@kidfun.test`, fullName: 'Hourly Test' },
    });
    userId = user.id;
    const profile = await prisma.profile.create({ data: { userId, profileName: 'Bé Test' } });
    profileId = profile.id;
    const device = await prisma.device.create({
      data: { userId, profileId, deviceName: 'Test phone', deviceCode: DEVICE_CODE },
    });
    deviceId = device.id;
  });

  afterAll(async () => {
    // Cascade xoá profile, device và các dòng AppUsageHourly
    await prisma.user.delete({ where: { id: userId } });
    await prisma.$disconnect();
  });

  it('lưu các ô theo giờ của máy trẻ đã liên kết', async () => {
    const res = await post({
      deviceCode: DEVICE_CODE,
      buckets: [
        {
          packageName: 'com.google.android.youtube',
          appName: 'YouTube',
          hourStart: previousHour.toISOString(),
          usageSeconds: 600,
          launchCount: 2,
        },
        {
          packageName: 'com.google.android.youtube',
          appName: 'YouTube',
          hourStart: currentHour.toISOString(),
          usageSeconds: 120,
          launchCount: 1,
        },
      ],
    });

    expect(res.status).toBe(201);
    expect(res.body.data).toEqual({ upserted: 2, rejected: 0 });

    const rows = await rowsOf();
    expect(rows.map((r) => [r.hourStart.getTime(), r.usageSeconds, r.profileId])).toEqual([
      [previousHour.getTime(), 600, profileId],
      [currentHour.getTime(), 120, profileId],
    ]);
  });

  it('gửi lại giá trị mới thì ghi đè, không cộng dồn và không nhân đôi dòng', async () => {
    const res = await post({
      deviceCode: DEVICE_CODE,
      buckets: [
        {
          packageName: 'com.google.android.youtube',
          hourStart: currentHour.toISOString(),
          usageSeconds: 900,
          launchCount: 3,
        },
      ],
    });

    expect(res.status).toBe(201);

    const rows = await rowsOf();
    expect(rows).toHaveLength(2);
    const current = rows.find((r) => r.hourStart.getTime() === currentHour.getTime());
    expect(current.usageSeconds).toBe(900);
    expect(current.launchCount).toBe(3);
    // Không gửi appName thì giữ appName cũ
    expect(current.appName).toBe('YouTube');
  });

  it('bỏ qua ô không hợp lệ nhưng vẫn lưu các ô hợp lệ trong cùng lô', async () => {
    const res = await post({
      deviceCode: DEVICE_CODE,
      buckets: [
        { packageName: 'com.zing.zalo', hourStart: previousHour.toISOString(), usageSeconds: 30 },
        { packageName: 'com.bad', hourStart: '2026-01-01T10:15:00.000Z', usageSeconds: 30 },
      ],
    });

    expect(res.status).toBe(201);
    expect(res.body.data).toEqual({ upserted: 1, rejected: 1 });
    expect((await rowsOf()).some((r) => r.packageName === 'com.bad')).toBe(false);
  });

  it('trả 404 DEVICE_NOT_LINKED khi deviceCode không tồn tại', async () => {
    const res = await post({
      deviceCode: 'khong_ton_tai',
      buckets: [{ packageName: 'a.b', hourStart: currentHour.toISOString(), usageSeconds: 1 }],
    });

    expect(res.status).toBe(404);
    expect(res.body.code).toBe('DEVICE_NOT_LINKED');
  });

  it('trả 400 khi thiếu deviceCode hoặc buckets rỗng', async () => {
    expect((await post({ buckets: [] })).status).toBe(400);
    expect((await post({ deviceCode: DEVICE_CODE, buckets: [] })).status).toBe(400);
  });

  it('trả 400 khi mọi ô đều không hợp lệ', async () => {
    const res = await post({
      deviceCode: DEVICE_CODE,
      buckets: [{ packageName: 'a.b', hourStart: currentHour.toISOString(), usageSeconds: 99999 }],
    });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe('INVALID_BUCKETS');
  });
});
