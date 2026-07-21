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
# a token that itself contains an unencoded @ must not leave a fragment (spec 79-82)
d=$(mk_repo_with_origin "https://oauth2:my@tok@github.com/a/b.git")
eq "$(ll_project_slug "$d")" "github.com-a-b" "multi-@ userinfo fully stripped"
case "$(ll_project_slug "$d")" in *tok*) fail "multi-@ credential fragment leaked";; esac
# a ?query (which can carry a token) is dropped before slugging
d=$(mk_repo_with_origin "https://github.com/a/b.git?access_token=SECRET")
eq "$(ll_project_slug "$d")" "github.com-a-b" "query dropped before slug"
case "$(ll_project_slug "$d")" in *SECRET*) fail "query token leaked";; esac
# an @ that legitimately appears in the PATH is preserved, not treated as userinfo
d=$(mk_repo_with_origin "https://github.com/@scope/b.git")
eq "$(ll_project_slug "$d")" "github.com-@scope-b" "path @ preserved, host kept"
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
case "$line" in *"  review  project=foo  run=abc123  round=1") pass "two-space join";; *) fail "join: [$line]";; esac

# ll_append tests
tmp="$(mktemp -d)"; export REVIEW_LOOP_LOG_FILE="$tmp/review-loop.log"
ll_append "one"; ll_append "two"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 2 ] && pass "two appends two lines" || fail "append count"
[ "$(file_mode "$REVIEW_LOOP_LOG_FILE")" = 600 ] && pass "mode 0600" || fail "mode"
REVIEW_LOOP_LOG=0 ll_append "three"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 2 ] && pass "off switch" || fail "off switch wrote"
ll_append "$(printf 'x%.0s' $(seq 1 2000))"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 2 ] && pass "over-1024 not written" || fail "bound"
# Boundary edge cases: exactly 1024 on-disk (1023 content + newline) and exactly 1025 (1024 content + newline)
ll_append "$(printf 'x%.0s' $(seq 1 1023))"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 3 ] && pass "1023-byte content (1024 on-disk) written" || fail "1023-byte edge"
ll_append "$(printf 'x%.0s' $(seq 1 1024))"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 3 ] && pass "1024-byte content (1025 on-disk) not written" || fail "1024-byte edge"
# guard: log dir inside a work tree
wt="$(mk_plain_repo)"; REVIEW_LOOP_LOG_FILE="$wt/review-loop.log" ll_append "guarded"
[ ! -f "$wt/review-loop.log" ] && pass "guard refuses inside work tree" || fail "guard"
# guard still fires when the log dir does NOT exist yet but an ancestor is a work tree
wt="$(mk_plain_repo)"; REVIEW_LOOP_LOG_FILE="$wt/nested/deep/review-loop.log" ll_append "guarded"
[ ! -f "$wt/nested/deep/review-loop.log" ] && pass "guard refuses via nearest existing ancestor" || fail "guard bypassed on missing dir"
# concurrency: two writers, 1000 lines each, 2000 whole lines
REVIEW_LOOP_LOG_FILE="$tmp/c.log"
( for i in $(seq 1000); do ll_append "a$i"; done ) &
( for i in $(seq 1000); do ll_append "b$i"; done ) &
wait
[ "$(wc -l < "$tmp/c.log")" = 2000 ] && pass "2000 whole lines" || fail "interleave split"

# an existing log with a looser mode is tightened to 0600 on append (privacy: spec requires 0600)
ex="$(mktemp -d)/l.log"; touch "$ex"; chmod 644 "$ex"
REVIEW_LOOP_LOG_FILE="$ex" ll_append "tighten"
[ "$(file_mode "$ex")" = 600 ] && pass "existing looser-mode log tightened to 0600" || fail "0600 not enforced on existing file"
# a missing nested dir under a NON-repo ancestor is created and written (guard does not over-refuse)
nd="$(mktemp -d)"   # mktemp -d is not a git repo
REVIEW_LOOP_LOG_FILE="$nd/sub/deep/l.log" ll_append "ok"
[ -s "$nd/sub/deep/l.log" ] && pass "missing dir under non-repo ancestor is written" || fail "over-refused a non-repo missing dir"
# refuse a non-regular target: a directory at the log path is never written into
nr="$(mktemp -d)/asdir"; mkdir -p "$nr"
REVIEW_LOOP_LOG_FILE="$nr" ll_append "x"
[ -z "$(ls -A "$nr" 2>/dev/null)" ] && pass "non-regular (directory) target refused" || fail "wrote into a directory target"
# refuse a symlink target: chmod must not follow it and re-permission or overwrite the victim
victim="$(mktemp -d)/victim"; printf 'keep' > "$victim"; chmod 644 "$victim"
sl="$(mktemp -d)/link"; ln -s "$victim" "$sl"
REVIEW_LOOP_LOG_FILE="$sl" ll_append "x"
{ [ "$(file_mode "$victim")" = 644 ] && [ "$(cat "$victim")" = keep ]; } && pass "symlink target not followed" || fail "symlink target chmodded or written"
# refuse an existing file with more than one hard link (its inode may be visible in a work tree)
hl="$(mktemp -d)"; printf '' > "$hl/a"; ln "$hl/a" "$hl/b"   # a and b share one inode, link count 2
REVIEW_LOOP_LOG_FILE="$hl/a" ll_append "x"
[ "$(wc -c < "$hl/a")" = 0 ] && pass "multi-hard-link target refused" || fail "wrote to a hard-linked file"

echo ALL PASS
