# chat-subagent v0.4.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove `chat.sh` wrapper, teach SKILL.md to use `curl` directly, add LM Studio native API support via reference docs, bump to v0.4.0.

**Architecture:** SKILL.md becomes the orchestrator — it tells Claude how to read endpoint config, pick the right API format (OpenAI or LM Studio native), compose a `curl` command, and pipe through jq for token reduction. API-specific details live in `references/openai-api.md` and `references/lmstudio-api.md`. Two jq filters handle the different response structures.

**Tech Stack:** Bash (`curl`, `jq`), Markdown (SKILL.md, reference docs), JSON (plugin.json, marketplace.json)

**Spec:** `docs/superpowers/specs/2026-03-27-chat-subagent-lmstudio-native-api-design.md`

**Branch:** `feat/chat-subagent-v040`

---

## File Map

```
plugins/chat-subagent/
  skills/chat-subagent/
    SKILL.md                          # MODIFY (Tasks 4, 5)
    thinking-filter.jq                # KEEP (no changes)
    thinking-filter-lmstudio.jq       # CREATE (Task 2)
    test-thinking-filters.sh          # CREATE (Tasks 1, 2) — replaces test-thinking-filter.sh
    chat.sh                           # DELETE (Task 6)
    test-thinking-filter.sh           # DELETE (Task 6)
    references/
      openai-api.md                   # CREATE (Task 3)
      lmstudio-api.md                 # CREATE (Task 3)
  .claude-plugin/plugin.json          # MODIFY (Task 7)
.claude-plugin/marketplace.json       # MODIFY (Task 7)
```

---

## Task 1: Write tests for existing OpenAI thinking filter

Port test cases from `test-thinking-filter.sh` into a new `test-thinking-filters.sh` that tests both filters. Start with the OpenAI filter only — LM Studio filter doesn't exist yet.

**Files:**
- Create: `plugins/chat-subagent/skills/chat-subagent/test-thinking-filters.sh`
- Read: `plugins/chat-subagent/skills/chat-subagent/test-thinking-filter.sh` (existing tests to port)

- [ ] **Step 1: Create `test-thinking-filters.sh` with OpenAI filter tests**

The new script uses the same `run_test` harness but is organized into sections per filter. Start with the OpenAI section — all 17 existing tests ported verbatim, plus a placeholder section for LM Studio tests.

```bash
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
  actual=$(printf '%s' "$input" | jq --from-file "$filter")
  local norm_expected norm_actual
  norm_expected=$(printf '%s' "$expected" | jq --compact-output .)
  norm_actual=$(printf '%s' "$actual" | jq --compact-output .)
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
  echo "SKIP: thinking-filter-lmstudio.jq not found (not yet created)"
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed, LM Studio tests skipped ==="
  [[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
fi

# LM Studio tests will be added in Task 3

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Make it executable and run to verify OpenAI tests pass**

Run: `chmod +x plugins/chat-subagent/skills/chat-subagent/test-thinking-filters.sh && plugins/chat-subagent/skills/chat-subagent/test-thinking-filters.sh`

Expected: All 17 OpenAI tests PASS, LM Studio section shows SKIP.

- [ ] **Step 3: Commit**

```bash
git add plugins/chat-subagent/skills/chat-subagent/test-thinking-filters.sh
git commit -m "test(chat-subagent): port OpenAI filter tests to new unified test script"
```

---

## Task 2: Write LM Studio filter tests, then create the filter (TDD)

Write the failing tests first, then implement the filter to make them pass.

**Files:**
- Modify: `plugins/chat-subagent/skills/chat-subagent/test-thinking-filters.sh` (add LM Studio test cases)
- Create: `plugins/chat-subagent/skills/chat-subagent/thinking-filter-lmstudio.jq`

- [ ] **Step 1: Remove the SKIP guard and add LM Studio test cases**

In `test-thinking-filters.sh`, replace the block starting with `if [[ ! -f "$LMSTUDIO_FILTER" ]]; then` (the SKIP guard) and the `# LM Studio tests will be added in Task 3` comment with these test cases (the filter file check should remain but should error, not skip):

```bash
# --- L1. Reasoning items filtered out ---
run_test "$LMSTUDIO_FILTER" "Reasoning items removed" \
  '{"output":[{"type":"reasoning","content":"thinking..."},{"type":"message","content":"The answer."}],"stats":{}}' \
  '{"output":[{"type":"message","content":"The answer."}],"stats":{}}'

# --- L2. Multiple reasoning items interleaved ---
run_test "$LMSTUDIO_FILTER" "Multiple reasoning items interleaved" \
  '{"output":[{"type":"reasoning","content":"r1"},{"type":"message","content":"First."},{"type":"reasoning","content":"r2"},{"type":"message","content":"Second."}],"stats":{}}' \
  '{"output":[{"type":"message","content":"First."},{"type":"message","content":"Second."}],"stats":{}}'

# --- L3. Tool call items preserved ---
run_test "$LMSTUDIO_FILTER" "Tool call items preserved" \
  '{"output":[{"type":"reasoning","content":"thinking"},{"type":"tool_call","tool":"web-search","arguments":{"query":"test"},"output":"results"},{"type":"message","content":"Done."}],"stats":{}}' \
  '{"output":[{"type":"tool_call","tool":"web-search","arguments":{"query":"test"},"output":"results"},{"type":"message","content":"Done."}],"stats":{}}'

# --- L4. Think tags stripped from message content ---
run_test "$LMSTUDIO_FILTER" "Think tags stripped from message content" \
  '{"output":[{"type":"message","content":"<think>\nLet me reason.\n</think>\nThe answer is 42."}],"stats":{}}' \
  '{"output":[{"type":"message","content":"The answer is 42."}],"stats":{}}'

# --- L5. Thinking tags stripped from message content ---
run_test "$LMSTUDIO_FILTER" "Thinking tags stripped from message content" \
  '{"output":[{"type":"message","content":"<thinking>reasoning</thinking>result"}],"stats":{}}' \
  '{"output":[{"type":"message","content":"result"}],"stats":{}}'

# --- L6. Analysis tags stripped from message content ---
run_test "$LMSTUDIO_FILTER" "Analysis tags stripped from message content" \
  '{"output":[{"type":"message","content":"<analysis>\nChecking.\n</analysis>\n\nFinal answer."}],"stats":{}}' \
  '{"output":[{"type":"message","content":"Final answer."}],"stats":{}}'

# --- L7. All tag types combined in message ---
run_test "$LMSTUDIO_FILTER" "All tag types combined in message" \
  '{"output":[{"type":"message","content":"<think>t1</think>\n<thinking>t2</thinking>\n<analysis>t3</analysis>\nfinal"}],"stats":{}}' \
  '{"output":[{"type":"message","content":"final"}],"stats":{}}'

# --- L8. No reasoning (passthrough) ---
run_test "$LMSTUDIO_FILTER" "No reasoning items unchanged" \
  '{"output":[{"type":"message","content":"Just a normal response."}],"stats":{"input_tokens":10}}' \
  '{"output":[{"type":"message","content":"Just a normal response."}],"stats":{"input_tokens":10}}'

# --- L9. Empty output array ---
run_test "$LMSTUDIO_FILTER" "Empty output array" \
  '{"output":[],"stats":{}}' \
  '{"output":[],"stats":{}}'

# --- L10. Only reasoning items (all filtered) ---
run_test "$LMSTUDIO_FILTER" "Only reasoning items results in empty output" \
  '{"output":[{"type":"reasoning","content":"r1"},{"type":"reasoning","content":"r2"}],"stats":{}}' \
  '{"output":[],"stats":{}}'

# --- L11. Tool call content not stripped (tags only in message type) ---
run_test "$LMSTUDIO_FILTER" "Tool call output not tag-stripped" \
  '{"output":[{"type":"tool_call","tool":"fetch","output":"<think>not stripped</think>data"}],"stats":{}}' \
  '{"output":[{"type":"tool_call","tool":"fetch","output":"<think>not stripped</think>data"}],"stats":{}}'
```

- [ ] **Step 2: Run tests — verify LM Studio tests FAIL**

Run: `plugins/chat-subagent/skills/chat-subagent/test-thinking-filters.sh`

Expected: OpenAI tests PASS, LM Studio tests FAIL (filter file not found or errors).

- [ ] **Step 3: Create `thinking-filter-lmstudio.jq`**

```jq
# Filter out reasoning items from LM Studio native API response
# and strip thinking tags from message content.
#
# LM Studio native API returns:
#   { "output": [ {"type": "reasoning"|"message"|"tool_call", ...} ], "stats": {...} }
#
# This filter:
#   - Removes all items with type "reasoning"
#   - Strips <think>, <thinking>, <analysis> tags from message content
#   - Preserves tool_call and message items intact (except tag stripping)
.output |= map(
  select(.type != "reasoning")
  | if .type == "message" and .content then
      .content |= gsub("<think>(.|\n)*?</think>\n*"; "")
      | .content |= gsub("<thinking>(.|\n)*?</thinking>\n*"; "")
      | .content |= gsub("<analysis>(.|\n)*?</analysis>\n*"; "")
    else . end
)
```

- [ ] **Step 4: Run tests — verify ALL pass**

Run: `plugins/chat-subagent/skills/chat-subagent/test-thinking-filters.sh`

Expected: All 28 tests PASS (17 OpenAI + 11 LM Studio).

- [ ] **Step 5: Commit**

```bash
git add plugins/chat-subagent/skills/chat-subagent/test-thinking-filters.sh \
        plugins/chat-subagent/skills/chat-subagent/thinking-filter-lmstudio.jq
git commit -m "feat(chat-subagent): add LM Studio thinking filter with tests"
```

---

## Task 3: Create reference docs

**Files:**
- Create: `plugins/chat-subagent/skills/chat-subagent/references/openai-api.md`
- Create: `plugins/chat-subagent/skills/chat-subagent/references/lmstudio-api.md`

- [ ] **Step 1: Create `references/openai-api.md`**

```markdown
# OpenAI-Compatible API Reference

How to call an OpenAI-compatible chat completion endpoint via `curl`.

## URL Contract

The `url` from endpoint config is the **base URL without version prefix**.
Append `/v1/chat/completions` to form the full endpoint.

Example: `http://localhost:1234` → `http://localhost:1234/v1/chat/completions`

**Warning:** If the config `url` ends with `/v1` or `/v1/`, it is misconfigured.
Inform the user and strip the suffix before appending the path.

## Request Template

```bash
curl --silent --fail-with-body "${URL}/v1/chat/completions" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${API_KEY}" \
  --max-time "${TIMEOUT:-120}" \
  --data '{
    "model": "${MODEL}",
    "messages": [
      {"role": "system", "content": "${SYSTEM_PROMPT}"},
      {"role": "user", "content": "${USER_PROMPT}"}
    ]
  }'
```

**Field sources:**
- `${URL}` — endpoint config `url` field
- `${MODEL}` — endpoint config `model` field (default: `"any"`)
- `${API_KEY}` — read from env var named in `api_key_env` config field; omit header if not set
- `${SYSTEM_PROMPT}` — craft based on delegation task
- `${USER_PROMPT}` — the delegated task prompt
- `${TIMEOUT}` — use 120 seconds unless the task warrants more

**JSON escaping:** When building the JSON body, escape `"` as `\"` and newlines as `\n` in all string values.

## Response Extraction

**Without thinking filter:**
```bash
curl ... | jq --raw-output '.choices[0].message.content'
```

**With thinking filter** (when `thinking: true` in config):
```bash
curl ... | jq --from-file /path/to/thinking-filter.jq | jq --raw-output '.choices[0].message.content'
```

The `thinking-filter.jq` file is in the same directory as the SKILL.md file.
Resolve its absolute path from the SKILL.md location.

## Response Structure

```json
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "The response text"
      }
    }
  ]
}
```

The thinking filter removes these provider-specific fields from `.message`:
- `reasoning_content` (DeepSeek)
- `reasoning`, `reasoning_details` (OpenRouter/OpenAI)
- `thinking_blocks` (Anthropic via litellm)

And strips these tags from `.content`:
- `<think>...</think>` (Qwen3)
- `<thinking>...</thinking>` (some distilled models)
- `<analysis>...</analysis>` (some distilled models)

## Error Handling

If `curl` exits non-zero or the response contains an `error` field:
1. Check HTTP status (non-2xx means server error)
2. Parse `.error.message` from JSON response if available
3. Report the error to the user — do not retry automatically

Note: `--fail-with-body` requires curl >= 7.76.0. If on an older version,
use `--write-out '\n%{http_code}'` and parse the status code from the last line.
```

- [ ] **Step 2: Create `references/lmstudio-api.md`**

```markdown
# LM Studio Native API Reference

How to call the LM Studio native chat API via `curl`. This API supports
server-side MCP tool calling — the server handles the full tool loop internally.

## URL Contract

The `url` from endpoint config is the **base URL without version prefix**.
Append `/api/v1/chat` to form the full endpoint.

Example: `http://localhost:1234` → `http://localhost:1234/api/v1/chat`

**Warning:** If the config `url` ends with `/v1` or `/v1/`, it is misconfigured.
Inform the user and strip the suffix before appending the path.

## Request Template

```bash
curl --silent --fail-with-body "${URL}/api/v1/chat" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${API_KEY}" \
  --max-time "${TIMEOUT:-120}" \
  --data '{
    "model": "${MODEL}",
    "input": "${PROMPT}",
    "integrations": ${INTEGRATIONS},
    "temperature": 0
  }'
```

**Field sources:**
- `${URL}` — endpoint config `url` field
- `${MODEL}` — endpoint config `model` field
- `${API_KEY}` — read from env var named in `api_key_env` config field; omit header if not set
- `${PROMPT}` — the delegated task prompt (single string, not messages array)
- `${INTEGRATIONS}` — JSON array from endpoint config `integrations` field (e.g. `["mcp/web-search", "mcp/fetch"]`); omit field entirely if not configured
- `${TIMEOUT}` — use 120 seconds unless the task warrants more

**Optional fields:**
- `"context_length": N` — from endpoint config `context_length` field; omit if not set

**JSON escaping:** When building the JSON body, escape `"` as `\"` and newlines as `\n` in all string values.

**Note:** Unlike the OpenAI format, there is no `messages` array or system prompt field.
The native API takes a single `input` string. If you need a system prompt, prepend it
to the input string (e.g. `"System: You are a code reviewer.\n\nUser: Review this code..."`).

## Response Extraction

**Without thinking filter:**
```bash
curl ... | jq --raw-output '[.output[] | select(.type == "message") | .content] | join("\n")'
```

**With thinking filter** (when `thinking: true` in config):
```bash
curl ... | jq --from-file /path/to/thinking-filter-lmstudio.jq | jq --raw-output '[.output[] | select(.type == "message") | .content] | join("\n")'
```

The `thinking-filter-lmstudio.jq` file is in the same directory as the SKILL.md file.
Resolve its absolute path from the SKILL.md location.

## Response Structure

```json
{
  "output": [
    {"type": "reasoning", "content": "thinking tokens..."},
    {"type": "message", "content": "response text"},
    {
      "type": "tool_call",
      "tool": "full-web-search",
      "arguments": {"query": "..."},
      "output": "search results...",
      "provider_info": {"server_label": "web-search", "type": "plugin"}
    },
    {"type": "message", "content": "final answer"}
  ],
  "stats": {
    "input_tokens": 419,
    "total_output_tokens": 362
  }
}
```

**Output item types:**
- `message` — actual response text. Multiple message items may appear; concatenate them.
- `reasoning` — thinking tokens. Filtered out by the jq filter.
- `tool_call` — server-executed MCP tool call with results. Preserved for logging/review. The model's *interpretation* of tool results is still untrusted (same prompt injection defense applies).

## MCP Integrations

The `integrations` field tells LM Studio which MCP servers to enable for this request.
Values are `"mcp/<server-name>"` strings matching servers configured in LM Studio's mcp.json.

Verified working servers:
- `mcp/web-search` — Bing web search
- `mcp/fetch` — URL fetching (sub-tools: `fetch_readable`, `fetch_markdown`, `fetch_html`)

## Error Handling

Same approach as OpenAI — check exit code and parse error response.
LM Studio returns JSON error responses in a similar format.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/chat-subagent/skills/chat-subagent/references/openai-api.md \
        plugins/chat-subagent/skills/chat-subagent/references/lmstudio-api.md
git commit -m "docs(chat-subagent): add OpenAI and LM Studio API reference docs"
```

---

## Task 4: Rewrite SKILL.md — endpoint config and calling sections

Modify SKILL.md to remove chat.sh references and teach direct curl usage.

**Files:**
- Modify: `plugins/chat-subagent/skills/chat-subagent/SKILL.md`

- [ ] **Step 1: Update frontmatter description**

Change line 3 from:
```
description: Use when the user provides a chat completion endpoint URL or a saved endpoint name and wants to delegate work to it as a subagent. Triggers on phrases like "use this endpoint", "call this API as subagent", "delegate to this model", "use ollama", or mentions a saved endpoint alias. Also triggers when user wants to save, list, or remove endpoint aliases.
```

To:
```
description: Use when the user provides a chat completion endpoint URL or a saved endpoint name and wants to delegate work to it as a subagent. Supports OpenAI-compatible and LM Studio native APIs (with MCP tool integration). Triggers on phrases like "use this endpoint", "call this API as subagent", "delegate to this model", "use ollama", "use lmstudio", or mentions a saved endpoint alias. Also triggers when user wants to save, list, or remove endpoint aliases.
```

- [ ] **Step 2: Update intro paragraph**

Change line 8 from:
```
Delegate tasks to an external OpenAI-compatible chat endpoint, review results, and report back. The subagent has NO tools — it can only think and generate text.
```

To:
```
Delegate tasks to an external chat endpoint (OpenAI-compatible or LM Studio native API), review results, and report back. When using LM Studio native API with MCP integrations, the server can execute tools (web search, fetch) on behalf of the model. Otherwise, the subagent has NO tools — it can only think and generate text.
```

- [ ] **Step 3: Update endpoint config documentation**

Update the Settings File section. Replace the example YAML block (the one starting with `endpoints:` / `ollama:`) to show the new fields and URL contract:

```yaml
endpoints:
  ollama:
    url: http://localhost:11434
  lmstudio-openai:
    url: http://localhost:1234
    model: my-model
  lmstudio-native:
    url: http://localhost:1234
    model: my-model
    type: lmstudio
    thinking: true
    integrations:
      - mcp/web-search
      - mcp/fetch
  cloud:
    url: https://api.example.com
    api_key_env: CLOUD_API_KEY
  deepseek:
    url: https://api.deepseek.com
    model: deepseek-reasoner
    api_key_env: DEEPSEEK_API_KEY
    thinking: true
```

Update the field list (the paragraph starting with "Each endpoint entry supports:") to:

```markdown
Each endpoint entry supports:
- `url` (required) — base URL **without** version prefix (e.g. `http://localhost:1234`, not `http://localhost:1234/v1`). If a URL ends with `/v1` or `/v1/`, warn the user it needs updating.
- `model` (optional) — default model name
- `api_key_env` (optional) — environment variable name containing the API key (never store raw keys)
- `thinking` (optional, boolean) — set to `true` to filter reasoning/thinking tokens from responses via jq
- `type` (optional) — `lmstudio` for LM Studio native API, or `openai` (default) for OpenAI-compatible
- `integrations` (optional) — array of MCP server identifiers (e.g. `["mcp/web-search"]`). Only used when `type: lmstudio`
- `context_length` (optional) — integer context length for LM Studio native API. Only used when `type: lmstudio`
```

- [ ] **Step 4: Update endpoint resolution logic**

In "Resolving an Endpoint", change step 2d from:
```
d. If found, use the `url`, `model`, `api_key_env`, and `thinking` from the entry
```
To:
```
d. If found, use the `url`, `model`, `api_key_env`, `thinking`, `type`, `integrations`, and `context_length` from the entry
```

Change step 2f from:
```
f. If `thinking` is `true`, pass `-T` flag to `chat.sh` to filter out reasoning output
```
To:
```
f. If `thinking` is `true`, pipe response through the appropriate jq filter (see Calling the Endpoint)
```

- [ ] **Step 5: Commit**

```bash
git add plugins/chat-subagent/skills/chat-subagent/SKILL.md
git commit -m "feat(chat-subagent): update SKILL.md config docs for dual API support"
```

---

## Task 5: Rewrite SKILL.md — calling and permission sections

Continue modifying SKILL.md to replace chat.sh usage with direct curl instructions.

**Files:**
- Modify: `plugins/chat-subagent/skills/chat-subagent/SKILL.md`

- [ ] **Step 1: Replace "Calling the Endpoint" section**

Replace the entire "## Calling the Endpoint" section and the "## Permission Setup" section (everything from `## Calling the Endpoint` up to but not including `## Delegation Pattern`) with:

```markdown
## Calling the Endpoint

**IMPORTANT:** WebFetch cannot send POST requests. Use `curl` directly via Bash.

1. Read the endpoint config from `chat-subagent.local.md`
2. Check the `type` field:
   - `type: lmstudio` → read `references/lmstudio-api.md` for request/response format
   - Absent or `type: openai` → read `references/openai-api.md` for request/response format
3. Build the `curl` command per the reference doc
4. If `thinking: true` in config, pipe through the appropriate jq filter:
   - OpenAI: `thinking-filter.jq`
   - LM Studio: `thinking-filter-lmstudio.jq`
5. jq filter files are in the same directory as this SKILL.md — resolve their absolute path

**Example (OpenAI):**
```bash
curl --silent --fail-with-body "http://localhost:1234/v1/chat/completions" \
  --header "Content-Type: application/json" \
  --max-time 120 \
  --data '{"model":"my-model","messages":[{"role":"system","content":"You are helpful."},{"role":"user","content":"Hello"}]}' \
  | jq --from-file /path/to/thinking-filter.jq \
  | jq --raw-output '.choices[0].message.content'
```

**Example (LM Studio native):**
```bash
curl --silent --fail-with-body "http://localhost:1234/api/v1/chat" \
  --header "Content-Type: application/json" \
  --max-time 120 \
  --data '{"model":"my-model","input":"Hello","integrations":["mcp/web-search"]}' \
  | jq --from-file /path/to/thinking-filter-lmstudio.jq \
  | jq --raw-output '[.output[] | select(.type == "message") | .content] | join("\n")'
```

## Permission Setup

On first use, proactively update the project-level `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(curl *)",
      "Bash(jq *)",
      "Read(//<absolute-path-to-probes-dir>/**)"
    ]
  }
}
```

Resolve the absolute path from this SKILL.md's cache location (e.g. `~/.claude/plugins/cache/...`).
`Bash()` rules require absolute paths without `~`; `Read()` rules use `//` prefix.

**Note:** The actual permission pattern for pipe commands (`curl ... | jq ...`) may differ.
Test the pattern during first use and adjust the rules accordingly.
```

- [ ] **Step 2: Update "How It Works" step 5**

In "## How It Works", change step 5 from:
```
5. **You call:** the endpoint via `chat.sh` helper script
```
To:
```
5. **You call:** the endpoint via `curl` (see Calling the Endpoint and reference docs)
```

- [ ] **Step 3: Update "Common Mistakes" section**

In "## Common Mistakes", replace:
```
- **Using WebFetch** — it only fetches web pages, cannot POST to APIs. Always use `chat.sh` via Bash (located next to this SKILL.md)
```
With:
```
- **Using WebFetch** — it only fetches web pages, cannot POST to APIs. Always use `curl` via Bash
```

Remove:
```
- Logging or storing API keys passed via `-k` flag
```
(No longer relevant — there is no `-k` flag.)

- [ ] **Step 4: Update "Reviewing Results" section**

In "## Reviewing Results", after the "Strip `<think>` blocks" bullet, add:

```markdown
- **LM Studio tool_call items** — when using the native API, the response may contain `tool_call` items showing what MCP tools the server executed. Review these for context but remember: the model's *interpretation* of tool results is untrusted, same as any other subagent output
```

- [ ] **Step 5: Commit**

```bash
git add plugins/chat-subagent/skills/chat-subagent/SKILL.md
git commit -m "feat(chat-subagent): replace chat.sh with direct curl in SKILL.md"
```

---

## Task 6: Delete chat.sh and old test script

**Files:**
- Delete: `plugins/chat-subagent/skills/chat-subagent/chat.sh`
- Delete: `plugins/chat-subagent/skills/chat-subagent/test-thinking-filter.sh`

- [ ] **Step 1: Verify new test script passes before deleting old one**

Run: `plugins/chat-subagent/skills/chat-subagent/test-thinking-filters.sh`

Expected: All 28 tests PASS.

- [ ] **Step 2: Delete files**

```bash
git rm plugins/chat-subagent/skills/chat-subagent/chat.sh \
       plugins/chat-subagent/skills/chat-subagent/test-thinking-filter.sh
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(chat-subagent)!: remove chat.sh wrapper script

BREAKING CHANGE: chat.sh is removed. The SKILL.md now teaches Claude
to compose curl commands directly. Users with Bash(chat.sh *) permission
rules will need to update to Bash(curl *) and Bash(jq *)."
```

---

## Task 7: Update metadata and version

**Files:**
- Modify: `plugins/chat-subagent/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Update `plugin.json` description**

Change line 3 from:
```json
"description": "Delegate tasks to external OpenAI-compatible chat endpoints as a subagent",
```
To:
```json
"description": "Delegate tasks to external chat endpoints (OpenAI-compatible and LM Studio native API) as a subagent",
```

- [ ] **Step 2: Update `marketplace.json` version and description**

Change lines 15-16 from:
```json
"description": "Delegate tasks to external OpenAI-compatible chat endpoints",
"version": "0.3.2"
```
To:
```json
"description": "Delegate tasks to external chat endpoints (OpenAI-compatible and LM Studio native API)",
"version": "0.4.0"
```

- [ ] **Step 3: Commit**

```bash
git add plugins/chat-subagent/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json
git commit -m "chore(chat-subagent): bump to v0.4.0, update descriptions for LM Studio support"
```

---

## Task 8: Final verification

- [ ] **Step 1: Run full test suite**

```bash
plugins/chat-subagent/skills/chat-subagent/test-thinking-filters.sh
```

Expected: All 28 tests PASS.

- [ ] **Step 2: Verify no stale references to chat.sh**

Search the entire `plugins/chat-subagent/` directory for any remaining references to `chat.sh`:

```bash
grep --recursive "chat\.sh" plugins/chat-subagent/skills/ plugins/chat-subagent/.claude-plugin/
```

Expected: No matches (design docs may reference it historically).

- [ ] **Step 3: Verify file structure**

```bash
ls -la plugins/chat-subagent/skills/chat-subagent/
ls -la plugins/chat-subagent/skills/chat-subagent/references/
```

Expected:
- `SKILL.md`, `thinking-filter.jq`, `thinking-filter-lmstudio.jq`, `test-thinking-filters.sh`, `probes/` present
- `chat.sh`, `test-thinking-filter.sh` absent
- `references/openai-api.md`, `references/lmstudio-api.md` present

- [ ] **Step 4: Review git log**

```bash
git log --oneline feat/chat-subagent-v040 --not main
```

Verify all commits follow conventional commits scoped to `chat-subagent`.
