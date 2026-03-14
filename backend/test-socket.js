const { io } = require('socket.io-client');

const socket = io('https://kidfun-backend-production.up.railway.app', {
  transports: ['websocket'],
});

socket.on('connect', () => {
  console.log('✅ Connected! Socket ID:', socket.id);
  socket.emit('joinFamily', { userId: 1 });
  console.log('📡 Joined family room');
});

socket.on('connect_error', (err) => {
  console.log('❌ Connection error:', err.message);
});

socket.on('disconnect', (reason) => {
  console.log('🔌 Disconnected:', reason);
});

setTimeout(() => {
  socket.disconnect();
  process.exit(0);
}, 5000);
