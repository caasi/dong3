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
# outcomes: one field after reviewers and before end, whatever the input order; ids encoded
# as on reviewers; a malformed pair is skipped
: > "$tmp/l.log"
( cd "$repo" && REVIEW_LOOP_LOG_FILE="$tmp/l.log" bash "$LOG" review end=converged outcome=b/x:2+0+0+1 \
    run=x7k2p9 round=2 reviewer=a:3 outcome=a:1+1+1+0 reviewer=b/x:3 outcome=c: )
case "$(cat "$tmp/l.log")" in
  *"  round=2  reviewers=a:3,b%2Fx:3  outcomes=b%2Fx:2+0+0+1,a:1+1+1+0  end=converged") pass "outcomes" ;;
  *) fail "outcomes: [$(cat "$tmp/l.log")]" ;;
esac
# the five reviewers of the roster, two-digit counts: the line stays far below the bound
: > "$tmp/l.log"; args=()
for id in claude-opus-5-5 claude-sonnet-5-5 gpt-6-astra z-ai/glm-5.3 claude-fable-5-2; do
  args+=("reviewer=$id:12" "outcome=$id:10+1+1+0"); done
( cd "$repo" && REVIEW_LOOP_LOG_FILE="$tmp/l.log" bash "$LOG" review run=x7k2p9 round=12 "${args[@]}" end=converged )
n="$(wc -c < "$tmp/l.log")"
[ "$n" -gt 0 ] && [ "$n" -lt 512 ] && pass "five reviewers: $n bytes" || fail "five reviewers: $n bytes"
# a line over the bound keeps its reviewers= field: outcomes= is left out, not the line
: > "$tmp/l.log"; args=()
for i in $(seq 1 20); do id="claude-sonnet-5-5-$i"; args+=("reviewer=$id:12" "outcome=$id:10+1+1+0"); done
( cd "$repo" && REVIEW_LOOP_LOG_FILE="$tmp/l.log" bash "$LOG" review run=x7k2p9 round=3 "${args[@]}" end=converged )
line="$(cat "$tmp/l.log")"
case "$line" in
  *"  round=3  reviewers=claude-sonnet-5-5-1:12,"*",claude-sonnet-5-5-20:12  end=converged") pass "long line keeps reviewers" ;;
  *) fail "long line: [$line]" ;;
esac
echo ALL PASS
