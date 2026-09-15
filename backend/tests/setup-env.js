/**
 * Chạy trước MỌI test file (jest.config.js → setupFiles).
 *
 * Hai việc:
 *   1. Nạp `.env.test` thay cho `.env`. Trước đây từng test file tự nạp
 *      `../../.env` — mà file đó trỏ thẳng vào Supabase production, nên
 *      `npm test` đăng ký user thật vào DB thật và reset cờ isOnline của
 *      thiết bị thật.
 *   2. Chặn cứng nếu DATABASE_URL vẫn trỏ ra Supabase. Thà không chạy được
 *      còn hơn âm thầm ghi vào dữ liệu production.
 */
const fs = require('fs');
const path = require('path');

const testEnvPath = path.resolve(__dirname, '../.env.test');
const hasTestEnv = fs.existsSync(testEnvPath);

require('dotenv').config({
  path: hasTestEnv ? testEnvPath : path.resolve(__dirname, '../.env'),
});

const url = process.env.DATABASE_URL || '';

if (!hasTestEnv) {
  throw new Error(
    '\n\n  Thiếu backend/.env.test — test sẽ chạy thẳng vào DB production.\n' +
      '  Tạo DB test cục bộ rồi copy .env.test.example thành .env.test:\n\n' +
      '    sudo -u postgres createdb -O $USER kidfun_test\n' +
      '    cp backend/.env.test.example backend/.env.test\n' +
      '    cd backend && DATABASE_URL="postgresql://$USER@localhost/kidfun_test?host=/var/run/postgresql" npx prisma db push\n\n'
  );
}

if (/supabase/i.test(url)) {
  throw new Error(
    '\n\n  DATABASE_URL trong .env.test đang trỏ vào Supabase (production).\n' +
      '  Test sẽ tạo/xoá dữ liệu thật — đổi sang DB cục bộ trước khi chạy.\n\n'
  );
}
