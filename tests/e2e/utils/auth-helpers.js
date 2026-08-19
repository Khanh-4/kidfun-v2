// Helper để setup auth state cho các test
const { request } = require('@playwright/test');

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3001';
const TEST_EMAIL = process.env.TEST_EMAIL || 'test@kidfun.dev';
const TEST_PASSWORD = process.env.TEST_PASSWORD || 'test123456';

/**
 * Đăng nhập qua API và trả về token, refreshToken, user
 */
async function loginViaApi() {
  const apiContext = await request.newContext();
  const response = await apiContext.post(`${BACKEND_URL}/api/auth/login`, {
    data: { email: TEST_EMAIL, password: TEST_PASSWORD },
  });
  if (!response.ok()) {
    throw new Error(`Login failed: ${response.status()} — ${await response.text()}`);
  }
  const body = await response.json();
  await apiContext.dispose();
  return body.data; // { token, refreshToken, user }
}

/**
 * Set localStorage auth state (token + user) để bỏ qua form login
 */
async function setAuthState(page, { token, user }) {
  await page.addInitScript(({ token, user }) => {
    localStorage.setItem('token', token);
    localStorage.setItem('user', JSON.stringify(user));
  }, { token, user });
}

/**
 * Set localStorage với token GIẢ (expired/invalid) để giả lập token hết hạn
 */
async function setExpiredToken(page) {
  const fakeExpiredToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' +
    'eyJ1c2VySWQiOjEsImVtYWlsIjoidGVzdEBraWRmdW4uZGV2IiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjE2MDAwMDM2MDB9.' +
    'INVALID_SIGNATURE';
  const fakeUser = { id: 1, email: TEST_EMAIL, fullName: 'Test User' };

  await page.addInitScript(({ token, user }) => {
    localStorage.setItem('token', token);
    localStorage.setItem('user', JSON.stringify(user));
  }, { token: fakeExpiredToken, user: fakeUser });
}

/**
 * Xóa auth state (giả lập chưa đăng nhập)
 */
async function clearAuthState(page) {
  await page.addInitScript(() => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  });
}

module.exports = { loginViaApi, setAuthState, setExpiredToken, clearAuthState, BACKEND_URL };
