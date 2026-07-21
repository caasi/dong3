#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
LOG="$LIBDIR/../../plugins/review-loop/skills/review-loop/scripts/log.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }; pass() { echo "PASS: $*"; }
repo="$(mk_repo_with_origin https://github.com/caasi/dong3.git)"; tmp="$(mktemp -d)"
export REVIEW_LOOP_LOG_FILE="$tmp/f.log"
( cd "$repo" && bash "$LOG" review run=x7k2p9 round=1 reviewer=a:1 )
( cd "$repo" && bash "$LOG" review run=x7k2p9 round=18 reviewer=a:1 )
grep -Eq ' {3,}' "$REVIEW_LOOP_LOG_FILE" && fail "padding: 3+ spaces present" || pass "exactly two spaces, no padding"
# UTC sortability: string sort == chronological (single host proxy: lines already in order)
LC_ALL=C sort -c "$REVIEW_LOOP_LOG_FILE" && pass "byte-sorts chronologically" || fail "not sortable"
# spec says plain string comparison = C/byte order; UTF-8 collation folds the separator spaces
# key order on a review line
head -1 "$REVIEW_LOOP_LOG_FILE" | grep -Eq '  review  project=[^ ]+  run=[^ ]+  round=' || fail "key order"
pass "key order"
# percent-encoding of a reviewer id reaches the log through log.sh, not just the unit
( cd "$repo" && bash "$LOG" review run=x7k2p9 round=2 reviewer=meta-llama/Llama-3.3-70B:3 )
grep -q 'reviewers=meta-llama%2FLlama-3.3-70B:3' "$REVIEW_LOOP_LOG_FILE" \
  && pass "reviewer id encoded on the writer path" || fail "id not encoded end to end"
# a line over 1024 bytes is not written
before=$(wc -l < "$REVIEW_LOOP_LOG_FILE")
( cd "$repo" && bash "$LOG" review run=x7k2p9 round=3 "reviewer=$(printf 'x%.0s' $(seq 1 1100)):1" )
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = "$before" ] && pass "over-1024 line refused" || fail "bound not enforced"
echo ALL PASS
