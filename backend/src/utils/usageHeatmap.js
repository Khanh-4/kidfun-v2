// Heatmap giờ × thứ cho tab "AI Insights" (đồ án chuyên ngành, T7.5.2) và số ngày có dữ liệu cho
// trạng thái rỗng (T7.5.4). Đọc từ AppUsageHourly (mốc UTC) → quy về giờ VN.

const { VN_OFFSET_MS } = require('./vnTime');

/** = MIN_HISTORY_DAYS của ml/jobs/predict.py: dưới số ngày này tác vụ ban đêm chưa dự đoán. */
const MIN_DAYS_FOR_PREDICTION = 7;

const round1 = (x) => Math.round(x * 10) / 10;

/**
 * @param {{ hourStart: Date, usageSeconds: number }[]} rows dữ liệu trong `weeks` tuần gần nhất
 * @param {{ weeks: number }} opts
 * @returns {{ weeks: number, grid: number[][], daysWithData: number }}
 *   grid[thứ 0=CN..6][giờ 0..23] = số phút trung bình mỗi tuần
 */
const buildUsageHeatmap = (rows, { weeks }) => {
  const seconds = Array.from({ length: 7 }, () => new Array(24).fill(0));
  const days = new Set();

  for (const { hourStart, usageSeconds } of rows) {
    const local = new Date(new Date(hourStart).getTime() + VN_OFFSET_MS);
    seconds[local.getUTCDay()][local.getUTCHours()] += usageSeconds;
    days.add(local.toISOString().slice(0, 10));
  }

  const grid = seconds.map((row) => row.map((s) => round1(s / 60 / weeks)));
  return { weeks, grid, daysWithData: days.size };
};

module.exports = { buildUsageHeatmap, MIN_DAYS_FOR_PREDICTION };
