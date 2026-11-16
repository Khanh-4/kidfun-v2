/**
 * Tài khoản demo cho buổi bảo vệ đồ án (T9.3.2) — CHỈ chạy trên DB test cục bộ (.env.test).
 *
 *   node scripts/thesis-demo.js seed <demo.json>   tạo phụ huynh demo (2 bé) + phụ huynh nền (6 bé) từ ml/e2e/export_demo.py
 *   node scripts/thesis-demo.js cleanup            xoá dữ liệu demo (cascade theo user)
 *
 * Do ml/e2e/run_demo.sh gọi. Đăng nhập app phụ huynh bằng DEMO_EMAIL / DEMO_PASSWORD (mặc định in ra khi seed).
 * Chặn cứng nếu DATABASE_URL trỏ vào Supabase (production).
 */
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');

require('dotenv').config({ path: path.resolve(__dirname, '../.env.test'), override: true });
if (!process.env.DATABASE_URL || /supabase/i.test(process.env.DATABASE_URL)) {
  console.error('DATABASE_URL không phải DB test cục bộ — dừng.');
  process.exit(2);
}

const prisma = require('../src/utils/prisma');

const DEMO_EMAIL = process.env.DEMO_EMAIL || 'demo.baove@kidfun.test';
const DEMO_PASSWORD = process.env.DEMO_PASSWORD || 'demo1234';
const BACKGROUND_EMAIL = 'demo.nen@kidfun.test';

async function cleanup() {
  const { count } = await prisma.user.deleteMany({ where: { email: { in: [DEMO_EMAIL, BACKGROUND_EMAIL] } } });
  console.log(`cleanup: xoá ${count} tài khoản demo`);
}

async function seedChild(userId, child) {
  const profile = await prisma.profile.create({
    data: { userId, profileName: child.name, dateOfBirth: new Date(`${child.dateOfBirth}T00:00:00Z`) },
  });
  const device = await prisma.device.create({
    data: { userId, profileId: profile.id, deviceName: `Máy của ${child.name}`, deviceCode: `thesis_demo_${profile.id}` },
  });
  const ofChild = { profileId: profile.id };
  await prisma.appUsageHourly.createMany({
    data: child.hourly.map((h) => ({ ...ofChild, deviceId: device.id, ...h, hourStart: new Date(h.hourStart) })),
  });
  if (child.limits.length) {
    await prisma.timeLimit.createMany({ data: child.limits.map((l) => ({ ...ofChild, ...l })) });
  }
  if (child.extRequests.length) {
    await prisma.timeExtensionRequest.createMany({
      data: child.extRequests.map((r) => ({ ...ofChild, deviceId: device.id, ...r, createdAt: new Date(r.createdAt) })),
    });
  }
  console.log(`seed: ${child.name} (${child.ageGroup}) → profileId ${profile.id}, ${child.hourly.length} dòng giờ`);
}

async function seed(file) {
  await cleanup();
  const { children } = JSON.parse(fs.readFileSync(file, 'utf8'));
  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 10);
  const parent = await prisma.user.create({ data: { email: DEMO_EMAIL, fullName: 'Phụ huynh Demo', passwordHash } });
  const background = await prisma.user.create({ data: { email: BACKGROUND_EMAIL, fullName: 'Phụ huynh nền (demo)' } });
  for (const child of children) await seedChild(child.demo ? parent.id : background.id, child);
  console.log(`\nĐăng nhập app phụ huynh: ${DEMO_EMAIL} / ${DEMO_PASSWORD}`);
}

async function main() {
  const [cmd, file] = process.argv.slice(2);
  if (cmd === 'seed' && file) return seed(file);
  if (cmd === 'cleanup') return cleanup();
  console.error('Cách dùng: node scripts/thesis-demo.js seed <demo.json> | cleanup');
  process.exitCode = 2;
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
