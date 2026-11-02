const request = require('supertest');
const jwt = require('jsonwebtoken');

// Env do tests/setup-env.js nạp (.env.test, có chặn nếu trỏ vào production).
// Lọc nhật ký YouTube theo NGÀY GIỜ VN: server chạy UTC, video xem lúc
// 00:00–06:59 giờ VN thuộc ngày UTC hôm trước — trước đây bị xếp sai ngày.

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');

const STAMP = Date.now();
let user;
let profile;

const auth = () => ({
  Authorization: `Bearer ${jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET)}`,
});

describe('GET /api/profiles/:id/youtube/* — mốc ngày theo giờ VN', () => {
  beforeAll(async () => {
    user = await prisma.user.create({ data: { email: `yt_${STAMP}@kidfun.test`, fullName: 'PH' } });
    profile = await prisma.profile.create({ data: { userId: user.id, profileName: 'Bé' } });
    const device = await prisma.device.create({
      data: { userId: user.id, profileId: profile.id, deviceName: 'phone', deviceCode: `yt_${STAMP}` },
    });
    const recent = Date.now() - 60 * 60 * 1000; // trong cửa sổ 7 ngày của dashboard
    await prisma.youTubeLog.createMany({
      data: [
        // 01:30 giờ VN ngày 10/03 = 18:30 UTC ngày 09/03
        { profileId: profile.id, deviceId: device.id, videoTitle: 'Sáng sớm', watchedAt: new Date('2026-03-09T18:30:00Z'), durationSeconds: 60 },
        // 23:30 giờ VN ngày 09/03 = 16:30 UTC ngày 09/03
        { profileId: profile.id, deviceId: device.id, videoTitle: 'Tối hôm trước', watchedAt: new Date('2026-03-09T16:30:00Z'), durationSeconds: 60 },
        { profileId: profile.id, deviceId: device.id, videoTitle: 'Gần đây', watchedAt: new Date(recent), durationSeconds: 60 },
      ],
    });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: user.id } }); // cascade
    await prisma.$disconnect();
  });

  it('date=2026-03-10 trả video xem lúc 01:30 giờ VN, không trả video 23:30 hôm trước', async () => {
    const res = await request(app)
      .get(`/api/profiles/${profile.id}/youtube/logs?date=2026-03-10`)
      .set(auth());
    expect(res.status).toBe(200);
    expect(res.body.data.logs.map((l) => l.videoTitle)).toEqual(['Sáng sớm']);
  });

  it('date=2026-03-09 chỉ trả video 23:30 giờ VN ngày 09/03', async () => {
    const res = await request(app)
      .get(`/api/profiles/${profile.id}/youtube/logs?date=2026-03-09`)
      .set(auth());
    expect(res.status).toBe(200);
    expect(res.body.data.logs.map((l) => l.videoTitle)).toEqual(['Tối hôm trước']);
  });

  it('date sai định dạng → 400', async () => {
    const res = await request(app)
      .get(`/api/profiles/${profile.id}/youtube/logs?date=hom-nay`)
      .set(auth());
    expect(res.status).toBe(400);
  });

  it('dashboard nhóm dailyActivity theo ngày giờ VN', async () => {
    const res = await request(app)
      .get(`/api/profiles/${profile.id}/youtube/dashboard?days=7`)
      .set(auth());
    expect(res.status).toBe(200);
    const vnToday = new Date(Date.now() - 60 * 60 * 1000 + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
    expect(res.body.data.dailyActivity).toEqual({ [vnToday]: 1 });
  });
});
