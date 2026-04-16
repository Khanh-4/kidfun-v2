const { generateDailyReport, generateWeeklyReport } = require('../services/reportService');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

let isDailyRunning = false;

async function runDailyReports() {
  if (isDailyRunning) return;
  isDailyRunning = true;

  try {
    const profiles = await prisma.profile.findMany({ where: { isActive: true } });
    console.log(`📊 [REPORT] Generating daily reports for ${profiles.length} profiles`);

    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);

    for (const profile of profiles) {
      try {
        await generateDailyReport(profile.id, yesterday);
      } catch (err) {
        console.error(`❌ [REPORT] Daily error for profile ${profile.id}:`, err.message);
      }
    }
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

  for (const profile of profiles) {
    try {
      await generateWeeklyReport(profile.id, monday);
    } catch (err) {
      console.error(`❌ [REPORT] Weekly error for profile ${profile.id}:`, err.message);
    }
  }
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

module.exports = { runDailyReports, runWeeklyReports, startScheduler };
