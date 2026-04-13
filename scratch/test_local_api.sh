#!/bin/bash
URL="http://localhost:3000"

function test_api() {
  echo "$1"
  shift
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "$@"
}

echo "=== TC-24.1: POST /api/child/sos (Upload .jpg to audio) ==="
touch dummy.jpg
test_api "Expected: 400" -X POST "${URL}/api/child/sos" -F "deviceCode=INVALID_CODE_XYZ" -F "audio=@dummy.jpg"

echo "=== TC-24.2: POST /api/child/sos (Upload >5MB) ==="
dd if=/dev/zero of=large.m4a bs=1M count=6 2>/dev/null
test_api "Expected: 400" -X POST "${URL}/api/child/sos" -F "deviceCode=INVALID_CODE_XYZ" -F "audio=@large.m4a"

rm dummy.jpg large.m4a
