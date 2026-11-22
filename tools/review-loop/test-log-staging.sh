#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2015  # lib.bash is sourced by path; pass() never fails, so A && pass || fail is safe
# Record first, ask at the hand-off: log.sh stages a run's lines, then keep, discard or sweep.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
LOG="$LIBDIR/../../plugins/review-loop/skills/review-loop/scripts/log.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }; pass() { echo "PASS: $*"; }
eq() { [ "$1" = "$2" ] || fail "$3: expected [$2] got [$1]"; pass "$3"; }

repo="$(mk_repo_with_origin https://github.com/caasi/dong3.git)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp" "$repo"' EXIT
export REVIEW_LOOP_LOG_FILE="$tmp/l.log" REVIEW_LOOP_USAGE_FILE="$tmp/u.tsv" \
  REVIEW_LOOP_USAGE_PENDING="$tmp/pending" REVIEW_LOOP_STAGING="$tmp/staging"
S="$tmp/staging"
lines() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
rv() { ( cd "$repo" && bash "$LOG" review "$@" ); }
us() { ( cd "$repo" && bash "$LOG" usage "$@" ); }

# During the run, nothing reaches the main files.
rv run=aaa111 round=1 reviewer=m:2 outcome=m:1+1+0+0
us run=aaa111 round=1 reviewer=codex model=gpt-6-sol output=5 cost=0.01 cost_source=provider-api
eq "$(lines "$tmp/l.log")" 0 "round line staged, not in the round log"
eq "$(lines "$tmp/u.tsv")" 0 "usage row staged, not in the usage file"
eq "$(lines "$S/aaa111/log")" 1 "staged round line"
eq "$(lines "$S/aaa111/usage")" 1 "staged usage row, no header"

# keep: the lines go to the main files, the usage file gets its header, the staging dir goes.
bash "$LOG" keep run=aaa111
case "$(cat "$tmp/l.log")" in *"  run=aaa111  round=1  reviewers=m:2  outcomes=m:1+1+0+0") pass "kept round line" ;;
  *) fail "kept round line: [$(cat "$tmp/l.log")]" ;; esac
eq "$(lines "$tmp/u.tsv")" 2 "usage header and row"
eq "$(sed -n 1p "$tmp/u.tsv" | cut -f1)" "date" "usage header first"
[ ! -e "$S/aaa111" ] && pass "staging dir removed" || fail "staging dir left"
bash "$LOG" keep run=aaa111
eq "$(lines "$tmp/l.log")" 1 "a second keep writes nothing"

# discard: nothing reaches the main files; the run's pending ids go, another run's stay.
: > "$tmp/l.log"
mkdir -p "$tmp/pending"
printf 'x\n' > "$tmp/pending/bbb222-1-pi.jsonl"; printf 'x\n' > "$tmp/pending/ccc333-1-pi.jsonl"
rv run=bbb222 round=1 reviewer=m:0 end=converged
bash "$LOG" discard run=bbb222
eq "$(lines "$tmp/l.log")" 0 "discarded line not in the round log"
[ ! -e "$S/bbb222" ] && pass "discard removes the staging dir" || fail "discard left the staging dir"
[ ! -e "$tmp/pending/bbb222-1-pi.jsonl" ] && pass "discard removes the run's pending ids" || fail "pending ids left"
[ -e "$tmp/pending/ccc333-1-pi.jsonl" ] && pass "another run's pending ids stay" || fail "other pending removed"

# Two keeps at the same time: each line reaches the round log once.
bad=0
for t in $(seq 1 30); do
  : > "$tmp/l.log"
  for r in 1 2 3 4 5; do rv run="race$t" round="$r" reviewer=m:1; done
  bash "$LOG" keep run="race$t" & bash "$LOG" keep run="race$t" & wait
  [ "$(lines "$tmp/l.log")" = 5 ] || bad=$((bad + 1))
done
eq "$bad" 0 "concurrent keeps write each line once (30 trials)"

# sweep: a staging dir untouched for 24 hours is kept; a fresh one stays; an old claim goes.
: > "$tmp/l.log"
rv run=old444 round=1 reviewer=m:1
rv run=new555 round=1 reviewer=m:1
touch -t 202001010000 "$S/old444/log" "$S/old444"
mkdir -p "$S/hhh000"   # made by a writer that has not written its first line yet
# The age of a claim is in its name. A renamed old run keeps the old mtime of its directory, and
# is still a claim being read: the mtime must not make it look old.
now="$(date +%s)"
mkdir -p "$S/.claim-ddd666-$((now - 8 * 86400))-1-1" "$S/.claim-ggg999-$now-1-1"
touch -t 202001010000 "$S/.claim-ggg999-$now-1-1"
bash "$LOG" sweep
eq "$(grep -c 'run=old444' "$tmp/l.log")" 1 "sweep keeps a stale run"
eq "$(grep -c 'run=new555' "$tmp/l.log" || true)" 0 "sweep leaves a fresh run"
[ -e "$S/new555/log" ] && pass "fresh staging dir stays" || fail "fresh staging dir gone"
[ -d "$S/hhh000" ] && pass "a new empty staging dir stays" || fail "new empty staging dir taken"
[ ! -e "$S/.claim-ddd666-$((now - 8 * 86400))-1-1" ] && pass "sweep removes a claim made 8 days ago" || fail "old claim left"
[ -e "$S/.claim-ggg999-$now-1-1" ] && pass "sweep keeps a new claim with an old mtime" || fail "new claim removed"

# A run token that is not a plain name is not a path: the line goes straight to the round log.
: > "$tmp/l.log"
rv run=../up round=1 reviewer=m:1
eq "$(lines "$tmp/l.log")" 1 "odd run token writes straight to the round log"
rv run=kkk-1 round=1 reviewer=m:1
eq "$(lines "$tmp/l.log")" 2 "a run token with '-' is not staged"
[ ! -e "$tmp/up" ] && [ ! -e "$tmp/..up" ] && pass "no dir outside staging" || fail "dir made outside staging"

# The off switch writes nothing anywhere.
REVIEW_LOOP_LOG=0 bash -c "cd '$repo' && bash '$LOG' review run=eee777 round=1 reviewer=m:1"
[ ! -e "$S/eee777" ] && pass "off switch stages nothing" || fail "off switch staged"

# A dir with any other file is not staging: keep leaves it, also for a name that starts with "..".
for x in notes .hidden ..x; do
  rv run=jjj111 round=1 reviewer=m:1; printf 'mine\n' > "$S/jjj111/$x"
  bash "$LOG" keep run=jjj111
  [ -f "$S/jjj111/$x" ] && [ -f "$S/jjj111/log" ] && pass "keep leaves a dir that holds $x" || fail "keep took a dir that holds $x"
  rm -f -- "$S/jjj111/$x" "$S/jjj111/log"; rmdir -- "$S/jjj111"
done

# With the off switch, keep and discard leave the staged lines alone.
rv run=iii111 round=1 reviewer=m:1
REVIEW_LOOP_LOG=0 bash "$LOG" keep run=iii111
REVIEW_LOOP_LOG=0 bash "$LOG" discard run=iii111
[ -s "$S/iii111/log" ] && pass "off switch: keep and discard leave the staging dir" || fail "off switch removed staged lines"

# Unset, REVIEW_LOOP_STAGING defaults to ~/.claude/review-loop-staging (set but empty is different).
mkdir -p "$tmp/home"
env -u REVIEW_LOOP_STAGING HOME="$tmp/home" bash -c "cd '$repo' && bash '$LOG' review run=lll111 round=1 reviewer=m:1"
[ -s "$tmp/home/.claude/review-loop-staging/lll111/log" ] && pass "unset REVIEW_LOOP_STAGING stages under ~/.claude" || fail "default staging dir not used"

# An empty REVIEW_LOOP_STAGING writes straight to the files.
: > "$tmp/l.log"
REVIEW_LOOP_STAGING='' bash -c "cd '$repo' && bash '$LOG' review run=fff888 round=1 reviewer=m:1"
eq "$(lines "$tmp/l.log")" 1 "empty REVIEW_LOOP_STAGING writes straight to the round log"

echo ALL PASS
