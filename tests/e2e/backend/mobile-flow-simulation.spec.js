/**
 * Mô phỏng luồng thực tế của mobile app (Flutter DioClient)
 *
 * Bug được tái hiện theo đúng sequence trong logs:
 *   GET /api/profiles 401
 *   GET /api/devices 401
 *   POST /api/auth/refresh-token 401  ← Đây là vấn đề
 *   POST /api/auth/refresh-token 401  (lặp lại nhiều lần)
 *   ...
 *   ❌ [SOCKET] Client disconnected: transport close
 *
 * Root cause:
 *   - Mobile app lưu access_token + refresh_token trong SecureStorage
 *   - Cả 2 token đều invalid (expired > 7 ngày, hoặc JWT_SECRET thay đổi sau deploy)
 *   - DioClient._authInterceptor() khi gặp 401:
 *       1. Lấy refreshToken từ SecureStorage
 *       2. Gọi POST /api/auth/refresh-token → cũng nhận 401
 *       3. catch (_) {} — nuốt lỗi im lặng, KHÔNG logout
 *       4. handler.next(originalError) → caller tiếp tục nhận 401
 *       5. Riverpod provider retry → lại từ bước 1 → infinite loop
 */

const { test, expect } = require('@playwright/test');

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3001';

// Giả lập đúng loại token mà Flutter app lưu trong SecureStorage sau khi
// JWT_SECRET thay đổi trên Railway (vẫn là JWT hợp lệ về format, nhưng signature sai)
const STALE_ACCESS_TOKEN =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' +
  'eyJ1c2VySWQiOjEsImVtYWlsIjoidGVzdEBraWRmdW4uZGV2IiwiaWF0IjoxNzE4MDAwMDAwLCJleHAiOjE3MTgwODY0MDB9.' +
  'OLD_SECRET_SIGNATURE_INVALID_NOW';

const STALE_REFRESH_TOKEN =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' +
  'eyJ1c2VySWQiOjEsImlhdCI6MTcxODAwMDAwMCwiZXhwIjoxNzE4NjA0ODAwfQ.' +
  'OLD_REFRESH_SECRET_SIGNATURE_INVALID';

test.describe('Mô phỏng luồng mobile app khi token expired', () => {
  test('[STEP 1] Mobile khởi động: gọi /api/profiles với token cũ → 401', async ({ request }) => {
    const resp = await request.get(`${BACKEND_URL}/api/profiles`, {
      headers: { Authorization: `Bearer ${STALE_ACCESS_TOKEN}` },
    });
    expect(resp.status()).toBe(401);
    console.log('[STEP 1] ✓ /api/profiles trả 401 — token expired/invalid');
  });

  test('[STEP 2] Mobile khởi động: gọi /api/devices với token cũ → 401', async ({ request }) => {
    const resp = await request.get(`${BACKEND_URL}/api/devices`, {
      headers: { Authorization: `Bearer ${STALE_ACCESS_TOKEN}` },
    });
    expect(resp.status()).toBe(401);
    console.log('[STEP 2] ✓ /api/devices trả 401 — token expired/invalid');
  });

  test('[STEP 3 — BUG] DioClient thử refresh: POST /api/auth/refresh-token với stale refresh token → 401', async ({ request }) => {
    // Flutter DioClient gửi: { refreshToken: <stale_token> }
    const resp = await request.post(`${BACKEND_URL}/api/auth/refresh-token`, {
      data: { refreshToken: STALE_REFRESH_TOKEN },
      headers: { 'Content-Type': 'application/json' },
    });

    // Server trả 401 — đây là vấn đề cốt lõi
    expect(resp.status()).toBe(401);
    const body = await resp.json();
    expect(['INVALID_TOKEN', 'TOKEN_EXPIRED']).toContain(body.code);

    console.log(`[STEP 3 — BUG] ❌ refresh-token trả ${resp.status()} (${body.code})`);
    console.log('[STEP 3 — BUG] ❌ Flutter DioClient: catch (_) {} nuốt lỗi, KHÔNG logout user');
    console.log('[STEP 3 — BUG] ❌ Kết quả: app tiếp tục gọi API → lại 401 → lại refresh → infinite loop');
  });

  test('[STEP 4] FCM token register cũng 401 (từ logs)', async ({ request }) => {
    const resp = await request.post(`${BACKEND_URL}/api/fcm-tokens/register`, {
      data: { token: 'fake_fcm_token' },
      headers: {
        Authorization: `Bearer ${STALE_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
    });
    expect(resp.status()).toBe(401);
    console.log('[STEP 4] ✓ /api/fcm-tokens/register cũng trả 401 — khớp với logs');
  });

  test('[VERIFY] refresh-token với body đúng format nhưng invalid signature → 401 (không crash server)', async ({ request }) => {
    // Đảm bảo server không bị crash hay trả 500 — chỉ trả 401 gracefully
    const resp = await request.post(`${BACKEND_URL}/api/auth/refresh-token`, {
      data: { refreshToken: STALE_REFRESH_TOKEN },
    });
    expect(resp.status()).toBe(401);
    // Server phải trả JSON hợp lệ
    const body = await resp.json();
    expect(body).toHaveProperty('success', false);
    expect(body).toHaveProperty('code');
    expect(body).toHaveProperty('message');
  });

  test('[VERIFY] Extension requests pending cũng 401 (từ logs)', async ({ request }) => {
    const resp = await request.get(`${BACKEND_URL}/api/extension-requests/pending`, {
      headers: { Authorization: `Bearer ${STALE_ACCESS_TOKEN}` },
    });
    expect(resp.status()).toBe(401);
    console.log('[VERIFY] ✓ /api/extension-requests/pending trả 401 — khớp với logs');
  });
});
