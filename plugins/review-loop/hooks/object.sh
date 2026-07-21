#!/usr/bin/env bash
# object.sh — UserPromptSubmit hook: appends one `object` line per author objection.
# Always exits 0. Never writes stdout. Inert unless observation-log: yes resolves.
set -uo pipefail
trap 'exit 0' EXIT           # rule 2, installed FIRST: every failure path exits 0, including
                             # a missing, unreadable, or unparsable logline.sh sourced below.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 0
. "$DIR/../skills/review-loop/scripts/logline.sh" 2>/dev/null || exit 0

command -v jq >/dev/null 2>&1 || exit 0   # no parser → silent (init reports it)

payload="$(cat)"
agent_type="$(printf '%s' "$payload" | jq -r '.agent_type // empty' 2>/dev/null)"
[ -n "$agent_type" ] && exit 0            # rule 1

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null)"
[ -n "$cwd" ] && [ -n "$sid" ] || exit 0

# resolve observation-log from project then global frontmatter (top scalar, stop at closing ---)
resolve() { # $1=file
  [ -f "$1" ] || return 1
  awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f&&/^observation-log:/{sub(/^observation-log:[[:space:]]*/,"");print;exit}' "$1"
}
# project config lives at the checkout root's .claude/, not necessarily $cwd — a session
# in a subdirectory must still see a project-level `no`. --show-toplevel gives the worktree
# root (where .claude/ lives); it is the right root here, unlike the slug, which uses
# --git-common-dir. Fall back to $cwd if not in a repo.
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")"
ans="$(resolve "$root/.claude/review-loop.local.md" || true)"
[ -n "$ans" ] || ans="$(resolve "$HOME/.claude/review-loop.local.md" || true)"
[ "$ans" = "yes" ] || exit 0

# Remove fenced blocks (lines between ``` fences) and inline spans (`...`), then flatten
# newlines to spaces, then match a whitespace-delimited marker word. Priority redo > again > fix.
# The flatten matters: `has` matches on one line, so a marker that begins its own line must
# become space-delimited. A newline is whitespace, so `#redo` alone on a line still counts.
# Fence and span stripping run first (line by line), before the flatten, so code is still excluded.
stripped="$(printf '%s' "$prompt" | awk 'BEGIN{f=0} /^[[:space:]]*```/{f=!f;next} !f{print}' | sed 's/`[^`]*`//g' | tr '\n' ' ')"
has() { # $1=word — true only if it appears whitespace-delimited
  printf '%s' " $stripped " | grep -Eq "[[:space:]]#$1[[:space:]]"
}
tier=""
if has redo; then tier=redo
elif has again; then tier=again
elif has fix; then tier=fix
fi
[ -n "$tier" ] || exit 0

proj="$(ll_project_slug "$cwd")"
# Scrub the session id like every other value. It is a harness UUID in practice, so ll_scrub
# is a no-op on it and the omission check (spec line 113, exact-id match) still lines up; but a
# session id carrying whitespace, '=' or '/' could otherwise forge a second line or break the
# two-space field boundaries, so the value rules must apply here too (acceptance line 433).
ll_append "$(ll_line object "project=$proj" "session=$(ll_scrub "$sid")" "tier=$tier")"
exit 0
