import axios from 'axios';

const API_URL = 'http://localhost:3001/api';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Thêm device code vào header
api.interceptors.request.use((config) => {
  const deviceCode = localStorage.getItem('deviceCode');
  if (deviceCode) {
    config.headers['X-Device-Code'] = deviceCode;
  }
  return config;
});

export default api;