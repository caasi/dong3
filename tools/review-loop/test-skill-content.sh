#!/usr/bin/env bash
# Data checks for the review-loop plugin's catalogue metadata.
#
# What used to live here: grep assertions that strings were present in SKILL.md,
# README.md and the command files. Those were removed — a string search cannot
# observe what an agent does after reading a prompt, so it reports green whether
# the instruction works or is ignored. See issue #73.
#
# What remains is genuine. Where a block needs an argument for why a string can settle its
# claim, that block carries it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
MKT="$ROOT/.claude-plugin/marketplace.json"
PLG="$ROOT/plugins/review-loop/.claude-plugin/plugin.json"
VERSION=0.12.0

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

# Both descriptions must state that a settled finding keeps its command, which is the
# fact 0.12.0 added. Same class again: the compliance act is the string being there.
# It asserts nothing about whether the loop then keeps and re-runs the command — issue
# #84 records the runs that measured that.
jq -e '.description|test("keeps the command that settled it")' "$PLG" >/dev/null \
  || fail "plugin.json description does not state the kept-command rule"
jq -e '.plugins[]|select(.name=="review-loop")|.description|test("keeps the command that settled it")' "$MKT" >/dev/null \
  || fail "marketplace review-loop description does not state the kept-command rule"
pass "both descriptions state the kept-command rule"

# Every record must state BOTH re-run triggers, not just the round one. This fact was
# written wrong twice in one episode — first in README.md and CLAUDE.md, then again in
# the three description strings — which is why it is pinned here rather than left to a
# scratch check that dies with the episode. SKILL.md itself says a check worth a longer
# life graduates to the repo test suite.
#
# This is NOT a return of the SKILL.md/README.md grep assertions issue #73 removed.
# Those asserted that a runtime prompt contained an instruction, and stood in for
# whether an agent then obeyed it — a string cannot see that. This asserts that a
# record states a fact, where the string IS the fact and the check is complete for what
# it asserts. That holds for a runtime prompt too: SKILL.md's own rule says a presence
# claim is settled by a grep, and only a behaviour claim needs a run.
#
# Flattened so a future re-wrap cannot turn a present phrase into a false negative. These
# two substrings do not wrap in any record today, and never did in this range — this guard
# is prospective, not a record of a past failure.
#
# SKILL.md's record is its FRONTMATTER DESCRIPTION, not the file. Grepping the whole file
# passed vacuously: the rule body states both triggers too, and the body is frozen, so a
# regression in the description alone slipped through. A mutation test found that — reading
# a check is not running it against a broken case. Slice the frontmatter, the same precision
# `jq -e .description` already gives the two JSON records.
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
frontmatter() { awk '/^---[[:space:]]*$/{n++; next} n==1' "$1" | tr '\n' ' ' | tr -s ' '; }
for trig in 'start of each round' 'before each commit'; do
  for f in "$ROOT/plugins/review-loop/skills/review-loop/README.md" "$ROOT/CLAUDE.md"; do
    flat "$f" | grep -q "$trig" || fail "$(basename "$f") does not state the '$trig' re-run trigger"
  done
  frontmatter "$ROOT/plugins/review-loop/skills/review-loop/SKILL.md" | grep -q "$trig" \
    || fail "SKILL.md frontmatter description does not state the '$trig' re-run trigger"
done
for trig in 'start of each round' 'before each commit'; do
  jq -e --arg t "$trig" '.description|test($t)' "$PLG" >/dev/null \
    || fail "plugin.json description does not state the '$trig' re-run trigger"
  jq -e --arg t "$trig" '.plugins[]|select(.name=="review-loop")|.description|test($t)' "$MKT" >/dev/null \
    || fail "marketplace review-loop description does not state the '$trig' re-run trigger"
done
pass "all five records state both re-run triggers"

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
