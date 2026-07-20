#!/usr/bin/env bash
# Smoke test for the railway-opencode image.
#
#   ./test/smoke-test.sh [image]         (default: railway-opencode:test)
#
# Boots the image the way Railway does (empty root-owned volume), verifies
# auth, the seeded workspace, baked skills and tools, persistence across a
# container replacement, and the no-password guard. CI runs this before any
# image is published.
set -euo pipefail

IMAGE="${1:-railway-opencode:test}"
RUN_ID="opencode-smoke-$$"
C1="$RUN_ID-1"
C2="$RUN_ID-2"
C3="$RUN_ID-noauth"
VOLUME="$RUN_ID-vol"
PASSWORD="smoke-test-password"
PORT=14096
CURRENT="$C1"

cleanup() {
  docker rm -f "$C1" "$C2" "$C3" >/dev/null 2>&1 || true
  docker volume rm "$VOLUME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  docker logs "$CURRENT" 2>&1 | tail -40 >&2 || true
  exit 1
}
pass() { echo "  ok: $*"; }

start_server() {
  docker run -d --name "$1" \
    --mount "type=volume,src=$VOLUME,dst=/var/lib/opencode,volume-nocopy=true" \
    -e OPENCODE_SERVER_PASSWORD="$PASSWORD" \
    -p "$PORT:4096" \
    "$IMAGE" >/dev/null
}

wait_healthy() {
  for _ in $(seq 60); do
    if curl -fsS --max-time 5 -o /dev/null -u "opencode:$PASSWORD" "http://127.0.0.1:$PORT/app" 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  return 1
}

echo "== boot with an empty root-owned volume (like Railway) =="
docker volume create "$VOLUME" >/dev/null
start_server "$C1"
wait_healthy || fail "server did not become healthy"
pass "server up and authenticated requests succeed"

echo "== auth =="
code="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/app")"
[[ "$code" == "401" ]] || fail "expected 401 without credentials, got $code"
pass "unauthenticated requests are rejected (401)"
code="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' -u "opencode:wrong" "http://127.0.0.1:$PORT/app")"
[[ "$code" == "401" ]] || fail "expected 401 with wrong password, got $code"
pass "wrong password rejected (401)"

echo "== environment inside the container =="
version="$(docker exec "$C1" gosu opencode opencode --version)" || fail "opencode not runnable"
pass "opencode $version"
for tool in node python go bun pnpm uv gh railway rg jq; do
  docker exec "$C1" gosu opencode bash -c "command -v $tool" >/dev/null || fail "$tool missing"
done
pass "runtimes and CLIs resolve via mise shims"
docker exec "$C1" gosu opencode test -f /var/lib/opencode/workspace/AGENTS.md || fail "workspace AGENTS.md not seeded"
pass "workspace seeded with AGENTS.md"
for skill in use-railway use-mise find-skills agent-browser skill-creator frontend-design; do
  docker exec "$C1" test -f "/opt/opencode/skills/$skill/SKILL.md" || fail "baked skill $skill missing"
done
pass "baked skills present"
owner="$(docker exec "$C1" stat -c '%U' /var/lib/opencode)"
[[ "$owner" == "opencode" ]] || fail "volume owned by $owner, expected opencode"
pass "volume ownership fixed to opencode user"

echo "== persistence across container replacement =="
docker exec "$C1" gosu opencode bash -c 'echo hello > /var/lib/opencode/workspace/persist-check.txt'
docker rm -f "$C1" >/dev/null
CURRENT="$C2"
start_server "$C2"
wait_healthy || fail "server did not come back up on the existing volume"
docker exec "$C2" test -f /var/lib/opencode/workspace/persist-check.txt || fail "workspace file lost across containers"
pass "workspace survives container replacement"

echo "== no-password guard =="
CURRENT="$C3"
set +e
docker run --name "$C3" "$IMAGE" >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" == "1" ]] || fail "expected exit code 1 without OPENCODE_SERVER_PASSWORD, got $rc"
noauth_logs="$(docker logs "$C3" 2>&1)"
[[ "$noauth_logs" == *"OPENCODE_SERVER_PASSWORD is not set"* ]] || fail "missing password error message"
pass "refuses to start without a password"

echo
echo "All smoke tests passed."
