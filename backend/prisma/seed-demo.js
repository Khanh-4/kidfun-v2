const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const prisma = new PrismaClient();

// Parse VN date string → UTC midnight Date (khớp với cách appUsageController lưu)
const getUtcMidnight = (offsetDays = 0) => {
  const vnNow = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' }).format(new Date());
  const d = new Date(vnNow + 'T00:00:00.000Z');
  d.setUTCDate(d.getUTCDate() - offsetDays);
  return d;
};

async function main() {
  console.log('🌱 Seeding demo data...\n');

  // ── 1. Tài khoản Parent demo ──────────────────────────────────────────────
  const hashedPassword = await bcrypt.hash('demo123', 10);
  const parent = await prisma.user.upsert({
    where: { email: 'demo@kidfun.app' },
    update: {},
    create: {
      email: 'demo@kidfun.app',
      passwordHash: hashedPassword,
      fullName: 'Phụ Huynh Demo',
      phoneNumber: '0901234567',
    },
  });
  console.log('✅ Parent account:', parent.email, `(id=${parent.id})`);

  // ── 2. Profile con ────────────────────────────────────────────────────────
  let profile = await prisma.profile.findFirst({
    where: { userId: parent.id, profileName: 'Bé An' },
  });
  if (!profile) {
    profile = await prisma.profile.create({
      data: {
        userId: parent.id,
        profileName: 'Bé An',
        dateOfBirth: new Date('2018-06-15'),
        isActive: true,
      },
    });
  }
  console.log('✅ Child profile:', profile.profileName, `(id=${profile.id})`);

  // ── 3. Time limits 7 ngày ─────────────────────────────────────────────────
  const daysConfig = [
    { day: 0, limit: 180 }, // CN: 3h
    { day: 1, limit: 90 },  // T2: 1.5h
    { day: 2, limit: 90 },  // T3: 1.5h
    { day: 3, limit: 120 }, // T4: 2h
    { day: 4, limit: 90 },  // T5: 1.5h
    { day: 5, limit: 120 }, // T6: 2h
    { day: 6, limit: 180 }, // T7: 3h
  ];
  for (const dc of daysConfig) {
    await prisma.timeLimit.upsert({
      where: { profileId_dayOfWeek: { profileId: profile.id, dayOfWeek: dc.day } },
      update: { dailyLimitMinutes: dc.limit, limitMinutes: dc.limit },
      create: {
        profileId: profile.id,
        dayOfWeek: dc.day,
        dailyLimitMinutes: dc.limit,
        limitMinutes: dc.limit,
        isActive: true,
      },
    });
  }
  console.log('✅ Time limits set for 7 days');

  // ── 4. Demo device ────────────────────────────────────────────────────────
  let device = await prisma.device.findFirst({
    where: { userId: parent.id, profileId: profile.id },
  });
  if (!device) {
    device = await prisma.device.create({
      data: {
        userId: parent.id,
        profileId: profile.id,
        deviceName: 'Điện thoại Demo',
        deviceCode: 'DEMO-DEVICE-001',
      },
    });
  }
  console.log('✅ Demo device:', device.deviceName, `(code=${device.deviceCode})`);

  // ── 5. App usage data 7 ngày ──────────────────────────────────────────────
  const apps = [
    { pkg: 'com.google.android.youtube', name: 'YouTube',   base: 1800 },
    { pkg: 'com.zhiliaoapp.musically',   name: 'TikTok',    base: 1200 },
    { pkg: 'com.instagram.android',      name: 'Instagram', base: 600  },
    { pkg: 'com.android.chrome',         name: 'Chrome',    base: 900  },
    { pkg: 'com.whatsapp',               name: 'WhatsApp',  base: 300  },
  ];

  for (let i = 0; i < 7; i++) {
    const date = getUtcMidnight(i);
    for (const app of apps) {
      const variance = Math.floor(Math.random() * 600) - 300; // ±5 phút
      const usageSeconds = Math.max(60, app.base + variance);
      await prisma.appUsageLog.upsert({
        where: {
          profileId_deviceId_packageName_date: {
            profileId: profile.id,
            deviceId: device.id,
            packageName: app.pkg,
            date,
          },
        },
        update: { usageSeconds },
        create: {
          profileId: profile.id,
          deviceId: device.id,
          packageName: app.pkg,
          appName: app.name,
          usageSeconds,
          date,
        },
      });
    }
  }
  console.log('✅ App usage data seeded for 7 days');

  // ── 6. Session history 7 ngày ─────────────────────────────────────────────
  const vnNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
  for (let i = 1; i <= 7; i++) {
    const date = new Date(vnNow);
    date.setDate(date.getDate() - i);
    date.setHours(9, 0, 0, 0); // 9:00 sáng

    // Kiểm tra đã có session hôm đó chưa
    const existing = await prisma.session.findFirst({
      where: {
        deviceId: device.id,
        startTime: { gte: new Date(date.getFullYear(), date.getMonth(), date.getDate()) },
      },
    });
    if (!existing) {
      const limitMin = daysConfig[date.getDay()]?.limit || 120;
      const durationMin = Math.min(limitMin, 60 + Math.floor(Math.random() * 60));
      const endTime = new Date(date.getTime() + durationMin * 60000);
      await prisma.session.create({
        data: {
          profileId: profile.id,
          deviceId: device.id,
          startTime: date,
          endTime,
          totalMinutes: durationMin,
          bonusMinutes: 0,
          status: 'COMPLETED',
        },
      });
    }
  }
  console.log('✅ Session history seeded for 7 days');

  console.log('\n🎉 Demo data ready!');
  console.log('📧 Login: demo@kidfun.app / demo123');
  console.log(`👶 Profile: ${profile.profileName} (id=${profile.id})`);
  console.log(`📱 Device code: ${device.deviceCode}`);
}

main()
  .catch((e) => {
    console.error('❌ Seed error:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
