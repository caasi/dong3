#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$SCRIPT_DIR/../../plugins/review-loop/skills/review-loop/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

need() { # $1=regex, $2=description
  grep -Eq "$1" "$SKILL" || fail "SKILL.md missing: $2"
  pass "$2"
}

refute() { # $1=regex, $2=description — fails if the regex IS present
  ! grep -Eq "$1" "$SKILL" || fail "SKILL.md still contains (should be gone): $2"
  pass "no longer present: $2"
}

# Novelty-checked anchor. An anchor that already matches the PRE-CHANGE SKILL.md
# guards nothing: it passes before the work is done. Three such anchors were
# proposed during spec 014's review and none of their authors had run grep.
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_REL="plugins/review-loop/skills/review-loop/SKILL.md"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
# A PR/CI checkout often has origin/main but no local main. Falling back to "no baseline"
# there would silently disable novelty checking and let every vacuous anchor pass -- the
# exact fail-open this helper exists to prevent. Try the local branch, then the
# remote-tracking ref, and only then give up.
_base_ref() {
  local b
  for b in "$DEFAULT_BRANCH" "origin/$DEFAULT_BRANCH"; do
    if git -C "$REPO" rev-parse --verify --quiet "$b" >/dev/null; then
      git -C "$REPO" merge-base HEAD "$b" 2>/dev/null && return 0
    fi
  done
  return 1
}
BASE_REF="${BASE_REF:-$(_base_ref || true)}"

# The frontmatter summarises every rule in the body, so grepping the whole file lets the
# summary stand in for the rule it summarises: gut the body, keep the description, and the
# anchor is still green. need_new therefore reads the BODY only. (refute keeps the whole
# file: a phrase must be gone from everywhere, summary included.)
skill_body() { awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm'; }

need_new() { # $1=regex, $2=description — must match the BODY now, must NOT match it at $BASE_REF
  # No pipeline into grep: with `set -o pipefail`, a consumer that exits early on a match
  # can surface the producer's SIGPIPE as a non-zero pipeline status, turning a real match
  # into a silent miss. Capture once, match with a here-string.
  local body; body="$(skill_body < "$SKILL")"
  grep -Eq "$1" <<<"$body" || fail "SKILL.md body missing (frontmatter does not count): $2"
  if [ -z "$BASE_REF" ]; then
    # Outside a git checkout there is genuinely no baseline: warn and pass, so the harness
    # stays runnable. INSIDE one, an unresolvable default branch is an error, not an
    # absence -- passing there would silently disable novelty checking, the exact fail-open
    # this helper exists to prevent.
    if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
      fail "in a git checkout but cannot resolve a baseline (tried $DEFAULT_BRANCH, origin/$DEFAULT_BRANCH) for: $2"
    fi
    echo "WARN: no BASE_REF (not a git checkout) — novelty unchecked for: $2" >&2
    pass "$2"
    return
  fi
  # Once this branch merges, the suite runs on the default branch, where the merge-base
  # IS HEAD -- the baseline and the working file are the same commit, so every anchor
  # would report itself vacuous. Novelty is unknowable there; it was checked before merge.
  if [ "$BASE_REF" = "$(git -C "$REPO" rev-parse HEAD)" ]; then
    echo "WARN: BASE_REF == HEAD (on the baseline branch) — novelty unchecked for: $2" >&2
    pass "$2"
    return
  fi
  local base_content
  base_content="$(git -C "$REPO" show "$BASE_REF:$SKILL_REL" 2>/dev/null)" || \
    fail "cannot read baseline $BASE_REF:$SKILL_REL for: $2"
  # Compare BODY to BODY. The baseline frontmatter summarises its own body, so grepping it
  # would report an anchor vacuous on the strength of a summary the body never contained.
  local base_body; base_body="$(skill_body <<<"$base_content")"
  if grep -Eq "$1" <<<"$base_body"; then
    fail "vacuous anchor (already in the SKILL.md body at $BASE_REF): $2"
  fi
  pass "$2"
}

need 'sandbox-preflight\.sh'                              "preflight script reference"
need 'Route by sandbox state'                            "sandbox-state routing rule"
need 'Embedded-diff form'                                "embedded-diff form"
need '\.item\.type=="command_execution"'                 "detector jq predicate (nested .item.type)"
need 'Embedded-diff rounds are exempt'                   "detector exemption for embedded-diff"
need 'references/codex-sandbox-host-fixes\.md'           "host-fix reference link"

# spec 010 Part A — watch pane gated behind explicit request
need 'asked to watch'                                    "watch pane gated on explicit request"
refute 'is set, spawn'                                   "old tmux-alone spawn prose"
# code-level guard: the spawn line must NOT gate on $TMUX alone (line-anchored so
# the new watch-first gate and incidental $TMUX prose don't trip it).
refute '^[[:space:]]*\[ -n "\$\{TMUX:-\}" \] && watch_pane'  "old tmux-only spawn gate (code)"

# spec 010 Part B — after-convergence group-commits offer
need 'After convergence'                                 "after-convergence offer section"
need 'feature.branch'                                    "offer is feature-branch only"
need 'force-with-lease'                                  "pinned-lease push guidance"
need 'never automatic'                                   "offer is assisted, never automatic"

# spec 014 Part A — roster, init, calibration
need_new 'never silently follow a stale config'          "roster drift is surfaced, not followed"
need_new 'review-loop\.local\.md'                        "enrollment config path"
need_new 'derived from `kind`'                           "tier is derived, not declared"

# spec 014 Part B — the adversarial panel
need_new 'blind, parallel, on the same unfixed diff'     "round 1 is blind on the UNFIXED diff"
need_new 'tried hardest to break'                        "R2's non-forcing critique rule, not its heading"
need_new 'refuted-undefended'                            "the status that had to exist"
need_new 'status == survived'                            "gate turns on survived, not != refuted"
need_new 'a concrete, checkable condition'               "the record's falsification FIELD, not the word"
need_new 'facilitator confirms the quote'                "prose reproduction is a check, not a capability"
need_new 'retain both verbatim texts'                    "dedup cannot launder attribution"
need_new 'weak evidence'                                 "same-family convergence is labelled weak"
need_new 'critique rounds are now exempt'                "R2 detector exemption"
need_new 'forge reviewer'                                "Phase B is a slot"
need_new 'clean_when'                                    "declared reviewers pin their stop signal"

# the leading convergence prompt is gone
refute 'Are your earlier points resolved'                "leading convergence prompt"
# the old Copilot-only Phase B heading is gone (note: it was an h3, not an h2)
refute '^### Phase B — GitHub Copilot'                   "Copilot-only Phase B heading"

echo "All SKILL.md content checks passed."
