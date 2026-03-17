import axios from 'axios';

const API_URL = (import.meta.env.VITE_API_URL || 'http://localhost:3001') + '/api';

console.log('[API] Base URL:', API_URL);

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

// Interceptor để unwrap response format { success, data } từ backend
api.interceptors.response.use(
  (response) => {
    if (response.data && response.data.success !== undefined && response.data.data !== undefined) {
      response.data = response.data.data;
    }
    return response;
  },
  (error) => Promise.reject(error)
);

export default api;