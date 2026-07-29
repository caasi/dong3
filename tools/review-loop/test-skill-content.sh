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
# Digest of the description both files must carry, pinned so that changing the
# version forces someone to look at the description. It does not check that the
# description is *right* — no data check can. It catches the case this suite used
# to miss: an edit to the description that silently does nothing, which the
# identical-descriptions check below reports green for, because two files that
# both failed to change still agree with each other. Re-pin deliberately when the
# description changes, including re-pinning the same value when it should not.
DESC_SHA=d38c90106f77d214

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

pd="$(jq -r .description "$PLG")"
md="$(jq -r '.plugins[]|select(.name=="review-loop").description' "$MKT")"
[ "$pd" = "$md" ] || fail "plugin.json and marketplace descriptions differ"
pass "descriptions identical"

ds="$(jq -r .description "$PLG" | sha256sum | cut -c1-16)"
[ "$ds" = "$DESC_SHA" ] || fail "description digest is $ds, not the pinned $DESC_SHA — re-pin DESC_SHA if the change was intended"
pass "description digest $DESC_SHA"

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
