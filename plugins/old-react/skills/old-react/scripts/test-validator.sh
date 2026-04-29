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

echo "Test 4: validator rejects file whose Correct section has no fenced block"
if "$VALIDATOR" "$FIXTURES/purity-fence-only-under-incorrect.md" >/dev/null 2>&1; then
  fail "validator accepted purity-fence-only-under-incorrect.md (Correct has no fence)"
fi
pass "rejected fence-only-under-incorrect"

echo "Test 5: validator accepts frontmatter with YAML inline comments"
if ! "$VALIDATOR" "$FIXTURES/purity-good-inline-comment.md" >/dev/null 2>&1; then
  fail "validator rejected purity-good-inline-comment.md (inline comment not stripped)"
fi
pass "accepted purity-good-inline-comment"

echo "All validator tests passed."
