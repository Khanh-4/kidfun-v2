module.exports = {
  testEnvironment: 'node',

  // Nạp .env.test và chặn nếu đang trỏ vào DB production — xem tests/setup-env.js
  setupFiles: ['<rootDir>/tests/setup-env.js'],

  // src/server.js lúc import tạo Socket.IO server + Prisma pool + Firebase và
  // không ai đóng chúng, nên event loop không bao giờ rỗng: thiếu forceExit là
  // jest treo vĩnh viễn SAU KHI test đã chạy xong (triệu chứng đánh lừa: không
  // in ra gì cả, vì jest buffer output theo suite khi không chạy trong TTY).
  forceExit: true,

  // Test integration đi qua mạng tới DB, 5s mặc định là quá ngắn.
  testTimeout: 20000,
};
