#!/usr/bin/env bash
# Usage: TOKEN=<id-token, optional> check-ready.sh <base-url> <ready-path> <expected-version>
# Passes only if <base-url><ready-path> returns HTTP 200 with the exact body {"status":"ok"}
# and <base-url>/ reports the expected version. Retries to allow for instance start-up.
set -euo pipefail

base="${1:?base url}"
path="${2:?ready path}"
version="${3:?expected version}"
auth=()
if [ -n "${TOKEN:-}" ]; then auth=(-H "Authorization: Bearer ${TOKEN}"); fi

body="$(mktemp)"
trap 'rm -f "$body"' EXIT

for i in 1 2 3 4 5 6; do
  code="$(curl -s -o "$body" -w '%{http_code}' ${auth[@]+"${auth[@]}"} "${base}${path}" || true)"
  if [ "$code" = 200 ] && [ "$(cat "$body")" = '{"status":"ok"}' ]; then
    echo "ready ok at ${base}${path}"
    if curl -sf ${auth[@]+"${auth[@]}"} "${base}/" | grep -q "\"version\":\"${version}\""; then
      echo "version ${version} confirmed"
      exit 0
    fi
    echo "version mismatch (expected ${version})" >&2
    exit 1
  fi
  echo "attempt ${i}: status=${code} body=$(head -c 80 "$body")" >&2
  sleep "${CHECK_READY_SLEEP:-5}"
done
echo "readiness check failed" >&2
exit 1
