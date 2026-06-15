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

echo "All SKILL.md content checks passed."
