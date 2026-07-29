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
VERSION=0.8.0

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

v="$(jq -r '.plugins[]|select(.name=="review-loop").version' "$MKT")"
[ "$v" = "$VERSION" ] || fail "review-loop version is $v, not $VERSION"
pass "version $VERSION"

# Both descriptions must mention the hook, which is a user-facing fact about what
# installing this plugin does. The probe is deliberately loose — either word
# satisfies it — because it is inherited coverage, not a new requirement about
# how the hook must be described. Scoped to the review-loop entry: a raw grep
# over marketplace.json would pass on another plugin's description.
jq -e '.plugins[]|select(.name=="review-loop")|.description|test("always-on|inert")' "$MKT" >/dev/null \
  || fail "marketplace review-loop description does not mention the hook"
jq -e '.description|test("always-on|inert")' "$PLG" >/dev/null \
  || fail "plugin.json description does not mention the hook"
pass "both descriptions mention the hook"

echo "All review-loop metadata checks passed."
