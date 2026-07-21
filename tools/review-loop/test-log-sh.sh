#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
LOG="$LIBDIR/../../plugins/review-loop/skills/review-loop/scripts/log.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }; pass() { echo "PASS: $*"; }

tok="$(bash "$LOG" new-run)"
[ "${#tok}" = 6 ] && pass "6 chars" || fail "len [$tok]"
case "$tok" in *[!a-z0-9]*) fail "charset [$tok]";; *) pass "lowercase alnum";; esac
[ "$(bash "$LOG" new-run)" != "$(bash "$LOG" new-run)" ] && pass "differ" || fail "same token"

repo="$(mk_repo_with_origin https://github.com/caasi/dong3.git)"
tmp="$(mktemp -d)"; export REVIEW_LOOP_LOG_FILE="$tmp/l.log"
( cd "$repo" && REVIEW_LOOP_LOG_FILE="$tmp/l.log" bash "$LOG" review run=x7k2p9 round=1 reviewer=claude-opus-4-8:19 reviewer=gpt-5.5:5 )
line="$(cat "$tmp/l.log")"
case "$line" in
  *"  review  project=github.com-caasi-dong3  run=x7k2p9  round=1  reviewers=claude-opus-4-8:19,gpt-5.5:5") pass "review line" ;;
  *) fail "review line: [$line]" ;;
esac
# stop line: no round, no reviewers, end last
: > "$tmp/l.log"
( cd "$repo" && REVIEW_LOOP_LOG_FILE="$tmp/l.log" bash "$LOG" review run=x7k2p9 end=stopped )
case "$(cat "$tmp/l.log")" in
  *"  review  project=github.com-caasi-dong3  run=x7k2p9  end=stopped") pass "stop line" ;;
  *) fail "stop line: [$(cat "$tmp/l.log")]" ;;
esac
echo ALL PASS
