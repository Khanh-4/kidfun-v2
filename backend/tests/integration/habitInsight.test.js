const request = require('supertest');
const jwt = require('jsonwebtoken');

// T7.5.3 — tác vụ ban đêm gửi nhóm thói quen (M3) + gợi ý (M4); app phụ huynh đọc bản mới nhất.
process.env.CRON_SECRET = process.env.CRON_SECRET || 'test-cron-secret';

const app = require('../../src/server');
const prisma = require('../../src/utils/prisma');

const TAG = `habit_test_${Date.now()}`;
let parent;
let stranger;
let profileId;

const put = (body) =>
  request(app).put('/api/cron/habit-insights').set('Authorization', `Bearer ${process.env.CRON_SECRET}`).send(body);
const tokenOf = (user) => jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET);
const get = (id, user) => request(app).get(`/api/profiles/${id}/habit-insight`).set('Authorization', `Bearer ${tokenOf(user)}`);
const insight = (over = {}) => ({
  profileId,
  date: '2026-11-10',
  habitSummary: 'hay dùng khuya, nghiêng về game',
  clusterId: 1,
  clusterCount: 3,
  suggestions: [{ code: 'gio_ngu', text: 'Tuần qua bé dùng máy sau nửa đêm ở 4 đêm.' }],
  ...over,
});

describe('Nhóm thói quen + gợi ý (T7.5.3)', () => {
  beforeAll(async () => {
    parent = await prisma.user.create({ data: { email: `${TAG}@kidfun.test`, fullName: 'Habit Parent' } });
    stranger = await prisma.user.create({ data: { email: `${TAG}_x@kidfun.test`, fullName: 'Stranger' } });
    profileId = (await prisma.profile.create({ data: { userId: parent.id, profileName: 'Bé Cúc' } })).id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: { in: [parent.id, stranger.id] } } });
    await prisma.$disconnect();
  });

  it('thiếu CRON_SECRET → 401', async () => {
    const res = await request(app).put('/api/cron/habit-insights').send({ modelVersion: 'v', insights: [] });
    expect(res.status).toBe(401);
  });

  it.each([
    ['thiếu modelVersion', { insights: [] }],
    ['ngày sai định dạng', { modelVersion: 'v', insights: [{ ...insight(), date: '10/11/2026' }] }],
    ['mã gợi ý lạ', { modelVersion: 'v', insights: [insight({ suggestions: [{ code: 'DROP TABLE', text: 'x' }] })] }],
    ['quá nhiều gợi ý', { modelVersion: 'v', insights: [insight({ suggestions: Array(6).fill({ code: 'who', text: 'x' }) })] }],
  ])('dữ liệu sai (%s) → 400', async (_n, body) => {
    expect((await put(body)).status).toBe(400);
  });

  it('ghi, chạy lại cùng ngày thì ghi đè; profile lạ bị bỏ qua', async () => {
    await put({ modelVersion: 'v1', insights: [insight()] });
    const res = await put({
      modelVersion: 'v2',
      insights: [insight({ habitSummary: 'dùng ít, ít game', suggestions: [] }), insight({ profileId: 999999999 })],
    });

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ saved: 1, unknownProfiles: 1 });
    const rows = await prisma.habitInsight.findMany({ where: { profileId } });
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ habitSummary: 'dùng ít, ít game', modelVersion: 'v2', suggestions: [] });
  });

  it('phụ huynh đọc bản mới nhất; hồ sơ người khác → 404', async () => {
    await put({ modelVersion: 'v', insights: [insight({ date: '2026-11-11', habitSummary: 'mới nhất' })] });

    const res = await get(profileId, parent);
    expect(res.status).toBe(200);
    expect(res.body.data.insight).toMatchObject({
      date: '2026-11-11', habitSummary: 'mới nhất', clusterId: 1, clusterCount: 3,
      suggestions: [{ code: 'gio_ngu', text: expect.stringContaining('nửa đêm') }],
    });
    expect((await get(profileId, stranger)).status).toBe(404);
  });

  it('chưa có kết quả → insight null', async () => {
    const other = await prisma.profile.create({ data: { userId: parent.id, profileName: 'Bé Mới' } });
    const res = await get(other.id, parent);
    expect(res.status).toBe(200);
    expect(res.body.data.insight).toBeNull();
  });
});
