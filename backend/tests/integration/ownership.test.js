const request = require('supertest');
const jwt = require('jsonwebtoken');

// Env do tests/setup-env.js nạp (.env.test, có chặn nếu trỏ vào production).
// Chặn IDOR: phụ huynh A đổi id trên URL không được xem/sửa dữ liệu con nhà B.

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');

const STAMP = Date.now();
let a;
let b;
let profileA;
let profileB;
let rowsB; // dữ liệu của nhà B

const auth = (user) => ({
  Authorization: `Bearer ${jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET)}`,
});

const createFamily = async (tag) => {
  const user = await prisma.user.create({ data: { email: `owner_${tag}_${STAMP}@kidfun.test`, fullName: tag } });
  const profile = await prisma.profile.create({ data: { userId: user.id, profileName: `Bé ${tag}` } });
  const device = await prisma.device.create({
    data: { userId: user.id, profileId: profile.id, deviceName: 'phone', deviceCode: `owner_${tag}_${STAMP}` },
  });
  const log = await prisma.youTubeLog.create({
    data: { profileId: profile.id, deviceId: device.id, videoTitle: 'Video', dangerLevel: 5 },
  });
  return {
    user,
    profile,
    geofence: await prisma.geofence.create({
      data: { profileId: profile.id, name: 'Nhà', latitude: 10.8, longitude: 106.7, radius: 200 },
    }),
    sos: await prisma.sOSAlert.create({
      data: { profileId: profile.id, deviceId: device.id, latitude: 10.8, longitude: 106.7 },
    }),
    blocked: await prisma.blockedVideo.create({
      data: { profileId: profile.id, videoTitle: 'Video xấu', videoId: `v${tag}${STAMP}` },
    }),
    alert: await prisma.aIAlert.create({
      data: { profileId: profile.id, youtubeLogId: log.id, dangerLevel: 5, category: 'VIOLENCE', summary: 'x' },
    }),
  };
};

describe('Phân quyền theo gia đình (chặn IDOR)', () => {
  beforeAll(async () => {
    const famA = await createFamily('A');
    const famB = await createFamily('B');
    ({ user: a, profile: profileA } = famA);
    ({ user: b, profile: profileB } = famB);
    rowsB = famB;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: { in: [a.id, b.id] } } }); // cascade
    await prisma.$disconnect();
  });

  it.each([
    'youtube/logs',
    'youtube/dashboard',
    'ai-alerts',
    'blocked-videos',
    'location/history',
    'sos',
    'geofences',
    'reports/daily',
  ])('GET /api/profiles/:id/%s — 404 với profile nhà khác, không 404 với profile của mình', async (path) => {
    const other = await request(app).get(`/api/profiles/${profileB.id}/${path}`).set(auth(a));
    expect(other.status).toBe(404);
    const mine = await request(app).get(`/api/profiles/${profileA.id}/${path}`).set(auth(a));
    expect(mine.status).not.toBe(404);
  });

  it('không chặn video được cho con nhà khác', async () => {
    const res = await request(app)
      .post(`/api/profiles/${profileB.id}/blocked-videos`)
      .set(auth(a))
      .send({ videoTitle: 'x', videoId: 'zz' });
    expect(res.status).toBe(404);
  });

  it('không sửa/xoá được vùng an toàn, SOS, video bị chặn, cảnh báo AI của nhà khác', async () => {
    const attempts = [
      request(app).put(`/api/geofences/${rowsB.geofence.id}`).set(auth(a)).send({ name: 'Bị sửa' }),
      request(app).delete(`/api/geofences/${rowsB.geofence.id}`).set(auth(a)),
      request(app).put(`/api/sos/${rowsB.sos.id}/acknowledge`).set(auth(a)),
      request(app).put(`/api/sos/${rowsB.sos.id}/resolve`).set(auth(a)),
      request(app).delete(`/api/blocked-videos/${rowsB.blocked.id}`).set(auth(a)),
      request(app).put(`/api/ai-alerts/${rowsB.alert.id}/read`).set(auth(a)),
    ];
    for (const res of await Promise.all(attempts)) expect(res.status).toBe(404);

    expect((await prisma.geofence.findUnique({ where: { id: rowsB.geofence.id } })).name).toBe('Nhà');
    expect((await prisma.sOSAlert.findUnique({ where: { id: rowsB.sos.id } })).status).not.toBe('RESOLVED');
    expect(await prisma.blockedVideo.findUnique({ where: { id: rowsB.blocked.id } })).not.toBeNull();
    expect((await prisma.aIAlert.findUnique({ where: { id: rowsB.alert.id } })).isRead).toBe(false);
  });

  it('chủ thật vẫn thao tác được trên dữ liệu của mình', async () => {
    const own = auth(b);
    expect((await request(app).put(`/api/ai-alerts/${rowsB.alert.id}/read`).set(own)).status).toBe(200);
    expect((await request(app).put(`/api/sos/${rowsB.sos.id}/acknowledge`).set(own)).status).toBe(200);
    const renamed = await request(app).put(`/api/geofences/${rowsB.geofence.id}`).set(own).send({ name: 'Nhà mới' });
    expect(renamed.status).toBe(200);
    expect((await request(app).delete(`/api/blocked-videos/${rowsB.blocked.id}`).set(own)).status).toBe(200);
  });
});
