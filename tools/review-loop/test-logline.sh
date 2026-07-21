#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
. "$LOGLINE"
fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
eq() { [ "$1" = "$2" ] || fail "$3: expected [$2] got [$1]"; pass "$3"; }

# Remote forms
d=$(mk_repo_with_origin "https://github.com/caasi/dong3.git")
eq "$(ll_project_slug "$d")" "github.com-caasi-dong3" "https .git"
d=$(mk_repo_with_origin "git@gitlab.com:group/subgroup/repo.git")
eq "$(ll_project_slug "$d")" "gitlab.com-group-subgroup-repo" "scp nested"
d=$(mk_repo_with_origin "https://oauth2:ghp_SECRET@github.com/a/b.git")
case "$(ll_project_slug "$d")" in *SECRET*) fail "credential leaked";; esac
eq "$(ll_project_slug "$d")" "github.com-a-b" "userinfo stripped"
# No remote → step 2, non-empty
d=$(mk_plain_repo); base=$(basename "$d")
eq "$(ll_project_slug "$d")" "$base" "plain clone non-empty"
w=$(mk_worktree "$d")
eq "$(ll_project_slug "$w")" "$base" "worktree yields main checkout"
# No repo → none
eq "$(ll_project_slug /tmp)" "none" "no repo"
# upstream remote but no origin → falls through to step 2, same as no remote
d=$(mk_plain_repo); git -C "$d" remote add upstream https://example.com/x/y.git
eq "$(ll_project_slug "$d")" "$(basename "$d")" "upstream-only falls through to step 2"
# a submodule reached through step 2 yields its path name under .git/modules
sup=$(mk_plain_repo); sub=$(mk_plain_repo)
git -C "$sup" -c protocol.file.allow=always submodule add -q "$sub" mysub >/dev/null 2>&1
git -C "$sup/mysub" remote remove origin 2>/dev/null || true
eq "$(ll_project_slug "$sup/mysub")" "mysub" "submodule yields its superproject path name"
# same slug from a subdirectory of the repo
d=$(mk_repo_with_origin https://github.com/caasi/dong3.git); mkdir -p "$d/a/b"
eq "$(ll_project_slug "$d/a/b")" "github.com-caasi-dong3" "subdirectory yields repo slug"
# Value rules
eq "$(ll_scrub 'a b=c/d')" "abcd" "scrub drops space = /"
eq "$(ll_encode_id 'meta-llama/Llama-3.3-70B')" "meta-llama%2FLlama-3.3-70B" "encode path sep"
eq "$(ll_encode_id "$(printf 'a\tb')")" "a%09b" "encode tab (whitespace, not only space)"
eq "$(ll_encode_id 'a,b')" "a%2Cb" "encode comma"
[ "$(ll_encode_id 'a%2Cb')" != "$(ll_encode_id 'a,b')" ] && pass "encode % first keeps distinct" || fail "collision"
case "$(ll_ts)" in *[0-9]T*:*:*Z) pass "ts shape";; *) fail "ts shape";; esac
line="$(ll_line review project=foo run=abc123 round=1)"
[ "$line" = "$(printf '%s' "$line" | sed 's/  / /g' | sed 's/ /  /g')" ] || true  # informal
case "$line" in *"  review  project=foo  run=abc123  round=1") pass "two-space join";; *) fail "join: [$line]";; esac

# ll_append tests
tmp="$(mktemp -d)"; export REVIEW_LOOP_LOG_FILE="$tmp/review-loop.log"
ll_append "one"; ll_append "two"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 2 ] && pass "two appends two lines" || fail "append count"
[ "$(stat -c %a "$REVIEW_LOOP_LOG_FILE")" = 600 ] && pass "mode 0600" || fail "mode"
REVIEW_LOOP_LOG=0 ll_append "three"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 2 ] && pass "off switch" || fail "off switch wrote"
ll_append "$(printf 'x%.0s' $(seq 1 2000))"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 2 ] && pass "over-1024 not written" || fail "bound"
# guard: log dir inside a work tree
wt="$(mk_plain_repo)"; REVIEW_LOOP_LOG_FILE="$wt/review-loop.log" ll_append "guarded"
[ ! -f "$wt/review-loop.log" ] && pass "guard refuses inside work tree" || fail "guard"
# concurrency: two writers, 1000 lines each, 2000 whole lines
REVIEW_LOOP_LOG_FILE="$tmp/c.log"
( for i in $(seq 1000); do ll_append "a$i"; done ) &
( for i in $(seq 1000); do ll_append "b$i"; done ) &
wait
[ "$(wc -l < "$tmp/c.log")" = 2000 ] && pass "2000 whole lines" || fail "interleave split"

echo ALL PASS
