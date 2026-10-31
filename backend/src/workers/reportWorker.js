const { generateDailyReport, generateWeeklyReport } = require('../services/reportService');
const prisma = require('../utils/prisma');

let isDailyRunning = false;

// Số profile xử lý song song. Chạy tuần tự từng profile (~9 query/profile) làm
// cron vượt maxDuration trên Vercel (timeout 60s lúc 17:53 UTC 2026-10-28).
const PROFILE_CONCURRENCY = 5;
const DAY_MS = 24 * 60 * 60 * 1000;

// "Hôm qua" theo giờ VN, dạng 00:00 UTC của ngày đó — cùng định dạng khoá
// periodStart mà reportController dùng (new Date('YYYY-MM-DD')). Cron chạy
// 17:05 UTC = 00:05 VN; lấy ngày theo UTC sẽ ra hôm kia (lệch 1 ngày).
function vnYesterdayKey(now = new Date()) {
  const vnDateStr = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' }).format(now);
  return new Date(new Date(`${vnDateStr}T00:00:00.000Z`).getTime() - DAY_MS);
}

async function runInBatches(items, size, fn) {
  for (let i = 0; i < items.length; i += size) {
    await Promise.all(items.slice(i, i + size).map(fn));
  }
}

async function runDailyReports() {
  if (isDailyRunning) return;
  isDailyRunning = true;

  try {
    const profiles = await prisma.profile.findMany({ where: { isActive: true } });
    console.log(`📊 [REPORT] Generating daily reports for ${profiles.length} profiles`);

    const yesterday = vnYesterdayKey();

    await runInBatches(profiles, PROFILE_CONCURRENCY, async (profile) => {
      try {
        await generateDailyReport(profile.id, yesterday);
      } catch (err) {
        console.error(`❌ [REPORT] Daily error for profile ${profile.id}:`, err.message);
      }
    });
    console.log(`✅ [REPORT] Daily done`);
  } finally {
    isDailyRunning = false;
  }
}

async function runWeeklyReports() {
  const profiles = await prisma.profile.findMany({ where: { isActive: true } });
  console.log(`📊 [REPORT] Generating weekly reports for ${profiles.length} profiles`);

  const now = new Date();
  const monday = new Date(now);
  const diff = now.getDay() === 0 ? 6 : now.getDay() - 1;
  monday.setDate(now.getDate() - diff - 7); // Previous week monday
  monday.setHours(0, 0, 0, 0);

  await runInBatches(profiles, PROFILE_CONCURRENCY, async (profile) => {
    try {
      await generateWeeklyReport(profile.id, monday);
    } catch (err) {
      console.error(`❌ [REPORT] Weekly error for profile ${profile.id}:`, err.message);
    }
  });
  console.log(`✅ [REPORT] Weekly done`);
}

function startScheduler() {
  setInterval(async () => {
    try {
      const now = new Date();
      const vnNow = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
      const hour = vnNow.getHours();
      const minute = vnNow.getMinutes();
      const day = vnNow.getDay(); // 0 = Sunday, 1 = Monday

      // Daily: mỗi ngày 00:05 VN
      if (hour === 0 && minute >= 5 && minute < 10) {
        await runDailyReports();
      }

      // Weekly: T2 (Monday) 00:10 VN
      if (day === 1 && hour === 0 && minute >= 10 && minute < 15) {
        await runWeeklyReports();
      }
    } catch (err) {
      console.error('❌ [REPORT SCHEDULER] Error:', err.message);
    }
  }, 5 * 60 * 1000); // Check every 5 minutes

  console.log('⏰ [REPORT SCHEDULER] Started');
}

module.exports = { runDailyReports, runWeeklyReports, startScheduler, vnYesterdayKey };
