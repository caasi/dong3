#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
HOOK="$LIBDIR/../../plugins/review-loop/hooks/object.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }; pass() { echo "PASS: $*"; }

repo="$(mk_repo_with_origin https://github.com/caasi/dong3.git)"
cfg="$repo/.claude"; mkdir -p "$cfg"
tmp="$(mktemp -d)"; LOG="$tmp/o.log"

run() { # $1=prompt-json-value, $2=extra-json (e.g. agent_type)
  printf '{"session_id":"S1","cwd":"%s","prompt":%s%s}' "$repo" "$1" "${2:-}" \
    | REVIEW_LOOP_LOG_FILE="$LOG" HOME="$tmp" bash "$HOOK"
}
say_yes() { printf 'observation-log: yes\n---\n' > "$cfg/review-loop.local.md.frontmatter" 2>/dev/null || true
  printf -- '---\nobservation-log: yes\n---\n' > "$cfg/review-loop.local.md"; }

# absent config → nothing
: > "$LOG"; run '"#fix here"'; [ ! -s "$LOG" ] && pass "absent → silent" || fail "wrote without opt-in"
# yes → writes, tier fix
say_yes; : > "$LOG"; out="$(run '"please #fix here"')"
[ -z "$out" ] && pass "no stdout" || fail "stdout: [$out]"
grep -q '  object  project=github.com-caasi-dong3  session=S1  tier=fix$' "$LOG" && pass "fix line" || fail "no fix line"
# strongest wins
: > "$LOG"; run '"#fix and #redo"'; grep -q 'tier=redo$' "$LOG" && pass "redo wins" || fail "priority"
# fenced code on its own lines is ignored
: > "$LOG"; run '"before\n```\n#redo\n```\nafter"'; [ ! -s "$LOG" ] && pass "own-line fence ignored" || fail "fence counted"
# inline span is ignored
: > "$LOG"; run '"use `#redo` as the token"'; [ ! -s "$LOG" ] && pass "inline span ignored" || fail "span counted"
# a real marker outside a fence still counts even when a fenced example is present
: > "$LOG"; run '"```\n#fix\n```\nreally #redo now"'; grep -q 'tier=redo$' "$LOG" && pass "out-of-fence marker counts" || fail "out-of-fence missed"
# adjacency does NOT match: #fixed is not #fix
: > "$LOG"; run '"already #fixed it"'; [ ! -s "$LOG" ] && pass "adjacency no-match" || fail "#fixed matched"
# a marker alone on its own line still counts — a newline is whitespace (C1 regression)
: > "$LOG"; run '"broken.\n#redo"'; grep -q 'tier=redo$' "$LOG" && pass "own-line marker counts" || fail "own-line marker missed"
: > "$LOG"; run '"one\n#again\nthree"'; grep -q 'tier=again$' "$LOG" && pass "mid own-line marker counts" || fail "mid own-line missed"
: > "$LOG"; run '"tail\n#fix"'; grep -q 'tier=fix$' "$LOG" && pass "trailing own-line marker counts" || fail "trailing own-line missed"
# observation-log: no → nothing
printf -- '---\nobservation-log: no\n---\n' > "$cfg/review-loop.local.md"
: > "$LOG"; run '"#fix"'; [ ! -s "$LOG" ] && pass "no → silent" || fail "wrote against no"
# project no overrides a global yes — including from a subdirectory of the repo
mkdir -p "$repo/deep/sub"
printf -- '---\nobservation-log: yes\n---\n' > "$tmp/.claude/review-loop.local.md" 2>/dev/null || { mkdir -p "$tmp/.claude"; printf -- '---\nobservation-log: yes\n---\n' > "$tmp/.claude/review-loop.local.md"; }
printf -- '---\nobservation-log: no\n---\n' > "$cfg/review-loop.local.md"
: > "$LOG"; run '"#fix"'; [ ! -s "$LOG" ] && pass "project no overrides global yes" || fail "override failed"
# same, but the session cwd is a subdirectory — project config still found at the root
run_sub() { printf '{"session_id":"S1","cwd":"%s","prompt":%s}' "$repo/deep/sub" "$1" | REVIEW_LOOP_LOG_FILE="$LOG" HOME="$tmp" bash "$HOOK"; }
: > "$LOG"; run_sub '"#fix"'; [ ! -s "$LOG" ] && pass "subdir sees project no" || fail "subdir bypassed decline"
# a key only in the ## Notes body, not the frontmatter, is read as absent
rm -f "$tmp/.claude/review-loop.local.md"   # reset the global set by the override test above
printf -- '---\nreview-loop-config: 1\n---\n## Notes\nobservation-log: yes\n' > "$cfg/review-loop.local.md"
: > "$LOG"; run '"#fix"'; [ ! -s "$LOG" ] && pass "notes-body not read" || fail "read body key"
say_yes
# agent_type suppresses
: > "$LOG"; run '"#fix"' ',"agent_type":"general"'; [ ! -s "$LOG" ] && pass "agent_type silent" || fail "agent line"
# exit 0 even on garbage
echo 'not json' | REVIEW_LOOP_LOG_FILE="$LOG" bash "$HOOK"; [ $? = 0 ] && pass "exit 0 on garbage" || fail "nonzero"
echo ALL PASS
