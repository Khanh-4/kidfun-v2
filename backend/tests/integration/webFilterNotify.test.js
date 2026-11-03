const request = require('supertest');
const jwt = require('jsonwebtoken');

// Đổi lọc web → máy trẻ phải nhận FCM data 'policy_update' (thay Socket.IO đã chết).
jest.mock('../../src/services/firebaseService', () => ({
  ...jest.requireActual('../../src/services/firebaseService'),
  sendDataMessage: jest.fn(),
}));

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');
const { sendDataMessage } = require('../../src/services/firebaseService');

const STAMP = Date.now();
let owner;
let profile;

describe('lọc web báo máy trẻ qua FCM', () => {
  beforeAll(async () => {
    owner = await prisma.user.create({ data: { email: `webnotify_${STAMP}@kidfun.test`, fullName: 'Owner' } });
    profile = await prisma.profile.create({ data: { userId: owner.id, profileName: 'Bé Web' } });
    const device = await prisma.device.create({
      data: { userId: owner.id, profileId: profile.id, deviceName: 'phone', deviceCode: `webnotify_${STAMP}` },
    });
    await prisma.fCMToken.create({ data: { userId: owner.id, deviceId: device.id, token: `web_tok_${STAMP}`, platform: 'ANDROID' } });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: owner.id } });
  });

  it('thêm tên miền chặn → gửi policy_update tới token máy trẻ', async () => {
    sendDataMessage.mockResolvedValue({ success: true });
    const res = await request(app)
      .post(`/api/profiles/${profile.id}/custom-blocked-domains`)
      .set('Authorization', `Bearer ${jwt.sign({ userId: owner.id, email: owner.email }, process.env.JWT_SECRET)}`)
      .send({ domain: 'example.com' });

    expect(res.status).toBe(201);
    expect(sendDataMessage).toHaveBeenCalledWith(`web_tok_${STAMP}`, expect.objectContaining({ type: 'policy_update' }));
  });
});
