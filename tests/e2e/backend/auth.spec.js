/**
 * Backend API E2E Tests: Authentication & Token Refresh
 *
 * Mục tiêu: Tái hiện chính xác luồng mà app mobile Android thực hiện:
 *   1. Đăng nhập → lấy access token + refresh token
 *   2. Gọi API với access token hợp lệ → 200
 *   3. Gọi API với access token expired/invalid → 401
 *   4. Thử refresh với refresh token hợp lệ → 200 + token mới
 *   5. Thử refresh với refresh token invalid → 401 (BUG: mobile app không handle được này)
 *   6. Thử refresh với không có body → 400
 */

const { test, expect } = require('@playwright/test');

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3001';

// Token fake để test 401 — giống với gì Flutter app lưu trong SecureStorage khi expire
const FAKE_EXPIRED_TOKEN =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' +
  'eyJ1c2VySWQiOjEsImVtYWlsIjoicGFyZW50QGtpZGZ1bi5kZXYiLCJpYXQiOjE2MDAwMDAwMDAsImV4cCI6MTYwMDAwMzYwMH0.' +
  'INVALID_SIGNATURE_TO_SIMULATE_EXPIRED';

const FAKE_EXPIRED_REFRESH_TOKEN =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' +
  'eyJ1c2VySWQiOjEsImlhdCI6MTYwMDAwMDAwMCwiZXhwIjoxNjAwNjA0ODAwfQ.' +
  'INVALID_REFRESH_SIGNATURE';

test.describe('Backend Auth API', () => {
  // ── Kiểm tra endpoint login ────────────────────────────────────────────

  test('login: email không tồn tại → 401 EMAIL_NOT_FOUND', async ({ request }) => {
    const resp = await request.post(`${BACKEND_URL}/api/auth/login`, {
      data: { email: 'nonexistent@kidfun.dev', password: 'password123' },
    });
    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.success).toBe(false);
    expect(body.code).toBe('EMAIL_NOT_FOUND');
  });

  test('login: thiếu email/password → 400', async ({ request }) => {
    const resp = await request.post(`${BACKEND_URL}/api/auth/login`, {
      data: { email: 'test@test.com' }, // thiếu password
    });
    expect(resp.status()).toBe(400);
  });

  // ── Kiểm tra API với token invalid (mô phỏng mobile: token hết hạn) ───

  test('profiles: không có token → 401 MISSING_TOKEN', async ({ request }) => {
    const resp = await request.get(`${BACKEND_URL}/api/profiles`);
    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.code).toBe('MISSING_TOKEN');
  });

  test('profiles: token invalid/expired → 401', async ({ request }) => {
    const resp = await request.get(`${BACKEND_URL}/api/profiles`, {
      headers: { Authorization: `Bearer ${FAKE_EXPIRED_TOKEN}` },
    });
    expect(resp.status()).toBe(401);
    const body = await resp.json();
    // Backend trả INVALID_TOKEN hoặc TOKEN_EXPIRED
    expect(['INVALID_TOKEN', 'TOKEN_EXPIRED']).toContain(body.code);
  });

  test('devices: token invalid/expired → 401', async ({ request }) => {
    const resp = await request.get(`${BACKEND_URL}/api/devices`, {
      headers: { Authorization: `Bearer ${FAKE_EXPIRED_TOKEN}` },
    });
    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(['INVALID_TOKEN', 'TOKEN_EXPIRED']).toContain(body.code);
  });

  test('extension-requests/pending: token invalid → 401', async ({ request }) => {
    const resp = await request.get(`${BACKEND_URL}/api/extension-requests/pending`, {
      headers: { Authorization: `Bearer ${FAKE_EXPIRED_TOKEN}` },
    });
    expect(resp.status()).toBe(401);
  });

  // ── Kiểm tra refresh token endpoint (CORE BUG AREA) ──────────────────

  test('[BUG REPRODUCTION] refresh-token: refresh token invalid → 401 INVALID_TOKEN', async ({ request }) => {
    // Đây chính xác là gì mobile app gửi khi SecureStorage chứa token cũ/sai
    const resp = await request.post(`${BACKEND_URL}/api/auth/refresh-token`, {
      data: { refreshToken: FAKE_EXPIRED_REFRESH_TOKEN },
    });
    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(body.success).toBe(false);
    // Server phân biệt được: INVALID_TOKEN (chữ ký sai) hoặc TOKEN_EXPIRED (hết hạn)
    expect(['INVALID_TOKEN', 'TOKEN_EXPIRED']).toContain(body.code);
    console.log(`[BUG] Khi mobile gọi refresh-token với token cũ → server trả: ${body.code}`);
    console.log(`[BUG] Mobile app KHÔNG handle case này → infinite loop cho đến khi socket disconnect`);
  });

  test('refresh-token: không có refreshToken trong body → 400 MISSING_TOKEN', async ({ request }) => {
    const resp = await request.post(`${BACKEND_URL}/api/auth/refresh-token`, {
      data: {},
    });
    expect(resp.status()).toBe(400);
    const body = await resp.json();
    expect(body.code).toBe('MISSING_TOKEN');
  });

  test('refresh-token: refreshToken null/empty → 400', async ({ request }) => {
    const resp = await request.post(`${BACKEND_URL}/api/auth/refresh-token`, {
      data: { refreshToken: '' },
    });
    // Empty string nhưng truthy check fails trong backend
    expect([400, 401]).toContain(resp.status());
  });
});
