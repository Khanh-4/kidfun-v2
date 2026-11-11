const { buildUsageHeatmap, MIN_DAYS_FOR_PREDICTION } = require('../../src/utils/usageHeatmap');

// Giờ VN → mốc UTC của AppUsageHourly.hourStart
const vn = (local) => new Date(Date.parse(`${local}:00Z`) - 7 * 60 * 60 * 1000);

describe('buildUsageHeatmap (T7.5.2)', () => {
  it('lưới 7 thứ × 24 giờ theo giờ VN, trung bình phút trên số tuần', () => {
    const rows = [
      { hourStart: vn('2026-11-09T20:00'), usageSeconds: 30 * 60 }, // thứ Hai 20h
      { hourStart: vn('2026-11-02T20:00'), usageSeconds: 10 * 60 }, // thứ Hai tuần trước 20h
    ];
    const { grid, weeks } = buildUsageHeatmap(rows, { weeks: 4 });

    expect(weeks).toBe(4);
    expect(grid).toHaveLength(7);
    expect(grid.every((r) => r.length === 24)).toBe(true);
    expect(grid[1][20]).toBe(10); // (30 + 10) / 4
    expect(grid[0][0]).toBe(0);
  });

  it('giờ 23h UTC hôm trước là 06h sáng VN hôm sau', () => {
    const { grid } = buildUsageHeatmap([{ hourStart: new Date('2026-11-09T23:00:00Z'), usageSeconds: 4 * 60 }], { weeks: 1 });
    expect(grid[2][6]).toBe(4); // thứ Ba 06h VN
  });

  it('cộng nhiều app cùng giờ; đếm số NGÀY có dữ liệu (không đếm giờ)', () => {
    const rows = [
      { hourStart: vn('2026-11-09T20:00'), usageSeconds: 60 },
      { hourStart: vn('2026-11-09T20:00'), usageSeconds: 60 },
      { hourStart: vn('2026-11-09T21:00'), usageSeconds: 60 },
      { hourStart: vn('2026-11-10T08:00'), usageSeconds: 60 },
    ];
    const { grid, daysWithData } = buildUsageHeatmap(rows, { weeks: 1 });
    expect(grid[1][20]).toBe(2);
    expect(daysWithData).toBe(2);
  });

  it('không có dữ liệu → lưới toàn 0, 0 ngày', () => {
    const { grid, daysWithData } = buildUsageHeatmap([], { weeks: 4 });
    expect(grid.flat().every((v) => v === 0)).toBe(true);
    expect(daysWithData).toBe(0);
    expect(MIN_DAYS_FOR_PREDICTION).toBe(7);
  });
});
