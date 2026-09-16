const request = require('supertest');

// Env do tests/setup-env.js nạp (.env.test, có chặn nếu trỏ vào production)

const app = require('../../src/server');

const TEST_EMAIL = `trace_test_${Date.now()}@kidfun.test`;

let accessToken;

describe('POST /api/devices/:id/delete-trace', () => {
  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: TEST_EMAIL, password: 'TestPass123!', fullName: 'Trace Test' });
    accessToken = res.body.data.token;
  });

  it('ghi log mốc hợp lệ', async () => {
    const log = jest.spyOn(console, 'log').mockImplementation(() => {});

    const res = await request(app)
      .post('/api/devices/181/delete-trace')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ event: 'probe_done', detail: 'alive=false after 75s' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(log.mock.calls.flat().join(' ')).toContain('probe_done');
    log.mockRestore();
  });

  it('cắt detail quá dài', async () => {
    const log = jest.spyOn(console, 'log').mockImplementation(() => {});

    await request(app)
      .post('/api/devices/181/delete-trace')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ event: 'probe_error', detail: 'x'.repeat(5000) });

    const logged = log.mock.calls.flat().join(' ');
    expect(logged.length).toBeLessThan(1000);
    log.mockRestore();
  });

  it('từ chối event sai định dạng', async () => {
    const res = await request(app)
      .post('/api/devices/181/delete-trace')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ event: 'DROP TABLE; \n fake log line' });

    expect(res.status).toBe(400);
  });

  it('yêu cầu đăng nhập', async () => {
    const res = await request(app)
      .post('/api/devices/181/delete-trace')
      .send({ event: 'probe_done' });

    expect(res.status).toBe(401);
  });
});
