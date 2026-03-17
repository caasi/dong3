#!/usr/bin/env bash
# Test suite for the -T (thinking filter) in chat.sh.
# Feeds mock API responses through the same jq filter and checks results.
# Dependencies: jq
set -euo pipefail

PASS=0
FAIL=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JQ_FILTER_FILE="$SCRIPT_DIR/thinking-filter.jq"

if [[ ! -f "$JQ_FILTER_FILE" ]]; then
  echo "Error: thinking-filter.jq not found at $JQ_FILTER_FILE" >&2
  exit 1
fi

run_test() {
  local name="$1" input="$2" expected="$3"
  local actual
  actual=$(printf '%s' "$input" | jq -f "$JQ_FILTER_FILE")
  # Normalize whitespace for comparison
  local norm_expected norm_actual
  norm_expected=$(printf '%s' "$expected" | jq -c .)
  norm_actual=$(printf '%s' "$actual" | jq -c .)
  if [[ "$norm_actual" == "$norm_expected" ]]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    echo "    expected: $norm_expected"
    echo "    actual:   $norm_actual"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Thinking Filter Tests ==="
echo ""

# --- 1. DeepSeek: reasoning_content ---
run_test "DeepSeek reasoning_content removed" \
  '{"choices":[{"message":{"role":"assistant","content":"The answer is 42.","reasoning_content":"Let me think step by step..."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"The answer is 42."}}]}'

# --- 2. OpenRouter/OpenAI: reasoning field ---
run_test "OpenRouter reasoning removed" \
  '{"choices":[{"message":{"role":"assistant","content":"Hello world.","reasoning":"I should greet the user."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"Hello world."}}]}'

# --- 3. OpenRouter: reasoning_details array ---
run_test "OpenRouter reasoning_details removed" \
  '{"choices":[{"message":{"role":"assistant","content":"Result.","reasoning_details":[{"type":"reasoning.text","text":"thinking..."}]}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"Result."}}]}'

# --- 4. Anthropic via litellm: thinking_blocks ---
run_test "Anthropic thinking_blocks removed" \
  '{"choices":[{"message":{"role":"assistant","content":"Done.","thinking_blocks":[{"type":"thinking","thinking":"deep thought","signature":"abc123"}]}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"Done."}}]}'

# --- 5. Qwen3: <think> block in content ---
run_test "Qwen3 think block stripped from content" \
  '{"choices":[{"message":{"role":"assistant","content":"<think>\nI need to reason about this.\nStep 1: analyze.\nStep 2: conclude.\n</think>\nThe answer is 42."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"The answer is 42."}}]}'

# --- 6. Qwen3: <think> block with no trailing newline ---
run_test "Qwen3 think block no trailing newline" \
  '{"choices":[{"message":{"role":"assistant","content":"<think>short thought</think>answer"}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"answer"}}]}'

# --- 7. Multiple fields at once ---
run_test "Multiple thinking fields combined" \
  '{"choices":[{"message":{"role":"assistant","content":"<think>hmm</think>\nOK.","reasoning_content":"rc","reasoning":"r","reasoning_details":[],"thinking_blocks":[]}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"OK."}}]}'

# --- 8. No thinking fields (passthrough) ---
run_test "Normal response unchanged" \
  '{"choices":[{"message":{"role":"assistant","content":"Just a normal response."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"Just a normal response."}}]}'

# --- 9. Non-chat response (error, etc.) passthrough ---
run_test "Error response passthrough" \
  '{"error":{"message":"model not found","type":"invalid_request_error"}}' \
  '{"error":{"message":"model not found","type":"invalid_request_error"}}'

# --- 10. content is null (some models return null content with tool_calls) ---
run_test "Null content preserved" \
  '{"choices":[{"message":{"role":"assistant","content":null,"reasoning_content":"thinking..."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":null}}]}'

# --- 11. Multiple choices ---
run_test "Multiple choices all filtered" \
  '{"choices":[{"message":{"role":"assistant","content":"A","reasoning":"r1"}},{"message":{"role":"assistant","content":"<think>t</think>\nB","reasoning":"r2"}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"A"}},{"message":{"role":"assistant","content":"B"}}]}'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
