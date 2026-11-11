const { ageGroupOf } = require('../../src/utils/ageGroup');

const NOW = new Date('2026-11-11T08:00:00Z');

// Nhóm tuổi khớp ml/ (AGE_MID, luật M4): "3-5" | "6-10" | "11-14" | "15-17".
describe('ageGroupOf', () => {
  it.each([
    ['2023-11-11', '3-5'],   // 3 tuổi
    ['2025-01-01', '3-5'],   // < 3 tuổi vẫn vào nhóm nhỏ nhất
    ['2020-11-12', '3-5'],   // còn 1 ngày nữa mới 6 tuổi
    ['2020-11-11', '6-10'],  // đúng sinh nhật 6 tuổi
    ['2015-06-01', '11-14'],
    ['2011-11-11', '15-17'],
    ['2000-01-01', '15-17'], // > 17 vẫn vào nhóm lớn nhất
  ])('sinh %s → %s', (dob, group) => {
    expect(ageGroupOf(new Date(dob), NOW)).toBe(group);
  });

  it('không có ngày sinh → null', () => {
    expect(ageGroupOf(null, NOW)).toBeNull();
  });
});
