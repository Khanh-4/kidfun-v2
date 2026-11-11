// Nhóm tuổi cho tác vụ ML ban đêm (đồ án chuyên ngành): khớp khoá của ml/ (AGE_MID trong models/m1,
// luật gợi ý M4 trong models/m3m4.py). Trẻ ngoài khoảng 3–17 tuổi gom vào nhóm gần nhất.

/**
 * @param {Date|null|undefined} dateOfBirth
 * @param {Date} [now]
 * @returns {'3-5'|'6-10'|'11-14'|'15-17'|null}
 */
const ageGroupOf = (dateOfBirth, now = new Date()) => {
  if (!dateOfBirth) return null;
  const dob = new Date(dateOfBirth);
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  const beforeBirthday =
    now.getUTCMonth() < dob.getUTCMonth() ||
    (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() < dob.getUTCDate());
  if (beforeBirthday) age -= 1;

  if (age < 6) return '3-5';
  if (age < 11) return '6-10';
  if (age < 15) return '11-14';
  return '15-17';
};

module.exports = { ageGroupOf };
