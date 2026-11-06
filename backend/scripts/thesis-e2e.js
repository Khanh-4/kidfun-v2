/**
 * Kiểm thử đầu cuối tác vụ ban đêm của đồ án (T7.3.4) — CHỈ chạy trên DB test cục bộ (.env.test).
 *
 *   node scripts/thesis-e2e.js seed <sim.json>     tạo 1 phụ huynh + 3 trẻ từ ml/e2e/export_sim.py
 *   node scripts/thesis-e2e.js verify <sim.json>   kiểm tra UsagePrediction / BehaviorBaseline / BehaviorAlert
 *   node scripts/thesis-e2e.js cleanup             xoá dữ liệu e2e (cascade theo user)
 *
 * Do ml/e2e/run_local.sh gọi. Chặn cứng nếu DATABASE_URL trỏ vào Supabase (production).
 */
const fs = require('fs');
const path = require('path');

require('dotenv').config({ path: path.resolve(__dirname, '../.env.test'), override: true });
if (!process.env.DATABASE_URL || /supabase/i.test(process.env.DATABASE_URL)) {
  console.error('DATABASE_URL không phải DB test cục bộ — dừng.');
  process.exit(2);
}

const prisma = require('../src/utils/prisma');

const EMAIL = 'thesis_e2e@kidfun.test';
const M1_ALERT_THRESHOLD = 0.6; // = behaviorResultsController.js

const readSim = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));

async function cleanup() {
  const { count } = await prisma.user.deleteMany({ where: { email: EMAIL } });
  console.log(`cleanup: xoá ${count} phụ huynh e2e`);
}

async function seedChild(userId, child) {
  const profile = await prisma.profile.create({ data: { userId, profileName: `E2E ${child.label}` } });
  const device = await prisma.device.create({
    data: { userId, profileId: profile.id, deviceName: 'e2e', deviceCode: `thesis_e2e_${profile.id}` },
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
  console.log(`seed: ${child.label} → profileId ${profile.id} (${child.hourly.length} dòng giờ)`);
}

async function seed(file) {
  await cleanup();
  const sim = readSim(file);
  const user = await prisma.user.create({ data: { email: EMAIL, fullName: 'Phụ huynh E2E' } });
  for (const child of sim.children) await seedChild(user.id, child);
}

// Giới hạn của ngày mai, cùng quy ước dayOfWeek với ml/simulator (0 = Chủ nhật, như getUTCDay).
const limitOn = (child, isoDate) => {
  const dow = new Date(`${isoDate}T00:00:00Z`).getUTCDay();
  return child.limits.find((l) => l.dayOfWeek === dow && l.isActive)?.dailyLimitMinutes ?? null;
};

function checkChild(child, profile, tomorrow, failures) {
  const fail = (msg) => failures.push(`${child.label}: ${msg}`);
  const preds = profile.usagePredictions.filter((p) => p.date.toISOString().slice(0, 10) === tomorrow);
  const alerts = profile.behaviorAlerts.filter((a) => a.source === 'M1');
  if (preds.length !== 1) return fail(`cần 1 dự đoán cho ${tomorrow}, có ${preds.length}`);
  const [p] = preds;
  const expectLimit = limitOn(child, tomorrow);

  if (!(p.predictedMinutes > 0)) fail(`predictedMinutes = ${p.predictedMinutes}`);
  if (!p.modelVersion.startsWith('xgb_')) fail(`modelVersion lạ: ${p.modelVersion}`);
  if (p.limitMinutes !== expectLimit) fail(`limitMinutes = ${p.limitMinutes}, cần ${expectLimit}`);
  if (expectLimit === null && p.pOverLimit !== null) fail('không có giới hạn mà pOverLimit khác null');
  if (expectLimit !== null && !(p.pOverLimit >= 0 && p.pOverLimit <= 1)) fail(`pOverLimit = ${p.pOverLimit}`);
  const wantAlert = p.pOverLimit !== null && p.pOverLimit >= M1_ALERT_THRESHOLD ? 1 : 0;
  if (alerts.length !== wantAlert) fail(`cần ${wantAlert} cảnh báo M1, có ${alerts.length}`);
  if (!profile.behaviorBaseline || profile.behaviorBaseline.validUntil <= new Date()) fail('thiếu baseline còn hạn');

  const pText = p.pOverLimit === null ? '—' : p.pOverLimit.toFixed(3);
  console.log(`${child.label.padStart(5)} | dự đoán ${p.predictedMinutes.toFixed(1)} phút | giới hạn ${expectLimit ?? '—'} `
    + `| p vượt ${pText} | cảnh báo M1: ${alerts.length}${alerts[0] ? ` "${alerts[0].message}"` : ''}`);
}

async function verify(file) {
  const sim = readSim(file);
  const tomorrow = new Date(Date.parse(`${sim.today}T00:00:00Z`) + 86400000).toISOString().slice(0, 10);
  const profiles = await prisma.profile.findMany({
    where: { user: { email: EMAIL } },
    include: { usagePredictions: true, behaviorAlerts: true, behaviorBaseline: true },
    orderBy: { id: 'asc' },
  });
  const failures = [];
  if (profiles.length !== sim.children.length) failures.push(`cần ${sim.children.length} trẻ, có ${profiles.length}`);
  sim.children.forEach((child, i) => profiles[i] && checkChild(child, profiles[i], tomorrow, failures));
  if (failures.length) {
    failures.forEach((f) => console.error(`FAIL ${f}`));
    return 1;
  }
  console.log(`verify: OK (${profiles.length} trẻ, ngày dự đoán ${tomorrow})`);
  return 0;
}

async function main() {
  const [cmd, file] = process.argv.slice(2);
  let code = 0;
  if (cmd === 'seed') await seed(file);
  else if (cmd === 'verify') code = await verify(file);
  else if (cmd === 'cleanup') await cleanup();
  else {
    console.error('Dùng: thesis-e2e.js seed|verify <sim.json> | cleanup');
    code = 2;
  }
  await prisma.$disconnect();
  process.exit(code);
}

main().catch(async (err) => {
  console.error(err);
  await prisma.$disconnect();
  process.exit(1);
});
