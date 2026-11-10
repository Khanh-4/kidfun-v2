const request = require('supertest');
const jwt = require('jsonwebtoken');

// Lỗi test 10/11 — luồng xin thêm giờ:
// 1. Máy trẻ nhận nhầm thông báo "xin thêm giờ" (token máy trẻ đăng ký dưới userId phụ huynh).
// 2. Duyệt/từ chối chỉ emit Socket.IO (null trên Vercel) → máy trẻ không biết kết quả.
// 3. Trẻ đã vượt hạn mức → duyệt +15p vẫn còn 0p, máy vẫn khoá.
jest.mock('../../src/services/firebaseService', () => ({
  ...jest.requireActual('../../src/services/firebaseService'),
  sendDataMessage: jest.fn(),
}));

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');
const { sendDataMessage, getParentTokens } = require('../../src/services/firebaseService');
const { vnQuotaDayRange } = require('../../src/utils/vnTime');

const STAMP = Date.now();
const PARENT_TOKEN = `ext_parent_${STAMP}`;
const CHILD_TOKEN = `ext_child_${STAMP}`;
const DEVICE_CODE = `extflow_${STAMP}`;
let owner;
let profile;
let device;
let auth;

const createRequest = (minutes = 15) =>
  prisma.timeExtensionRequest.create({
    data: { profileId: profile.id, deviceId: device.id, requestMinutes: minutes },
  });

const todayLimit = () =>
  request(app).get(`/api/child/today-limit?deviceCode=${DEVICE_CODE}`).set('X-Device-Code', DEVICE_CODE);

describe('luồng xin thêm giờ', () => {
  beforeAll(async () => {
    owner = await prisma.user.create({ data: { email: `extflow_${STAMP}@kidfun.test`, fullName: 'Owner' } });
    profile = await prisma.profile.create({ data: { userId: owner.id, profileName: 'Bé Xin Giờ' } });
    device = await prisma.device.create({
      data: { userId: owner.id, profileId: profile.id, deviceName: 'kid', deviceCode: DEVICE_CODE, lastSeen: new Date() },
    });
    await prisma.fCMToken.createMany({
      data: [
        { userId: owner.id, deviceId: null, token: PARENT_TOKEN, platform: 'ANDROID' },
        { userId: owner.id, deviceId: device.id, token: CHILD_TOKEN, platform: 'ANDROID' },
      ],
    });
    auth = `Bearer ${jwt.sign({ userId: owner.id, email: owner.email }, process.env.JWT_SECRET)}`;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: owner.id } });
  });

  beforeEach(async () => {
    sendDataMessage.mockReset();
    sendDataMessage.mockResolvedValue({ success: true });
    await prisma.timeExtensionRequest.deleteMany({ where: { profileId: profile.id } });
    await prisma.usageLog.deleteMany({ where: { profileId: profile.id } });
    await prisma.timeLimit.deleteMany({ where: { profileId: profile.id } });
  });

  it('thông báo cho phụ huynh không gửi tới token của máy trẻ', async () => {
    const tokens = await getParentTokens(owner.id);
    const values = tokens.map((t) => t.token);
    expect(values).toContain(PARENT_TOKEN);
    expect(values).not.toContain(CHILD_TOKEN);
  });

  it('duyệt → máy trẻ nhận FCM extension_response APPROVED', async () => {
    const req = await createRequest();
    const res = await request(app).put(`/api/extension-requests/${req.id}/approve`).set('Authorization', auth).send({});

    expect(res.status).toBe(200);
    expect(sendDataMessage).toHaveBeenCalledWith(
      CHILD_TOKEN,
      expect.objectContaining({ type: 'extension_response', requestId: String(req.id), status: 'APPROVED' }),
    );
    expect(sendDataMessage).not.toHaveBeenCalledWith(PARENT_TOKEN, expect.anything());
  });

  it('từ chối → máy trẻ nhận FCM extension_response REJECTED', async () => {
    const req = await createRequest();
    const res = await request(app).put(`/api/extension-requests/${req.id}/reject`).set('Authorization', auth).send({});

    expect(res.status).toBe(200);
    expect(sendDataMessage).toHaveBeenCalledWith(
      CHILD_TOKEN,
      expect.objectContaining({ type: 'extension_response', status: 'REJECTED' }),
    );
  });

  it('đã vượt hạn mức → duyệt +15p thì còn đúng 15p để dùng', async () => {
    const { dayOfWeek, startOfDay } = vnQuotaDayRange();
    await prisma.timeLimit.create({ data: { profileId: profile.id, dayOfWeek, dailyLimitMinutes: 30 } });
    // Đã dùng 50p (vượt 20p), log đã đóng
    const start = new Date(Math.max(startOfDay.getTime(), Date.now() - 2 * 3600 * 1000));
    await prisma.usageLog.create({
      data: {
        profileId: profile.id, deviceId: device.id, appName: 'KidFun Monitor', activityType: 'MONITORING',
        startTime: start, endTime: new Date(start.getTime() + 50 * 60000), durationSeconds: 50 * 60,
      },
    });

    const req = await createRequest(15);
    const res = await request(app).put(`/api/extension-requests/${req.id}/approve`).set('Authorization', auth).send({});
    expect(res.status).toBe(200);
    expect(res.body.data.responseMinutes).toBe(15);

    const limit = await todayLimit();
    expect(limit.status).toBe(200);
    expect(limit.body.data.remainingMinutes).toBe(15);

    const saved = await prisma.timeExtensionRequest.findUnique({ where: { id: req.id } });
    expect(saved.responseMinutes).toBe(15);
    expect(saved.grantedMinutes).toBe(35);
  });

  it('chưa hết giờ → duyệt +15p cộng đúng 15p', async () => {
    const { dayOfWeek } = vnQuotaDayRange();
    await prisma.timeLimit.create({ data: { profileId: profile.id, dayOfWeek, dailyLimitMinutes: 30 } });

    const req = await createRequest(15);
    await request(app).put(`/api/extension-requests/${req.id}/approve`).set('Authorization', auth).send({});

    const limit = await todayLimit();
    expect(limit.body.data.remainingMinutes).toBe(45);
  });
});
