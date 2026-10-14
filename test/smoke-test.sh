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

# $2 is the password variable, so both supported names get exercised.
start_server() {
  docker run -d --name "$1" \
    --mount "type=volume,src=$VOLUME,dst=/var/lib/opencode,volume-nocopy=true" \
    -e "$2=$PASSWORD" \
    -p "$PORT:4096" \
    "$IMAGE" >/dev/null
}

status() { curl -s --max-time 10 -o /dev/null -w '%{http_code}' "$@"; }

wait_healthy() {
  for _ in $(seq 60); do
    if curl -fsS --max-time 5 -o /dev/null -u "opencode:$PASSWORD" "http://127.0.0.1:$PORT/api/info" 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  return 1
}

echo "== boot with an empty root-owned volume (like Railway) =="
docker volume create "$VOLUME" >/dev/null
start_server "$C1" OPENCODE_PASSWORD
wait_healthy || fail "server did not become ready"
pass "server ready and the API accepts OPENCODE_PASSWORD"

echo "== auth =="
code="$(status "http://127.0.0.1:$PORT/api/info")"
[[ "$code" == "401" ]] || fail "expected 401 from the API without credentials, got $code"
pass "API rejects requests without credentials (401)"
code="$(status -u "opencode:wrong" "http://127.0.0.1:$PORT/api/info")"
[[ "$code" == "401" ]] || fail "expected 401 with wrong password, got $code"
pass "API rejects a wrong password (401)"
code="$(status "http://127.0.0.1:$PORT/")"
[[ "$code" == "200" ]] || fail "expected the web UI at / without credentials, got $code"
pass "web UI loads without credentials and signs in itself"

echo "== environment inside the container =="
version="$(docker exec "$C1" gosu opencode opencode --version)" || fail "opencode not runnable"
pass "$version"
for tool in node corepack python go bun pnpm uv gh railway rg jq; do
  docker exec "$C1" gosu opencode bash -c "command -v $tool" >/dev/null || fail "$tool missing"
done
pass "runtimes and CLIs resolve via mise shims"
docker exec "$C1" gosu opencode test -f /var/lib/opencode/workspace/AGENTS.md || fail "workspace AGENTS.md not seeded"
pass "workspace seeded with AGENTS.md"
# Skill discovery finishes shortly after the server is ready.
for _ in $(seq 30); do
  skills="$(curl -fsS --max-time 10 -u "opencode:$PASSWORD" "http://127.0.0.1:$PORT/api/skill?directory=/var/lib/opencode/workspace" || true)"
  [[ "$skills" == *'"id":"use-railway"'* ]] && break
  sleep 1
done
for skill in use-railway use-mise find-skills agent-browser skill-creator frontend-design; do
  [[ "$skills" == *"\"id\":\"$skill\""* ]] || fail "OpenCode did not load the baked skill $skill"
done
pass "OpenCode loads the baked skills"
owner="$(docker exec "$C1" stat -c '%U' /var/lib/opencode)"
[[ "$owner" == "opencode" ]] || fail "volume owned by $owner, expected opencode"
pass "volume ownership fixed to opencode user"

echo "== persistence across container replacement =="
docker exec "$C1" gosu opencode bash -c 'echo hello > /var/lib/opencode/workspace/persist-check.txt'
docker rm -f "$C1" >/dev/null
CURRENT="$C2"
start_server "$C2" OPENCODE_SERVER_PASSWORD
wait_healthy || fail "server did not come back up on the existing volume with OPENCODE_SERVER_PASSWORD"
docker exec "$C2" test -f /var/lib/opencode/workspace/persist-check.txt || fail "workspace file lost across containers"
pass "workspace survives container replacement"

echo "== no-password guard =="
CURRENT="$C3"
set +e
docker run --name "$C3" "$IMAGE" >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" == "1" ]] || fail "expected exit code 1 without a password, got $rc"
noauth_logs="$(docker logs "$C3" 2>&1)"
[[ "$noauth_logs" == *"OPENCODE_PASSWORD is not set"* ]] || fail "missing password error message"
pass "refuses to start without a password"

echo
echo "All smoke tests passed."
