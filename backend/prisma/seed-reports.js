const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // 1. Tìm user đầu tiên
  const user = await prisma.user.findFirst();
  if (!user) {
    console.error('Không tìm thấy user nào trong database. Hãy chạy seed trước.');
    process.exit(1);
  }
  console.log(`User: ${user.fullName} (id=${user.id})`);

  // 2. Tìm profile đầu tiên của user
  const profile = await prisma.profile.findFirst({ where: { userId: user.id } });
  if (!profile) {
    console.error('User không có profile nào.');
    process.exit(1);
  }
  console.log(`Profile: ${profile.profileName} (id=${profile.id})`);

  // 3. Tìm device gán cho profile, nếu không có thì tạo mới
  let device = await prisma.device.findFirst({ where: { profileId: profile.id } });
  if (!device) {
    device = await prisma.device.create({
      data: {
        userId: user.id,
        profileId: profile.id,
        deviceName: 'Seed Device',
        deviceCode: 'SEED-' + Date.now(),
      },
    });
    console.log(`Đã tạo device mới: ${device.deviceName} (id=${device.id})`);
  } else {
    console.log(`Device: ${device.deviceName} (id=${device.id})`);
  }

  // 4. Tạo 14 ngày sessions
  const sessions = [];
  const now = new Date();

  for (let dayOffset = 0; dayOffset < 14; dayOffset++) {
    const date = new Date(now);
    date.setDate(date.getDate() - dayOffset);
    date.setHours(0, 0, 0, 0);

    const sessionCount = 1 + Math.floor(Math.random() * 3); // 1-3 sessions

    for (let i = 0; i < sessionCount; i++) {
      const startHour = 8 + Math.floor(Math.random() * 12); // 8:00 - 19:00
      const startMin = Math.floor(Math.random() * 60);
      const duration = 30 + Math.floor(Math.random() * 151); // 30-180 phút

      const startTime = new Date(date);
      startTime.setHours(startHour, startMin, 0, 0);

      const endTime = new Date(startTime.getTime() + duration * 60 * 1000);

      sessions.push({
        profileId: profile.id,
        deviceId: device.id,
        startTime,
        endTime,
        totalMinutes: duration,
        bonusMinutes: 0,
        status: 'COMPLETED',
      });
    }
  }

  // Batch insert
  const result = await prisma.session.createMany({ data: sessions });
  console.log(`Đã tạo ${result.count} sessions cho 14 ngày.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
