const request = require('supertest');

// Env do tests/setup-env.js nạp (.env.test, có chặn nếu trỏ vào production).
// POST /api/child/session/end — xác thực bằng header X-Device-Code.

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');

const STAMP = Date.now();
let owner;
let profile;
let device;
let otherDevice;
let session;

const end = (deviceCode, body) => {
  const req = request(app).post('/api/child/session/end');
  if (deviceCode) req.set('X-Device-Code', deviceCode);
  return req.send(body);
};

describe('POST /api/child/session/end', () => {
  beforeAll(async () => {
    owner = await prisma.user.create({ data: { email: `sessend_${STAMP}@kidfun.test`, fullName: 'Owner' } });
    profile = await prisma.profile.create({ data: { userId: owner.id, profileName: 'Bé Phiên' } });
    device = await prisma.device.create({
      data: { userId: owner.id, profileId: profile.id, deviceName: 'phone', deviceCode: `sessend_a_${STAMP}` },
    });
    otherDevice = await prisma.device.create({
      data: { userId: owner.id, deviceName: 'tablet', deviceCode: `sessend_b_${STAMP}` },
    });
    session = await prisma.session.create({
      data: { profileId: profile.id, deviceId: device.id, startTime: new Date(Date.now() - 5 * 60000) },
    });
  });

  afterAll(async () => {
    await prisma.session.deleteMany({ where: { deviceId: { in: [device.id, otherDevice.id] } } });
    await prisma.user.deleteMany({ where: { id: owner.id } }); // cascade
  });

  it('trả 400 MISSING_DEVICE_CODE khi thiếu header (app gửi deviceCode rỗng sau khi gỡ liên kết)', async () => {
    const res = await end(null, { sessionId: session.id });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe('MISSING_DEVICE_CODE');
  });

  it('không cho thiết bị khác đóng phiên không phải của nó', async () => {
    const res = await end(otherDevice.deviceCode, { sessionId: session.id });

    expect(res.status).toBe(404);
    const after = await prisma.session.findUnique({ where: { id: session.id } });
    expect(after.status).toBe('ACTIVE');
  });

  it('đóng phiên của chính thiết bị', async () => {
    const res = await end(device.deviceCode, { sessionId: session.id });

    expect(res.status).toBe(200);
    const after = await prisma.session.findUnique({ where: { id: session.id } });
    expect(after.status).toBe('COMPLETED');
    expect(after.totalMinutes).toBeGreaterThanOrEqual(4);
  });
});
