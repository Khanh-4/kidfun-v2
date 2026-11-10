const { grantedMinutesFor, extensionMinutes } = require('../../src/utils/extensionGrant');

// Lỗi test 10/11: trẻ đã dùng 688p, hạn mức 465p → phụ huynh duyệt +15p nhưng
// remaining vẫn 0, máy vẫn khoá. Duyệt khi đã quá giờ phải là "+15p kể từ bây giờ".
describe('grantedMinutesFor', () => {
  it('chưa hết giờ → cộng đúng số phút được duyệt', () => {
    expect(grantedMinutesFor({ approvedMinutes: 15, usedSeconds: 100 * 60, limitMinutes: 120 })).toBe(15);
  });

  it('vừa đúng hết giờ → cộng đúng số phút được duyệt', () => {
    expect(grantedMinutesFor({ approvedMinutes: 15, usedSeconds: 120 * 60, limitMinutes: 120 })).toBe(15);
  });

  it('đã vượt hạn mức → bù phần vượt rồi mới cộng số phút được duyệt', () => {
    expect(grantedMinutesFor({ approvedMinutes: 15, usedSeconds: 688 * 60, limitMinutes: 465 })).toBe(15 + 223);
  });

  it('phần vượt lẻ giây được làm tròn lên để trẻ có đủ số phút', () => {
    expect(grantedMinutesFor({ approvedMinutes: 10, usedSeconds: 60 * 60 + 1, limitMinutes: 60 })).toBe(11);
  });
});

describe('extensionMinutes', () => {
  it('ưu tiên grantedMinutes (đã gồm phần bù)', () => {
    expect(extensionMinutes({ responseMinutes: 15, grantedMinutes: 238 })).toBe(238);
  });

  it('bản ghi cũ chưa có grantedMinutes → dùng responseMinutes', () => {
    expect(extensionMinutes({ responseMinutes: 15, grantedMinutes: null })).toBe(15);
  });

  it('không có số phút nào → 0', () => {
    expect(extensionMinutes({ responseMinutes: null, grantedMinutes: null })).toBe(0);
  });
});
