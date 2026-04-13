#!/bin/bash
URL="https://kidfun-backend-production.up.railway.app"

function test_api() {
  echo "$1"
  shift
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "$@"
}

echo "=== TC-22.1: GET /api/profiles/:id/location/current (no auth) ==="
test_api "Expected: 401" -X GET "${URL}/api/profiles/1/location/current"

echo "=== TC-22.2: POST /api/profiles/:id/geofences (no auth) ==="
test_api "Expected: 401" -X POST "${URL}/api/profiles/1/geofences"

echo "=== TC-23.1: POST /api/child/location (INVALID_CODE) ==="
test_api "Expected: 404" -X POST "${URL}/api/child/location" -H "Content-Type: application/json" -d '{"deviceCode": "INVALID_CODE_XYZ", "latitude": 10.0, "longitude": 106.0}'

echo "=== TC-23.2: POST /api/child/sos (INVALID_CODE) ==="
test_api "Expected: 404" -X POST "${URL}/api/child/sos" -F "deviceCode=INVALID_CODE_XYZ"

echo "=== TC-24.1: POST /api/child/sos (Upload .jpg to audio) ==="
touch dummy.jpg
test_api "Expected: 400" -X POST "${URL}/api/child/sos" -F "deviceCode=INVALID_CODE_XYZ" -F "audio=@dummy.jpg"

echo "=== TC-24.2: POST /api/child/sos (Upload >5MB) ==="
dd if=/dev/zero of=large.m4a bs=1M count=6 2>/dev/null
test_api "Expected: 400" -X POST "${URL}/api/child/sos" -F "deviceCode=INVALID_CODE_XYZ" -F "audio=@large.m4a"

rm dummy.jpg large.m4a
