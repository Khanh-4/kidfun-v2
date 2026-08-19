/**
 * Seed data demo cho buổi bảo vệ hội đồng.
 * Chạy: node backend/prisma/seed-defense.js
 */

const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding defense demo data...');

  // ── 1. Parent account ──────────────────────────────────────────────────────
  const hashedPassword = await bcrypt.hash('demo123', 10);
  const parent = await prisma.user.upsert({
    where: { email: 'demo@kidfun.app' },
    update: { passwordHash: hashedPassword, fullName: 'Phụ Huynh Demo' },
    create: {
      email: 'demo@kidfun.app',
      passwordHash: hashedPassword,
      fullName: 'Phụ Huynh Demo',
      phoneNumber: '0901234567',
    },
  });
  console.log(`✅ Parent: ${parent.email} (ID: ${parent.id})`);

  // ── 2. Child profile ───────────────────────────────────────────────────────
  const profile = await prisma.profile.upsert({
    where: { id: 1000 },
    update: { profileName: 'Bé An' },
    create: {
      id: 1000,
      userId: parent.id,
      profileName: 'Bé An',
      dateOfBirth: new Date('2018-06-15'),
      isActive: true,
    },
  });
  console.log(`✅ Profile: ${profile.profileName} (ID: ${profile.id})`);

  // ── 3. Demo device ─────────────────────────────────────────────────────────
  const device = await prisma.device.upsert({
    where: { deviceCode: 'DEMO-DEVICE-2026' },
    update: { profileId: profile.id },
    create: {
      userId: parent.id,
      profileId: profile.id,
      deviceName: 'Điện thoại Bé An (Demo)',
      deviceCode: 'DEMO-DEVICE-2026',
      osVersion: 'Android 13',
      isOnline: false,
    },
  });
  console.log(`✅ Device: ${device.deviceName} (ID: ${device.id})`);

  // ── 4. Time limits 7 ngày ─────────────────────────────────────────────────
  const dailyLimits = [180, 90, 90, 120, 90, 120, 180]; // CN, T2, T3, T4, T5, T6, T7
  for (let day = 0; day < 7; day++) {
    await prisma.timeLimit.upsert({
      where: { profileId_dayOfWeek: { profileId: profile.id, dayOfWeek: day } },
      update: { dailyLimitMinutes: dailyLimits[day], limitMinutes: dailyLimits[day] },
      create: {
        profileId: profile.id,
        dayOfWeek: day,
        dailyLimitMinutes: dailyLimits[day],
        limitMinutes: dailyLimits[day],
        isActive: true,
      },
    });
  }
  console.log('✅ Time limits: 7 ngày đã set');

  // ── 5. App usage logs 7 ngày ──────────────────────────────────────────────
  const apps = [
    { pkg: 'com.google.android.youtube', name: 'YouTube', base: 1800 },
    { pkg: 'com.zhiliaoapp.musically', name: 'TikTok', base: 1200 },
    { pkg: 'com.android.chrome', name: 'Chrome', base: 900 },
    { pkg: 'com.whatsapp', name: 'WhatsApp', base: 300 },
    { pkg: 'com.mojang.minecraftpe', name: 'Minecraft', base: 600 },
  ];

  for (let i = 0; i < 7; i++) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    date.setHours(0, 0, 0, 0);

    for (const app of apps) {
      const variance = Math.floor(Math.random() * 600) - 300;
      await prisma.appUsageLog.upsert({
        where: {
          profileId_deviceId_packageName_date: {
            profileId: profile.id,
            deviceId: device.id,
            packageName: app.pkg,
            date,
          },
        },
        update: {},
        create: {
          profileId: profile.id,
          deviceId: device.id,
          packageName: app.pkg,
          appName: app.name,
          usageSeconds: Math.max(60, app.base + variance),
          date,
        },
      });
    }
  }
  console.log('✅ App usage logs: 7 ngày × 5 apps');

  // ── 6. YouTube logs mẫu ───────────────────────────────────────────────────
  const ytVideos = [
    { title: 'Cocomelon - Wheels on the Bus', channel: 'Cocomelon', danger: 1, category: 'SAFE', summary: 'Bài hát thiếu nhi an toàn, phù hợp mọi lứa tuổi' },
    { title: 'Minecraft Survival Ep.50', channel: 'Dream', danger: 1, category: 'SAFE', summary: 'Gameplay Minecraft sáng tạo, phù hợp mọi lứa tuổi' },
    { title: 'Baby Shark Dance', channel: 'Pinkfong', danger: 1, category: 'SAFE', summary: 'Nhạc thiếu nhi phổ biến, không có nội dung xấu' },
    { title: 'GTA 5 Funny Moments', channel: 'GamingChannel', danger: 3, category: 'VIOLENCE', summary: 'Game bạo lực nhẹ, không phù hợp trẻ dưới 13 tuổi' },
    { title: 'Scary Horror Compilation', channel: 'HorrorChannel', danger: 4, category: 'DISTURBING', summary: 'Nội dung đáng sợ, gây ám ảnh tâm lý, không phù hợp trẻ em' },
    { title: 'Learn Colors with Surprise Eggs', channel: 'KidsTV', danger: 1, category: 'SAFE', summary: 'Video giáo dục màu sắc cho trẻ nhỏ' },
  ];

  const createdYtLogs = [];
  for (let i = 0; i < 7; i++) {
    const date = new Date();
    date.setDate(date.getDate() - i);

    const videosToday = ytVideos.slice(0, 3 + (i % 3));
    for (const v of videosToday) {
      const log = await prisma.youTubeLog.create({
        data: {
          profileId: profile.id,
          deviceId: device.id,
          videoTitle: v.title,
          channelName: v.channel,
          watchedAt: new Date(date.getTime() + Math.random() * 43200000),
          durationSeconds: 60 + Math.floor(Math.random() * 300),
          isAnalyzed: true,
          dangerLevel: v.danger,
          category: v.category,
          aiSummary: v.summary,
          isBlocked: v.danger >= 4,
        },
      }).catch(() => null);
      if (log) createdYtLogs.push({ log, meta: v });
    }
  }
  console.log(`✅ YouTube logs: ${createdYtLogs.length} entries`);

  // ── 7. AI Alerts cho video nguy hiểm ──────────────────────────────────────
  const dangerousLogs = createdYtLogs.filter(({ meta }) => meta.danger >= 4);
  for (const { log, meta } of dangerousLogs) {
    await prisma.aIAlert.create({
      data: {
        profileId: profile.id,
        youtubeLogId: log.id,
        dangerLevel: meta.danger,
        category: meta.category,
        summary: meta.summary,
        notifiedAt: log.watchedAt,
      },
    }).catch(() => {});
  }
  console.log(`✅ AI Alerts: ${dangerousLogs.length} alerts tạo cho video nguy hiểm`);

  // ── 8. Blocked videos ─────────────────────────────────────────────────────
  for (const { log, meta } of dangerousLogs) {
    await prisma.blockedVideo.create({
      data: {
        profileId: profile.id,
        videoTitle: log.videoTitle,
        channelName: log.channelName,
        reason: 'AI_DETECTED',
      },
    }).catch(() => {});
  }

  // ── 9. Geofences ──────────────────────────────────────────────────────────
  await prisma.geofence.upsert({
    where: { id: 9001 },
    update: {},
    create: {
      id: 9001,
      profileId: profile.id,
      name: 'Nhà',
      latitude: 10.762622,
      longitude: 106.660172,
      radius: 200,
      isActive: true,
    },
  });
  await prisma.geofence.upsert({
    where: { id: 9002 },
    update: {},
    create: {
      id: 9002,
      profileId: profile.id,
      name: 'Trường học',
      latitude: 10.770,
      longitude: 106.665,
      radius: 300,
      isActive: true,
    },
  });
  console.log('✅ Geofences: Nhà + Trường học');

  // ── 10. School schedule ───────────────────────────────────────────────────
  const existingSchedule = await prisma.schoolSchedule.findUnique({
    where: { profileId: profile.id },
  });
  if (!existingSchedule) {
    const schedule = await prisma.schoolSchedule.create({
      data: {
        profileId: profile.id,
        isEnabled: true,
        templateStartTime: '07:00',
        templateEndTime: '11:30',
      },
    });

    // Day schedules: T2-T6 enabled, CN+T7 disabled
    for (let day = 0; day < 7; day++) {
      const isSchoolDay = day >= 1 && day <= 5;
      await prisma.schoolDaySchedule.create({
        data: {
          scheduleId: schedule.id,
          dayOfWeek: day,
          isEnabled: isSchoolDay,
          startTime: isSchoolDay ? '07:00' : '00:00',
          endTime: isSchoolDay ? '11:30' : '00:00',
        },
      });
    }

    // Allowed apps during school
    await prisma.allowedSchoolApp.createMany({
      data: [
        { scheduleId: schedule.id, packageName: 'com.zoom.us', appName: 'Zoom' },
        { scheduleId: schedule.id, packageName: 'com.google.android.apps.classroom', appName: 'Google Classroom' },
      ],
    });
    console.log('✅ School schedule: T2-T6 07:00-11:30, cho phép Zoom + Google Classroom');
  } else {
    console.log('⏭️  School schedule: đã tồn tại, bỏ qua');
  }

  // ── 11. Web category blocking ─────────────────────────────────────────────
  const categoriesToBlock = ['adult', 'gambling'];
  for (const catName of categoriesToBlock) {
    const cat = await prisma.webCategory.findFirst({ where: { name: catName } });
    if (cat) {
      await prisma.blockedCategory.upsert({
        where: { profileId_categoryId: { profileId: profile.id, categoryId: cat.id } },
        update: {},
        create: { profileId: profile.id, categoryId: cat.id, isBlocked: true },
      });
    }
  }
  console.log('✅ Web filtering: Người lớn + Cờ bạc đã bật');

  // ── 12. Per-app limit (YouTube) ───────────────────────────────────────────
  await prisma.appTimeLimit.upsert({
    where: { profileId_packageName: { profileId: profile.id, packageName: 'com.google.android.youtube' } },
    update: {},
    create: {
      profileId: profile.id,
      packageName: 'com.google.android.youtube',
      appName: 'YouTube',
      dailyLimitMinutes: 60,
    },
  });
  console.log('✅ Per-app limit: YouTube 60 phút/ngày');

  // ── Done ───────────────────────────────────────────────────────────────────
  console.log('\n🎉 Defense demo data seeded thành công!');
  console.log('📧 Login: demo@kidfun.app / demo123');
  console.log(`👶 Profile: Bé An (ID: ${profile.id})`);
  console.log(`📱 Device code: DEMO-DEVICE-2026`);
}

main()
  .catch((err) => {
    console.error('❌ Seed failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
