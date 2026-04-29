#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate-rules.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

echo "Test 1: validator rejects file with missing frontmatter"
if "$VALIDATOR" "$FIXTURES/bad-missing-frontmatter.md" >/dev/null 2>&1; then
  fail "validator accepted bad-missing-frontmatter.md"
fi
pass "rejected missing frontmatter"

echo "Test 2: validator rejects file with missing Correct block"
if "$VALIDATOR" "$FIXTURES/bad-missing-correct-block.md" >/dev/null 2>&1; then
  fail "validator accepted bad-missing-correct-block.md"
fi
pass "rejected missing Correct block"

echo "Test 3: validator accepts purity-good-minimal.md"
if ! "$VALIDATOR" "$FIXTURES/purity-good-minimal.md" >/dev/null 2>&1; then
  fail "validator rejected purity-good-minimal.md"
fi
pass "accepted purity-good-minimal"

echo "All validator tests passed."
