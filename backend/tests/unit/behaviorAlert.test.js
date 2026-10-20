const { parseBehaviorAlerts, buildMessage, formatMinutes, formatTimes, MAX_ALERTS } = require('../../src/utils/behaviorAlert');

const HOUR_MS = 60 * 60 * 1000;
const NOW = Date.UTC(2026, 9, 20, 12, 30); // 20/10/2026 19:30 giờ VN
const hourAgo = new Date(Math.floor(NOW / HOUR_MS) * HOUR_MS - HOUR_MS).toISOString();

const alert = (overrides = {}) => ({
  rule: 'spike',
  category: 'game',
  dayType: 'school',
  slotStart: hourAgo,
  minutes: 45,
  usualMinutes: 15,
  ...overrides,
});

describe('parseBehaviorAlerts', () => {
  it('nhận cảnh báo hợp lệ và chuẩn hoá slotStart thành Date', () => {
    const { valid, rejected } = parseBehaviorAlerts([alert()], NOW);
    expect(rejected).toBe(0);
    expect(valid[0]).toMatchObject({ rule: 'spike', category: 'game', minutes: 45, usualMinutes: 15 });
    expect(valid[0].slotStart).toEqual(new Date(hourAgo));
  });

  it('loại từng cảnh báo sai mà vẫn giữ cảnh báo đúng', () => {
    const { valid, rejected } = parseBehaviorAlerts(
      [
        alert(),
        alert({ rule: 'binge' }),
        alert({ category: 'banking' }),
        alert({ minutes: 61 }),
        alert({ slotStart: '2026-10-20T11:15:00.000Z' }), // không tròn giờ
        alert({ slotStart: new Date(NOW - 49 * HOUR_MS).toISOString() }), // quá 48 giờ
        alert({ slotStart: new Date(NOW + 2 * HOUR_MS).toISOString() }), // ở tương lai
        alert({ dayType: 'holiday' }),
      ],
      NOW
    );
    expect(valid).toHaveLength(1);
    expect(rejected).toBe(7);
  });

  it('từ chối cả lô khi không phải mảng hoặc quá dài', () => {
    expect(parseBehaviorAlerts(undefined, NOW).error).toBeDefined();
    expect(parseBehaviorAlerts([], NOW).error).toBeDefined();
    expect(parseBehaviorAlerts(Array(MAX_ALERTS + 1).fill(alert()), NOW).error).toBeDefined();
  });
});

describe('buildMessage — cùng mẫu câu với ml/models/explain.py', () => {
  const slot = new Date('2026-10-20T19:00:00.000Z'); // 02:00 sáng 21/10 giờ VN

  it('luật khuya dùng giờ VN', () => {
    expect(buildMessage({ rule: 'night', category: 'game', slotStart: slot, minutes: 38 })).toBe(
      'Bé chơi game lúc 2h trong 38 phút — giờ này bé thường đã ngủ.'
    );
  });

  it('tăng đột biến so với mức thường ngày, làm tròn dễ đọc', () => {
    const evening = new Date('2026-10-20T13:00:00.000Z'); // 20h VN
    expect(buildMessage({ rule: 'spike', category: 'video', slotStart: evening, minutes: 60, usualMinutes: 20 })).toBe(
      'Bé xem video lúc 20h gấp 3 lần so với bình thường (1 giờ, thường khoảng 20 phút).'
    );
  });

  it('mức thường ngày gần 0 thì không nói "gấp N lần"', () => {
    const msg = buildMessage({ rule: 'spike', category: 'social', slotStart: slot, minutes: 25, usualMinutes: 0 });
    expect(msg).toBe('Bé dùng mạng xã hội lúc 2h trong 25 phút — giờ này bé thường hầu như không dùng mạng xã hội.');
  });

  it('định dạng số', () => {
    expect(formatMinutes(45)).toBe('45 phút');
    expect(formatMinutes(150)).toBe('2 giờ 30 phút');
    expect(formatTimes(2.87)).toBe('gấp 3 lần');
    expect(formatTimes(1.46)).toBe('gấp 1,5 lần');
  });
});
