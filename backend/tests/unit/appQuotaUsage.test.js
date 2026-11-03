const { quotaAppUsageSeconds } = require('../../src/utils/appQuotaUsage');

// Ngày hạn mức D0 = 03/11 (06:00 03/11 → 05:59 04/11 giờ VN).
const D0 = new Date('2026-11-03T00:00:00Z'); // khoá date của AppUsageLog
const D1 = new Date('2026-11-04T00:00:00Z');

describe('quotaAppUsageSeconds — usage từng app trong ngày hạn mức 06:00', () => {
  it('trừ phần 00:00–06:00 của D0 (thuộc ngày hạn mức trước)', () => {
    const logs = [{ packageName: 'yt', date: D0, usageSeconds: 3000 }];
    const early = [{ packageName: 'yt', usageSeconds: 1200 }];
    expect(quotaAppUsageSeconds(logs, early, D0).get('yt')).toBe(1800);
  });

  it('cộng thêm log của D1 khi đang trong khung 00:00–05:59 hôm sau', () => {
    const logs = [
      { packageName: 'yt', date: D0, usageSeconds: 3000 },
      { packageName: 'yt', date: D1, usageSeconds: 600 },
    ];
    expect(quotaAppUsageSeconds(logs, [], D0).get('yt')).toBe(3600);
  });

  it('không âm khi số giờ sớm lớn hơn log ngày', () => {
    const logs = [{ packageName: 'yt', date: D0, usageSeconds: 100 }];
    const early = [{ packageName: 'yt', usageSeconds: 500 }];
    expect(quotaAppUsageSeconds(logs, early, D0).get('yt')).toBe(0);
  });
});
