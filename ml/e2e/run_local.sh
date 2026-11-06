#!/usr/bin/env bash
# Kiểm thử đầu cuối tác vụ ban đêm (T7.3.4) trên DB test cục bộ — KHÔNG đụng production.
#
#   mô phỏng 3 trẻ → seed vào DB test → bật backend local → jobs.nightly --push (2 lần) → kiểm tra DB → dọn
#
# Chạy từ gốc repo:  bash ml/e2e/run_local.sh
# Cần: backend/.env.test trỏ vào Postgres local (schema đã `prisma db push`), ml/.venv đã cài requirements.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${E2E_PORT:-5055}"
SECRET="e2e-$(date +%s)"
WORK="$(mktemp -d)"
SIM="$WORK/sim.json"
LOG="$WORK/backend.log"
BACKEND_PID=""

cleanup() {
  [ -n "$BACKEND_PID" ] && kill "$BACKEND_PID" 2>/dev/null || true
  (cd "$ROOT/backend" && node scripts/thesis-e2e.js cleanup) || true
  rm -rf "$WORK"
}
trap cleanup EXIT

if ! grep -q '^DATABASE_URL=' "$ROOT/backend/.env.test" || grep -qi '^DATABASE_URL=.*supabase' "$ROOT/backend/.env.test"; then
  echo "backend/.env.test thiếu hoặc trỏ vào Supabase — dừng." >&2
  exit 2
fi

echo "== 1. Mô phỏng 3 trẻ"
(cd "$ROOT/ml" && .venv/bin/python -m e2e.export_sim "$SIM")

echo "== 2. Seed vào DB test"
(cd "$ROOT/backend" && node scripts/thesis-e2e.js seed "$SIM")

echo "== 3. Bật backend local :$PORT (env từ .env.test, nạp TRƯỚC .env nên không bị ghi đè)"
(cd "$ROOT/backend" && NODE_ENV=e2e PORT="$PORT" HOST=127.0.0.1 CRON_SECRET="$SECRET" \
  exec node -r dotenv/config src/server.js dotenv_config_path=.env.test >"$LOG" 2>&1) &
BACKEND_PID=$!
up() { curl -sf -o /dev/null "http://127.0.0.1:$PORT/api/cron/thesis-data?limit=1" -H "Authorization: Bearer $SECRET"; }
for _ in $(seq 1 30); do up && break; sleep 1; done
if ! up; then
  echo "Backend không lên được:" >&2; tail -30 "$LOG" >&2; exit 1
fi

run_nightly() {
  (cd "$ROOT/ml" && CRON_SECRET="$SECRET" .venv/bin/python -m jobs.nightly --url "http://127.0.0.1:$PORT" --push) || true
}

echo "== 4. Tác vụ ban đêm — lần 1"
run_nightly
echo "== 5. Tác vụ ban đêm — lần 2 (chạy lại phải ghi đè dự đoán, không tạo cảnh báo trùng)"
run_nightly

echo "== 6. Kiểm tra DB"
(cd "$ROOT/backend" && node scripts/thesis-e2e.js verify "$SIM")
