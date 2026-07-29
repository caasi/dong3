#!/usr/bin/env bash
# Data checks for the tsugu plugin's catalogue metadata.
#
# What used to live here: ~200 grep assertions that strings were present in
# SKILL.md, templates, references and command files. Those were removed — a
# prompt's property is what an agent does after reading it, and a string search
# cannot observe behaviour, so it reports green whether the instruction works, is
# ignored, or is contradicted elsewhere. See issue #73.
#
# What remains is genuine: the subject is JSON, and the property under test is
# the value of a field. Version drift and a stale catalogue description are real
# defects that a data check really does catch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
MKT="$ROOT/.claude-plugin/marketplace.json"
PLG="$ROOT/plugins/tsugu/.claude-plugin/plugin.json"
VERSION=0.10.0

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

mkt() { jq -r '.plugins[]|select(.name=="tsugu")|'"$1" "$MKT"; }

[ "$(mkt .version)" = "$VERSION" ] || fail "marketplace tsugu version is $(mkt .version), not $VERSION"
pass "marketplace: tsugu version $VERSION"

# The catalogue entry and the plugin's own manifest must describe the same
# plugin. These are the facts a reader of the marketplace relies on.
for probe in prune 'local-first|local by default' 'post-handoff|POST-HANDOFF'; do
  jq -e --arg p "$probe" '.plugins[]|select(.name=="tsugu")|.description|test($p)' "$MKT" >/dev/null \
    || fail "marketplace tsugu description does not match /$probe/"
  pass "marketplace description matches /$probe/"
done

for probe in prune 'local-first|local by default' 'schema 7'; do
  jq -e --arg p "$probe" '.description|test($p)' "$PLG" >/dev/null \
    || fail "plugin.json description does not match /$probe/"
  pass "plugin.json description matches /$probe/"
done

echo "All tsugu metadata checks passed."
