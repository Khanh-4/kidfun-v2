#!/usr/bin/env node

/**
 * Script hiển thị IP LAN của máy hiện tại
 * Giúp người dùng biết IP để cấu hình khi chạy trên nhiều thiết bị
 *
 * Chạy: node scripts/get-lan-ip.js
 * Hoặc: npm run lan:ip
 */

const os = require('os');
const nets = os.networkInterfaces();

console.log('');
console.log('=== KidFun V2 - Thông tin mạng LAN ===');
console.log('');

const lanIPs = [];

for (const name of Object.keys(nets)) {
  for (const net of nets[name]) {
    // Chỉ lấy IPv4 và không phải internal (loopback)
    if (net.family === 'IPv4' && !net.internal) {
      lanIPs.push({ name, address: net.address });
    }
  }
}

if (lanIPs.length === 0) {
  console.log('Không tìm thấy địa chỉ IP LAN nào.');
  console.log('Hãy đảm bảo máy đã kết nối mạng WiFi hoặc Ethernet.');
} else {
  console.log('Địa chỉ IP LAN của máy này:');
  console.log('');
  lanIPs.forEach(({ name, address }) => {
    console.log(`  ${name}: ${address}`);
  });

  const primaryIP = lanIPs[0].address;
  console.log('');
  console.log('--- Cấu hình cho các thiết bị khác ---');
  console.log('');
  console.log('1. File frontend/child-monitor/.env (trên máy con):');
  console.log(`   VITE_API_URL=http://${primaryIP}:3001`);
  console.log(`   VITE_SOCKET_URL=http://${primaryIP}:3001`);
  console.log('');
  console.log('2. File frontend/parent-dashboard/.env (nếu chạy trên máy khác):');
  console.log(`   VITE_API_URL=http://${primaryIP}:3001`);
  console.log(`   VITE_SOCKET_URL=http://${primaryIP}:3001`);
  console.log('');
  console.log('3. File backend/.env (trên máy chạy backend):');
  console.log(`   SOCKET_CORS_ORIGIN=http://localhost:3000,http://localhost:3002,http://${primaryIP}:3000,http://${primaryIP}:3002`);
  console.log('');
  console.log('4. Electron (Child Monitor):');
  console.log(`   API_URL=http://${primaryIP}:3001 npm run electron:dev`);
  console.log('');
  console.log('Lưu ý: Mở firewall port 3001 trên máy chạy backend!');
}

console.log('');
