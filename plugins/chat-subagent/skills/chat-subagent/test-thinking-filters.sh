#!/usr/bin/env bash
# Test suite for thinking/reasoning filters.
# Tests both OpenAI-compatible and LM Studio native API jq filters.
# Dependencies: jq
set -euo pipefail

PASS=0
FAIL=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENAI_FILTER="$SCRIPT_DIR/thinking-filter.jq"
LMSTUDIO_FILTER="$SCRIPT_DIR/thinking-filter-lmstudio.jq"

run_test() {
  local filter="$1" name="$2" input="$3" expected="$4"
  local actual
  actual=$(printf '%s' "$input" | jq -f "$filter")
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

# ============================================================
# OpenAI-compatible filter (thinking-filter.jq)
# ============================================================
echo "=== OpenAI-compatible Filter Tests ==="
echo ""

if [[ ! -f "$OPENAI_FILTER" ]]; then
  echo "Error: thinking-filter.jq not found at $OPENAI_FILTER" >&2
  exit 1
fi

run_test "$OPENAI_FILTER" "DeepSeek reasoning_content removed" \
  '{"choices":[{"message":{"role":"assistant","content":"The answer is 42.","reasoning_content":"Let me think step by step..."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"The answer is 42."}}]}'

run_test "$OPENAI_FILTER" "OpenRouter reasoning removed" \
  '{"choices":[{"message":{"role":"assistant","content":"Hello world.","reasoning":"I should greet the user."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"Hello world."}}]}'

run_test "$OPENAI_FILTER" "OpenRouter reasoning_details removed" \
  '{"choices":[{"message":{"role":"assistant","content":"Result.","reasoning_details":[{"type":"reasoning.text","text":"thinking..."}]}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"Result."}}]}'

run_test "$OPENAI_FILTER" "Anthropic thinking_blocks removed" \
  '{"choices":[{"message":{"role":"assistant","content":"Done.","thinking_blocks":[{"type":"thinking","thinking":"deep thought","signature":"abc123"}]}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"Done."}}]}'

run_test "$OPENAI_FILTER" "Qwen3 think block stripped from content" \
  '{"choices":[{"message":{"role":"assistant","content":"<think>\nI need to reason about this.\nStep 1: analyze.\nStep 2: conclude.\n</think>\nThe answer is 42."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"The answer is 42."}}]}'

run_test "$OPENAI_FILTER" "Qwen3 think block no trailing newline" \
  '{"choices":[{"message":{"role":"assistant","content":"<think>short thought</think>answer"}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"answer"}}]}'

run_test "$OPENAI_FILTER" "Multiple thinking fields combined" \
  '{"choices":[{"message":{"role":"assistant","content":"<think>hmm</think>\nOK.","reasoning_content":"rc","reasoning":"r","reasoning_details":[],"thinking_blocks":[]}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"OK."}}]}'

run_test "$OPENAI_FILTER" "Normal response unchanged" \
  '{"choices":[{"message":{"role":"assistant","content":"Just a normal response."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"Just a normal response."}}]}'

run_test "$OPENAI_FILTER" "Error response passthrough" \
  '{"error":{"message":"model not found","type":"invalid_request_error"}}' \
  '{"error":{"message":"model not found","type":"invalid_request_error"}}'

run_test "$OPENAI_FILTER" "Null content preserved" \
  '{"choices":[{"message":{"role":"assistant","content":null,"reasoning_content":"thinking..."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":null}}]}'

run_test "$OPENAI_FILTER" "Multiple choices all filtered" \
  '{"choices":[{"message":{"role":"assistant","content":"A","reasoning":"r1"}},{"message":{"role":"assistant","content":"<think>t</think>\nB","reasoning":"r2"}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"A"}},{"message":{"role":"assistant","content":"B"}}]}'

run_test "$OPENAI_FILTER" "Analysis block stripped from content" \
  '{"choices":[{"message":{"role":"assistant","content":"<analysis>\nLet me break this down.\nStep 1: check.\n</analysis>\n\nThe answer is 42."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"The answer is 42."}}]}'

run_test "$OPENAI_FILTER" "Analysis block inline" \
  '{"choices":[{"message":{"role":"assistant","content":"<analysis>quick check</analysis>result"}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"result"}}]}'

run_test "$OPENAI_FILTER" "Both think and analysis blocks" \
  '{"choices":[{"message":{"role":"assistant","content":"<think>reasoning</think>\n<analysis>checking</analysis>\nfinal answer"}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"final answer"}}]}'

run_test "$OPENAI_FILTER" "Thinking block (full tag) stripped from content" \
  '{"choices":[{"message":{"role":"assistant","content":"<thinking>\nI need to explain the key differences.\nLet me organize this.\n</thinking>\n\nHere is the answer."}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"Here is the answer."}}]}'

run_test "$OPENAI_FILTER" "Thinking block (full tag) inline" \
  '{"choices":[{"message":{"role":"assistant","content":"<thinking>quick thought</thinking>result"}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"result"}}]}'

run_test "$OPENAI_FILTER" "Think, thinking, and analysis blocks combined" \
  '{"choices":[{"message":{"role":"assistant","content":"<think>r1</think>\n<thinking>r2</thinking>\n<analysis>r3</analysis>\nfinal"}}]}' \
  '{"choices":[{"message":{"role":"assistant","content":"final"}}]}'

# ============================================================
# LM Studio native filter (thinking-filter-lmstudio.jq)
# ============================================================
echo ""
echo "=== LM Studio Native Filter Tests ==="
echo ""

if [[ ! -f "$LMSTUDIO_FILTER" ]]; then
  echo "Error: thinking-filter-lmstudio.jq not found at $LMSTUDIO_FILTER" >&2
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed, LM Studio tests skipped ==="
  [[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
fi

# LM Studio tests will be added in Task 2

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
