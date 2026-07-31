#!/usr/bin/env bash
# Data checks for the review-loop plugin's catalogue metadata.
#
# What used to live here: grep assertions that strings were present in SKILL.md,
# README.md and the command files. Those were removed — a string search cannot
# observe what an agent does after reading a prompt, so it reports green whether
# the instruction works or is ignored. See issue #73.
#
# What remains is genuine: JSON fields, compared by value.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
MKT="$ROOT/.claude-plugin/marketplace.json"
PLG="$ROOT/plugins/review-loop/.claude-plugin/plugin.json"
VERSION=0.10.0

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

pd="$(jq -r .description "$PLG")"
md="$(jq -r '.plugins[]|select(.name=="review-loop").description' "$MKT")"
[ "$pd" = "$md" ] || fail "plugin.json and marketplace descriptions differ"
pass "descriptions identical"

# Both descriptions must state how a finding is settled, which is the fact 0.8.0
# added. This is a presence claim and a grep settles it: the string is the
# compliance act, so the check is complete for what it asserts. It replaces a
# pinned digest that could not catch the failure it was named after — a digest
# re-derived from the file it checks passes on the very no-op edit that motivated
# it, because the author reads the stale value back out and pastes it in.
jq -e '.description|test("five independent simulation runs")' "$PLG" >/dev/null \
  || fail "plugin.json description does not say how a runtime-prompt finding is settled"
jq -e '.plugins[]|select(.name=="review-loop")|.description|test("five independent simulation runs")' "$MKT" >/dev/null \
  || fail "marketplace review-loop description does not say how a runtime-prompt finding is settled"
pass "both descriptions state the settlement rule"

# Both descriptions must state the recurring-T3 rule, which is the fact 0.9.0 added.
# Same class as the check above: a user-facing fact whose compliance act is the string
# being there. It asserts nothing about whether the loop then re-confirms direction —
# only a run shows that, and spec 019 records those runs.
jq -e '.description|test("re-confirms the direction of the whole change")' "$PLG" >/dev/null \
  || fail "plugin.json description does not state the recurring-T3 rule"
jq -e '.plugins[]|select(.name=="review-loop")|.description|test("re-confirms the direction of the whole change")' "$MKT" >/dev/null \
  || fail "marketplace review-loop description does not state the recurring-T3 rule"
pass "both descriptions state the recurring-T3 rule"

v="$(jq -r '.plugins[]|select(.name=="review-loop").version' "$MKT")"
[ "$v" = "$VERSION" ] || fail "review-loop version is $v, not $VERSION"
pass "version $VERSION"

# Every review-loop *.sh must be executable IN THE INDEX — both the ones that ship with
# the plugin and this repository's own test scripts, since the defect this catches is the
# same in either place.
# § A3 tells the facilitator to run log.sh directly and § Helper scripts states that all
# of them are executable, so a script committed 100644 makes the documented call fail for
# everyone who installs the plugin — while a local `chmod +x` hides it from the author.
# The mode is read from the index, not the working tree, because that is what ships.
listing="$(cd "$ROOT" && git ls-files -s 'plugins/review-loop/skills/review-loop/scripts/*.sh' \
                                          'tools/review-loop/*.sh')" \
  || fail "could not read the index for the review-loop scripts"
[ -n "$listing" ] || fail "no review-loop scripts found in the index — the check would pass vacuously"
bad=0
while IFS= read -r row; do
  [ -n "$row" ] || continue
  mode="${row%% *}"; path="${row#*	}"
  [ "$mode" = "100755" ] || { echo "  not executable in the index: $path" >&2; bad=1; }
done <<EOF
$listing
EOF
[ "$bad" = 0 ] || fail "a review-loop script is committed non-executable"
pass "every review-loop *.sh is executable in the index ($(printf '%s\n' "$listing" | wc -l) files)"

echo "All review-loop metadata checks passed."
