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

# spec 014 — the roster
need "no reviewer sees another's findings"               "A1 is blind"
need 'Every live reviewer, blind and in parallel, on the same unfixed diff' "A1 rule (not the frontmatter/intro echo of 'same unfixed diff')"
need 'never silently follow a stale config'              "drift is surfaced"
need 'review-loop\.local\.md'                            "enrollment config path"
need 'bonus, not a gate'                                 "heterogeneity gates nothing"
need 'same-family passes are first-class'               "same-family is not a fallback"
need 'A recipe never suppresses a detector'             "reconciliation logic present (not just the section opener)"

# spec 014 — findings and the verdict
need 'absence of a falsification condition gates nothing' "a missing falsification condition gates nothing"
need 'a citation the facilitator verifies with a command' "prose reproduction is a check, not a capability"
need 'never imputes'                                     "the facilitator may not fill in another's fields"
need 'retain both verbatim texts'                        "dedup cannot launder attribution"
need 'never reported as a downgrade'                     "same-family is disclosed, never downgraded"
need 'never let a weak check downgrade a same-family pass' "a weak check may not downgrade same-family"
need 'actually ran, verified'                            "the verdict names the real panel"

# spec 014 — when adversarial review is the point (§B.7)
need 'does the finding have a runnable ground truth'     "the escalation axis is ground truth"
need 'never auto-runs it'                                "the direction guard is proposed, not auto-run"
need 'diversity-illusion danger zone'                    "converged-without-proof is the trigger"
# NB: the no-sub-command RULE is stated by NAMING /review-loop:direction as forbidden, so it is a
# need (the phrase is present as the denial), never a refute — Step 4's grep asserts exactly 1 hit.
need 'never a .?/review-loop:direction.? sub-command'    "no direction sub-command, stated as the rule"

# spec 014 — Codex's first round carries a prompt
need 'freeform, carries the prompt'                      "A1 uses the prompt-bearing form (comment)"
need 'carry the finding-record request the blind round needs' "R1 is prompt-bearing (rule, not just the comment): targeted form cannot serve R1"
need 'git diff --name-only'                              "the inferred diff is checked"

# spec 014 — a review that is not a review
need 'drop the reviewer, continue, and disclose'          "ghost reviewer gate"

# gone
refute 'Are your earlier points resolved'                "leading convergence prompt"
refute '^\*\*A2\. Codex review'                          "the old serial second gate"

echo "All SKILL.md content checks passed."
