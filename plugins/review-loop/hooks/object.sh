#!/usr/bin/env bash
# object.sh — UserPromptSubmit hook: appends one `object` line per author objection.
# Always exits 0. Never writes stdout. Inert unless observation-log: yes resolves.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../skills/review-loop/scripts/logline.sh"
trap 'exit 0' EXIT           # rule 2: any failure path still exits 0

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

# Remove fenced blocks (lines between ``` fences) and inline spans (`...`),
# then match a whitespace-delimited marker word. Priority redo > again > fix.
stripped="$(printf '%s' "$prompt" | awk 'BEGIN{f=0} /^[[:space:]]*```/{f=!f;next} !f{print}' | sed 's/`[^`]*`//g')"
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
ll_append "$(ll_line object "project=$proj" "session=$sid" "tier=$tier")"
exit 0
