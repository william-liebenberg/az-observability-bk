#!/usr/bin/env bash
set -euo pipefail

url="${1:?Usage: smoke-test.sh <url>}"
attempts="${SMOKE_ATTEMPTS:-20}"
delay="${SMOKE_DELAY_SECONDS:-5}"
body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT

for ((attempt = 1; attempt <= attempts; attempt++)); do
  echo "Smoke test attempt ${attempt}/${attempts} for ${url}"
  status="$(curl --silent --show-error --output "$body_file" \
    --write-out '%{http_code}' --max-time 10 "$url" || true)"
  if [[ "$status" == "200" ]]; then
    cat "$body_file"
    echo "✅ Smoke test succeeded after ${attempt} attempts"
    exit 0
  fi

  echo "Smoke attempt ${attempt}/${attempts} returned HTTP ${status:-none}" >&2
  sleep "$delay"
done

echo "Smoke test failed after ${attempts} attempts" >&2
cat "$body_file" >&2
exit 1
