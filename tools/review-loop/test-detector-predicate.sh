#!/usr/bin/env bash
# Pins the post-round detector's decision, using recorded `codex exec --json` streams.
# No sandbox, no network, no codex binary required.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX="$SCRIPT_DIR/fixtures"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# The predicate, verbatim from SKILL.md's detector.
ran_a_command() {
  jq -e 'select(.type=="item.completed") | select(.item.type=="command_execution")' "$1" >/dev/null 2>&1
}

# The routing decision the skill must make.
#   review  round + zero commands -> non-review (sandbox false clean)
#   critique round + zero commands -> review (exempt: its subject is the findings)
classify_round() { # $1=kind ($2=file)
  if ran_a_command "$2"; then echo "review"; return; fi
  case "$1" in
    critique) echo "review" ;;
    *)        echo "non-review" ;;
  esac
}

for f in codex-native-false-clean codex-native-real-review codex-r2-critique; do
  [ -f "$FIX/$f.jsonl" ] || fail "missing fixture: $f.jsonl"
  jq -e . "$FIX/$f.jsonl" >/dev/null || fail "fixture is not valid JSONL: $f"
done
pass "fixtures present and parse as JSONL"

[ "$(classify_round review "$FIX/codex-native-false-clean.jsonl")" = "non-review" ] \
  || fail "a sandbox-blocked native review must be a non-review, never a silent clean"
pass "native review + zero commands -> non-review"

[ "$(classify_round review "$FIX/codex-native-real-review.jsonl")" = "review" ] \
  || fail "a native review that ran commands must be a review"
pass "native review + commands -> review"

# The exemption. This is the branch that cannot execute on a `broken` host.
ran_a_command "$FIX/codex-r2-critique.jsonl" \
  && fail "the critique fixture must have ZERO command_execution items to test the exemption"
[ "$(classify_round critique "$FIX/codex-r2-critique.jsonl")" = "review" ] \
  || fail "an R2 critique round with zero commands must be EXEMPT, not a non-review"
pass "R2 critique + zero commands -> review (exempt)"

# The false-clean fixture must also carry a corroborating text marker.
grep -q 'sandbox prevented reading' "$FIX/codex-native-false-clean.jsonl" \
  || fail "false-clean fixture lacks its corroborating text marker"
pass "false-clean fixture carries a text marker"

# thread_id is parseable from every fixture (resume depends on it).
for f in "$FIX"/*.jsonl; do
  jq -re 'select(.type=="thread.started") | .thread_id' "$f" >/dev/null \
    || fail "no thread_id in $(basename "$f")"
done
pass "thread_id parseable from every fixture"

# Cross-link: the exemption this test pins must actually be stated in SKILL.md.
# Without this, Task 4 could land an exemption that contradicts these fixtures and
# both suites would still pass.
SKILL="$SCRIPT_DIR/../../plugins/review-loop/skills/review-loop/SKILL.md"
# Both sites must state it, and each is asserted on its own. The operative statement
# lives in Codex mechanics (it scopes the detector); the ghost-panelist gate restates it.
# One regex matching either leaves the suite green when the operative one is deleted.
grep -Eq 'R2 critique rounds are EXEMPT from the post-round' "$SKILL" \
  || fail "Codex mechanics no longer scopes the detector to exempt R2 critique rounds"
grep -Eq 'R2 critique rounds are now exempt too' "$SKILL" \
  || fail "the ghost-panelist gate no longer restates the R2 critique exemption"
grep -Eq 'zero .*command_execution' "$SKILL" \
  || fail "SKILL.md no longer describes the zero-command detector condition"
pass "SKILL.md states the exemption these fixtures pin"

echo "All detector-predicate checks passed."
