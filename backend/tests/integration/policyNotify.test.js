const request = require('supertest');
const jwt = require('jsonwebtoken');

// Lịch học / giới hạn từng app đổi → máy trẻ phải nhận FCM data 'policy_update'
// (lỗi test 10/11: chỉ emit Socket.IO — trên Vercel `io` null nên không gửi gì,
// máy trẻ chờ tới lượt đồng bộ 5 phút mới áp dụng).
jest.mock('../../src/services/firebaseService', () => ({
  ...jest.requireActual('../../src/services/firebaseService'),
  sendDataMessage: jest.fn(),
}));

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');
const { sendDataMessage } = require('../../src/services/firebaseService');

const STAMP = Date.now();
const TOKEN = `policy_tok_${STAMP}`;
let owner;
let profile;
let auth;

const expectPolicyPush = () =>
  expect(sendDataMessage).toHaveBeenCalledWith(TOKEN, expect.objectContaining({ type: 'policy_update' }));

describe('lịch học / giới hạn app báo máy trẻ qua FCM', () => {
  beforeAll(async () => {
    owner = await prisma.user.create({ data: { email: `policynotify_${STAMP}@kidfun.test`, fullName: 'Owner' } });
    profile = await prisma.profile.create({ data: { userId: owner.id, profileName: 'Bé Học' } });
    const device = await prisma.device.create({
      data: { userId: owner.id, profileId: profile.id, deviceName: 'phone', deviceCode: `policynotify_${STAMP}` },
    });
    await prisma.fCMToken.create({ data: { userId: owner.id, deviceId: device.id, token: TOKEN, platform: 'ANDROID' } });
    auth = `Bearer ${jwt.sign({ userId: owner.id, email: owner.email }, process.env.JWT_SECRET)}`;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: owner.id } });
  });

  beforeEach(() => {
    sendDataMessage.mockReset();
    sendDataMessage.mockResolvedValue({ success: true });
  });

  it('lưu lịch học → gửi policy_update', async () => {
    const res = await request(app)
      .put(`/api/profiles/${profile.id}/school-schedule`)
      .set('Authorization', auth)
      .send({ isEnabled: true, templateStartTime: '07:00', templateEndTime: '11:30', allowedApps: [] });

    expect(res.status).toBe(200);
    expectPolicyPush();
  });

  it('bật chế độ đi học ngay (FORCE_ON) → gửi policy_update', async () => {
    const res = await request(app)
      .post(`/api/profiles/${profile.id}/school-schedule/override`)
      .set('Authorization', auth)
      .send({ action: 'FORCE_ON', durationMinutes: 30 });

    expect(res.status).toBe(200);
    expectPolicyPush();
  });

  it('thêm / xoá giới hạn thời gian app → gửi policy_update', async () => {
    const add = await request(app)
      .post(`/api/profiles/${profile.id}/app-time-limits`)
      .set('Authorization', auth)
      .send({ packageName: 'com.example.game', dailyLimitMinutes: 30 });
    expect(add.status).toBe(201);
    expectPolicyPush();

    sendDataMessage.mockClear();
    const del = await request(app)
      .delete(`/api/profiles/${profile.id}/app-time-limits/com.example.game`)
      .set('Authorization', auth);
    expect(del.status).toBe(200);
    expectPolicyPush();
  });

  it('token hết hạn → xoá khỏi DB, thao tác của phụ huynh vẫn thành công', async () => {
    sendDataMessage.mockResolvedValue({ success: false, error: 'INVALID_TOKEN', token: TOKEN });

    const res = await request(app)
      .post(`/api/profiles/${profile.id}/school-schedule/override`)
      .set('Authorization', auth)
      .send({ action: 'CLEAR' });

    expect(res.status).toBe(200);
    expect(await prisma.fCMToken.count({ where: { token: TOKEN } })).toBe(0);
  });
});
