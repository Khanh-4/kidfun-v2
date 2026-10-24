const request = require('supertest');
const jwt = require('jsonwebtoken');

// Env do tests/setup-env.js nạp (.env.test, có chặn nếu trỏ vào production).
// POST /api/profiles/:id/location/request — thay event Socket.IO 'requestLocation'.

jest.mock('../../src/services/firebaseService', () => ({
  ...jest.requireActual('../../src/services/firebaseService'),
  sendDataMessage: jest.fn(),
}));

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');
const { sendDataMessage } = require('../../src/services/firebaseService');

const STAMP = Date.now();
let owner;
let stranger;
let profile;
let device;

const auth = (user) => ({
  Authorization: `Bearer ${jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET)}`,
});

const url = () => `/api/profiles/${profile.id}/location/request`;

describe('POST /api/profiles/:id/location/request', () => {
  beforeAll(async () => {
    owner = await prisma.user.create({ data: { email: `locreq_owner_${STAMP}@kidfun.test`, fullName: 'Owner' } });
    stranger = await prisma.user.create({ data: { email: `locreq_other_${STAMP}@kidfun.test`, fullName: 'Other' } });
    profile = await prisma.profile.create({ data: { userId: owner.id, profileName: 'Bé Vị Trí' } });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: { in: [owner.id, stranger.id] } } }); // cascade
  });

  beforeEach(() => sendDataMessage.mockReset());

  it('trả 404 NO_DEVICE khi hồ sơ chưa liên kết máy nào', async () => {
    const res = await request(app).post(url()).set(auth(owner));

    expect(res.status).toBe(404);
    expect(res.body.code).toBe('NO_DEVICE');
    expect(sendDataMessage).not.toHaveBeenCalled();
  });

  it('trả 409 NO_FCM_TOKEN khi máy trẻ chưa đăng ký FCM', async () => {
    device = await prisma.device.create({
      data: { userId: owner.id, profileId: profile.id, deviceName: 'phone', deviceCode: `locreq_${STAMP}` },
    });

    const res = await request(app).post(url()).set(auth(owner));

    expect(res.status).toBe(409);
    expect(res.body.code).toBe('NO_FCM_TOKEN');
  });

  it('gửi lệnh data-only location_request tới token của máy trẻ', async () => {
    await prisma.fCMToken.create({
      data: { userId: owner.id, deviceId: device.id, token: `locreq_tok_${STAMP}`, platform: 'ANDROID' },
    });
    sendDataMessage.mockResolvedValue('projects/x/messages/1');

    const res = await request(app).post(url()).set(auth(owner));

    expect(res.status).toBe(200);
    expect(res.body.data.sent).toBe(1);
    expect(sendDataMessage).toHaveBeenCalledWith(`locreq_tok_${STAMP}`, {
      type: 'location_request',
      profileId: String(profile.id),
    });
  });

  it('xoá token FCM hết hạn và trả 502 khi không gửi được tới máy nào', async () => {
    sendDataMessage.mockResolvedValue({ error: 'INVALID_TOKEN', token: `locreq_tok_${STAMP}` });

    const res = await request(app).post(url()).set(auth(owner));

    expect(res.status).toBe(502);
    expect(await prisma.fCMToken.findUnique({ where: { token: `locreq_tok_${STAMP}` } })).toBeNull();
  });

  it('chặn phụ huynh khác gửi yêu cầu cho con nhà người ta', async () => {
    const res = await request(app).post(url()).set(auth(stranger));

    expect(res.status).toBe(404);
    expect(sendDataMessage).not.toHaveBeenCalled();
  });
});
