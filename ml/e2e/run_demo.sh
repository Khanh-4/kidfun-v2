#!/usr/bin/env bash
# Tài khoản demo buổi bảo vệ (T9.3.2) trên DB test cục bộ — KHÔNG đụng production.
#
#   mô phỏng 28 ngày (2 bé demo + 6 bé nền) → seed vào DB test → bật backend local (0.0.0.0) → jobs.nightly --push
#   → GIỮ backend chạy cho app phụ huynh kết nối; Ctrl+C để tắt (dữ liệu demo vẫn giữ trong DB test).
#
# Chạy từ gốc repo:   bash ml/e2e/run_demo.sh            (thêm --cleanup để xoá dữ liệu demo rồi thoát)
# Cần: backend/.env.test trỏ vào Postgres local (schema đã `prisma db push`), ml/.venv đã cài requirements.
# App phụ huynh: build với --dart-define=API_BASE_URL=http://<IP-laptop>:<PORT> — xem docs/thesis/demo-bao-ve.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${DEMO_PORT:-3001}"
SECRET="demo-$(date +%s)"
WORK="$(mktemp -d)"
DEMO="$WORK/demo.json"
BACKEND_PID=""

stop() {
  [ -n "$BACKEND_PID" ] && kill "$BACKEND_PID" 2>/dev/null || true
  rm -rf "$WORK"
}
trap stop EXIT

if ! grep -q '^DATABASE_URL=' "$ROOT/backend/.env.test" || grep -qi '^DATABASE_URL=.*supabase' "$ROOT/backend/.env.test"; then
  echo "backend/.env.test thiếu hoặc trỏ vào Supabase — dừng." >&2
  exit 2
fi

if [ "${1:-}" = "--cleanup" ]; then
  (cd "$ROOT/backend" && node scripts/thesis-demo.js cleanup)
  exit 0
fi

echo "== 1. Mô phỏng 28 ngày (2 bé demo + 6 bé nền)"
(cd "$ROOT/ml" && .venv/bin/python -m e2e.export_demo "$DEMO")

echo "== 2. Seed vào DB test"
(cd "$ROOT/backend" && node scripts/thesis-demo.js seed "$DEMO")

echo "== 3. Bật backend local 0.0.0.0:$PORT (env từ .env.test)"
(cd "$ROOT/backend" && NODE_ENV=demo PORT="$PORT" HOST=0.0.0.0 CRON_SECRET="$SECRET" \
  exec node -r dotenv/config src/server.js dotenv_config_path=.env.test) &
BACKEND_PID=$!
up() { curl -sf -o /dev/null "http://127.0.0.1:$PORT/api/cron/thesis-data?limit=1" -H "Authorization: Bearer $SECRET"; }
for _ in $(seq 1 30); do up && break; sleep 1; done
up || { echo "Backend không lên được." >&2; exit 1; }

echo "== 4. Tác vụ ban đêm (baseline, dự đoán M1, cảnh báo M2, thói quen M3/M4)"
(cd "$ROOT/ml" && CRON_SECRET="$SECRET" .venv/bin/python -m jobs.nightly --url "http://127.0.0.1:$PORT" --push)

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
cat <<MSG

== Sẵn sàng. Backend demo: http://${IP:-<IP-laptop>}:$PORT  (Ctrl+C để tắt)
   Đăng nhập: ${DEMO_EMAIL:-demo.baove@kidfun.test} / ${DEMO_PASSWORD:-demo1234}
   WSL2: điện thoại không thấy IP WSL — xem mục "Mạng" trong docs/thesis/demo-bao-ve.md.
MSG
wait "$BACKEND_PID"
