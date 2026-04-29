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
if "$VALIDATOR" "$FIXTURES/purity-missing-correct.md" >/dev/null 2>&1; then
  fail "validator accepted purity-missing-correct.md"
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

echo "Test 6: validator rejects file with unclosed frontmatter"
if "$VALIDATOR" "$FIXTURES/purity-unclosed-frontmatter.md" >/dev/null 2>&1; then
  fail "validator accepted purity-unclosed-frontmatter.md"
fi
pass "rejected purity-unclosed-frontmatter"

echo "Test 7: validator rejects file with an unclosed fenced code block"
if "$VALIDATOR" "$FIXTURES/purity-unclosed-fence.md" >/dev/null 2>&1; then
  fail "validator accepted purity-unclosed-fence.md"
fi
pass "rejected purity-unclosed-fence"

echo "Test 8: validator rejects file whose title heading exists only inside a code fence"
if "$VALIDATOR" "$FIXTURES/purity-title-only-in-fence.md" >/dev/null 2>&1; then
  fail "validator accepted purity-title-only-in-fence.md (title not a real H2)"
fi
pass "rejected purity-title-only-in-fence"

echo "Test 9: validator rejects file whose markers exist only inside a code fence"
if "$VALIDATOR" "$FIXTURES/purity-markers-only-in-fence.md" >/dev/null 2>&1; then
  fail "validator accepted purity-markers-only-in-fence.md (markers not in body)"
fi
pass "rejected purity-markers-only-in-fence"

echo "Test 10: validator rejects file with a tag not in the closed set"
if "$VALIDATOR" "$FIXTURES/purity-bad-tag.md" >/dev/null 2>&1; then
  fail "validator accepted purity-bad-tag.md (tag 'foobar' is not in the closed set)"
fi
pass "rejected purity-bad-tag"

echo "Test 11: validator rejects file whose tags array is too short"
if "$VALIDATOR" "$FIXTURES/purity-too-few-tags.md" >/dev/null 2>&1; then
  fail "validator accepted purity-too-few-tags.md (only one tag, spec requires 2-4)"
fi
pass "rejected purity-too-few-tags"

echo "Test 12: validator rejects unclosed frontmatter when body contains a Markdown horizontal rule"
if "$VALIDATOR" "$FIXTURES/purity-frontmatter-body-hr.md" >/dev/null 2>&1; then
  fail "validator accepted purity-frontmatter-body-hr.md (body --- is not the frontmatter close)"
fi
pass "rejected purity-frontmatter-body-hr"

echo "All validator tests passed."
