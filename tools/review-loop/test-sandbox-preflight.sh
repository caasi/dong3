#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="$SCRIPT_DIR/../../plugins/review-loop/skills/review-loop/scripts/sandbox-preflight.sh"
BASH_BIN="$(command -v bash)"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/review-loop-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

make_stub() { # $1=dir name, $2=exit code, $3=stderr line
  mkdir -p "$tmp/$1"
  cat >"$tmp/$1/bwrap" <<EOF
#!/usr/bin/env bash
echo "$3" >&2
exit $2
EOF
  chmod +x "$tmp/$1/bwrap"
}

make_stub usable 0 ""
make_stub broken 1 "bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted"
make_stub other  1 "bwrap: something unrelated went wrong"
make_stub noctx  1 "some-tool: Operation not permitted"   # EPERM but no bwrap: context

run() { # $1=PATH to use ; prints "<stdout> <exit>"
  local out rc=0
  out="$(PATH="$1" "$BASH_BIN" "$PREFLIGHT" 2>/dev/null)" || rc=$?
  printf '%s %s' "$out" "$rc"
}

echo "Test 1: usable sandbox -> usable/0"
[ "$(run "$tmp/usable:$PATH")" = "usable 0" ] || fail "expected 'usable 0'"
pass "usable"

echo "Test 2: broken sandbox (EPERM) -> broken/1"
[ "$(run "$tmp/broken:$PATH")" = "broken 1" ] || fail "expected 'broken 1'"
pass "broken"

echo "Test 3: bwrap absent -> unknown/2"
[ "$(run "/nonexistent-preflight-dir")" = "unknown 2" ] || fail "expected 'unknown 2'"
pass "absent"

echo "Test 4: non-EPERM failure -> unknown/2"
[ "$(run "$tmp/other:$PATH")" = "unknown 2" ] || fail "expected 'unknown 2'"
pass "non-EPERM"

echo "Test 5: EPERM without a bwrap: setup line -> unknown/2"
[ "$(run "$tmp/noctx:$PATH")" = "unknown 2" ] || fail "expected 'unknown 2'"
pass "EPERM-without-bwrap-context"

echo "All sandbox-preflight tests passed."
