const request = require('supertest');

// POST /api/child/fcm-token — máy trẻ đăng ký FCM token gắn với deviceId.
// Không có route này thì location_request / blocked_apps_update (FCM theo
// deviceId) không bao giờ có người nhận → phụ huynh thấy 409 NO_FCM_TOKEN.

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');

const STAMP = Date.now();
const URL = '/api/child/fcm-token';
let owner;
let profile;
let device;

describe('POST /api/child/fcm-token', () => {
  beforeAll(async () => {
    owner = await prisma.user.create({ data: { email: `childfcm_${STAMP}@kidfun.test`, fullName: 'Owner' } });
    profile = await prisma.profile.create({ data: { userId: owner.id, profileName: 'Bé FCM' } });
    device = await prisma.device.create({
      data: { userId: owner.id, profileId: profile.id, deviceName: 'phone', deviceCode: `childfcm_${STAMP}` },
    });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: owner.id } }); // cascade
  });

  it('trả 400 khi thiếu X-Device-Code', async () => {
    const res = await request(app).post(URL).send({ token: 'tok' });
    expect(res.status).toBe(400);
  });

  it('trả 400 khi thiếu token', async () => {
    const res = await request(app).post(URL).set('X-Device-Code', device.deviceCode).send({});
    expect(res.status).toBe(400);
  });

  it('trả 404 khi deviceCode không tồn tại', async () => {
    const res = await request(app).post(URL).set('X-Device-Code', 'khong_co').send({ token: 'tok' });
    expect(res.status).toBe(404);
  });

  it('lưu token gắn deviceId + userId chủ máy', async () => {
    const token = `child_tok_${STAMP}`;
    const res = await request(app).post(URL).set('X-Device-Code', device.deviceCode).send({ token });

    expect(res.status).toBe(200);
    const row = await prisma.fCMToken.findUnique({ where: { token } });
    expect(row.deviceId).toBe(device.id);
    expect(row.userId).toBe(owner.id);
  });

  it('gắn lại token đã có (vd. từng đăng ký lúc ở chế độ phụ huynh) sang máy trẻ', async () => {
    const token = `shared_tok_${STAMP}`;
    await prisma.fCMToken.create({ data: { userId: owner.id, deviceId: null, token, platform: 'ANDROID' } });

    const res = await request(app).post(URL).set('X-Device-Code', device.deviceCode).send({ token });

    expect(res.status).toBe(200);
    const row = await prisma.fCMToken.findUnique({ where: { token } });
    expect(row.deviceId).toBe(device.id);
  });

  it('route phụ huynh đăng ký lại cùng token (không kèm deviceId) không xoá liên kết máy trẻ', async () => {
    const jwt = require('jsonwebtoken');
    const token = `child_tok_${STAMP}`; // đã gắn máy trẻ ở test trước
    const res = await request(app)
      .post('/api/fcm-tokens/register')
      .set('Authorization', `Bearer ${jwt.sign({ userId: owner.id, email: owner.email }, process.env.JWT_SECRET)}`)
      .send({ token });

    expect(res.status).toBe(200);
    const row = await prisma.fCMToken.findUnique({ where: { token } });
    expect(row.deviceId).toBe(device.id);
  });
});
