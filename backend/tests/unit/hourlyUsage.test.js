const { parseHourlyBuckets, MAX_BUCKETS } = require('../../src/utils/hourlyUsage');

// Mốc "bây giờ" cố định: 2026-10-17 02:30 giờ VN = 2026-10-16T19:30:00Z
const NOW = new Date('2026-10-16T19:30:00.000Z');

const bucket = (overrides = {}) => ({
  packageName: 'com.google.android.youtube',
  appName: 'YouTube',
  hourStart: '2026-10-16T19:00:00.000Z',
  usageSeconds: 1200,
  launchCount: 2,
  ...overrides,
});

describe('parseHourlyBuckets', () => {
  it('nhận ô hợp lệ và chuẩn hoá hourStart thành Date', () => {
    const { valid, rejected } = parseHourlyBuckets([bucket()], NOW);

    expect(rejected).toBe(0);
    expect(valid).toEqual([
      {
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        hourStart: new Date('2026-10-16T19:00:00.000Z'),
        usageSeconds: 1200,
        launchCount: 2,
      },
    ]);
  });

  it('launchCount và appName là tuỳ chọn', () => {
    const { valid } = parseHourlyBuckets(
      [bucket({ launchCount: undefined, appName: undefined })],
      NOW
    );

    expect(valid[0].launchCount).toBe(0);
    expect(valid[0].appName).toBeNull();
  });

  it('loại ô có hourStart không tròn giờ', () => {
    const { valid, rejected } = parseHourlyBuckets(
      [bucket({ hourStart: '2026-10-16T19:15:00.000Z' })],
      NOW
    );

    expect(valid).toHaveLength(0);
    expect(rejected).toBe(1);
  });

  it('loại ô ở giờ tương lai nhưng chấp nhận đồng hồ máy trẻ nhanh vài phút', () => {
    // 19:55 server, đồng hồ máy trẻ nhanh 6 phút đã sang giờ 20:00
    const now = new Date('2026-10-16T19:55:00.000Z');
    const { valid } = parseHourlyBuckets(
      [
        bucket({ hourStart: '2026-10-16T20:00:00.000Z' }),
        bucket({ hourStart: '2026-10-16T21:00:00.000Z', packageName: 'com.x' }),
      ],
      now
    );

    expect(valid.map((b) => b.packageName)).toEqual(['com.google.android.youtube']);
  });

  it('loại ô cũ hơn 7 ngày', () => {
    const { valid, rejected } = parseHourlyBuckets(
      [bucket({ hourStart: '2026-10-09T18:00:00.000Z' })],
      NOW
    );

    expect(valid).toHaveLength(0);
    expect(rejected).toBe(1);
  });

  it.each([
    ['usageSeconds âm', { usageSeconds: -1 }],
    ['usageSeconds quá 1 giờ', { usageSeconds: 3601 }],
    ['usageSeconds không phải số nguyên', { usageSeconds: 12.5 }],
    ['launchCount âm', { launchCount: -3 }],
    ['thiếu packageName', { packageName: '' }],
    ['packageName quá dài', { packageName: 'a'.repeat(256) }],
    ['hourStart không phải ngày', { hourStart: 'hôm qua' }],
  ])('loại ô khi %s', (_label, overrides) => {
    const { valid, rejected } = parseHourlyBuckets([bucket(overrides)], NOW);

    expect(valid).toHaveLength(0);
    expect(rejected).toBe(1);
  });

  it('gộp ô trùng (cùng package, cùng giờ) — giữ ô sau cùng', () => {
    const { valid } = parseHourlyBuckets(
      [bucket({ usageSeconds: 100 }), bucket({ usageSeconds: 300 })],
      NOW
    );

    expect(valid).toHaveLength(1);
    expect(valid[0].usageSeconds).toBe(300);
  });

  it('báo lỗi khi buckets không phải mảng, rỗng hoặc quá dài', () => {
    expect(parseHourlyBuckets(undefined, NOW).error).toBeDefined();
    expect(parseHourlyBuckets([], NOW).error).toBeDefined();
    expect(parseHourlyBuckets(Array(MAX_BUCKETS + 1).fill(bucket()), NOW).error).toBeDefined();
  });
});
