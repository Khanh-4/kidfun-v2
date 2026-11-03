const request = require('supertest');

// Khởi động lại máy trẻ: app gọi today-limit TRƯỚC session/start, lúc đó log
// phiên cũ còn mở. Thời gian máy tắt (sau lastSeen) không được tính là đã dùng.
const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');

const STAMP = Date.now();
const MIN = 60 * 1000;
let owner;

describe('GET /api/child/today-limit sau khi khởi động lại', () => {
  afterAll(async () => {
    await prisma.usageLog.deleteMany({ where: { profile: { userId: owner.id } } });
    await prisma.user.deleteMany({ where: { id: owner.id } });
  });

  it('cắt log mở ở lastSeen khi máy im lặng lâu', async () => {
    owner = await prisma.user.create({ data: { email: `reboot_${STAMP}@kidfun.test`, fullName: 'Owner' } });
    const profile = await prisma.profile.create({ data: { userId: owner.id, profileName: 'Bé Reboot' } });
    const now = Date.now();
    const device = await prisma.device.create({
      data: {
        userId: owner.id, profileId: profile.id, deviceName: 'phone', deviceCode: `reboot_${STAMP}`,
        lastSeen: new Date(now - 30 * MIN), // tắt máy 30 phút trước
      },
    });
    // Dùng 10 phút rồi tắt máy: log mở từ 40 phút trước
    await prisma.usageLog.create({
      data: { profileId: profile.id, deviceId: device.id, appName: 'KidFun', activityType: 'SESSION', startTime: new Date(now - 40 * MIN) },
    });

    const res = await request(app).get('/api/child/today-limit').query({ deviceCode: device.deviceCode });

    expect(res.status).toBe(200);
    expect(res.body.data.usedMinutes).toBe(10);
  });
});
