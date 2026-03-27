# chat-subagent: Remove chat.sh, Add LM Studio Native API Support

> Spec for removing the `chat.sh` wrapper script and teaching Claude to call OpenAI-compatible and LM Studio native APIs directly via `curl`, with `jq` filters for token reduction.

## Problem

`chat.sh` is a bash wrapper that users must install alongside the plugin. This adds friction — the plugin should be zero-install beyond Claude Code itself. Additionally, `chat.sh` only speaks OpenAI-compatible format (`/v1/chat/completions`). LM Studio has a native API (`/api/v1/chat`) that supports server-side MCP tool calling, which the current plugin cannot use.

## Goals

1. **Remove `chat.sh`** — SKILL.md teaches Claude to compose `curl` commands directly
2. **Keep `jq`** — pipe responses through jq filters to strip reasoning/thinking tokens before they enter Claude's context (token savings)
3. **Dual API support** — OpenAI-compatible and LM Studio native, selected by config `type` field
4. **Zero new dependencies** — `curl` and `jq` are available on all target platforms (macOS, Linux)

## Non-Goals

- Ephemeral MCP server support (future work)
- Multi-turn conversation via LM Studio native API (single-shot is sufficient for subagent delegation)
- Streaming support
- Replacing `jq` with Claude-side JSON parsing

## Core Discovery: LM Studio Dual API

LM Studio exposes two APIs:

| | OpenAI-compatible | LM Studio native |
|---|---|---|
| Endpoint | `/v1/chat/completions` | `/api/v1/chat` |
| Input | `messages` array | `input` string |
| MCP tools | Not supported | `integrations` field |
| Auth | Bearer token | Bearer token (same) |
| Response | `choices[0].message.content` | `output[]` typed array |
| Tool loop | Client must handle | Server handles end-to-end |

### Native API Request Format

```bash
curl --silent --fail-with-body "http://<host>:1234/api/v1/chat" \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "model": "<model-id>",
    "input": "your prompt here",
    "integrations": ["mcp/web-search", "mcp/fetch"],
    "context_length": 8000,
    "temperature": 0
  }'
```

### Native API Response Format

```json
{
  "output": [
    {"type": "reasoning", "content": "thinking tokens..."},
    {"type": "message", "content": "initial response..."},
    {
      "type": "tool_call",
      "tool": "full-web-search",
      "arguments": {"query": "..."},
      "output": "search results...",
      "provider_info": {"server_label": "web-search", "type": "plugin"}
    },
    {"type": "reasoning", "content": "more thinking..."},
    {"type": "message", "content": "final answer incorporating tool results"}
  ],
  "stats": {
    "input_tokens": 419,
    "total_output_tokens": 362,
    "reasoning_output_tokens": 195,
    "tokens_per_second": 27.6,
    "time_to_first_token_seconds": 1.4
  }
}
```

`output` is a typed array with interleaved items: `message`, `tool_call`, `reasoning`.

### MCP Integration Modes

| | Ephemeral | mcp.json |
|---|---|---|
| Request format | `{"type": "ephemeral_mcp", "server_label": "...", "server_url": "..."}` | `"mcp/<server-name>"` string |
| Configuration | Per-request | Pre-configured in LM Studio's mcp.json |
| Use case | Remote MCP, one-off | Local MCP, frequently used servers |

Only mcp.json mode is in scope for this spec.

## Design

### File Changes

```
plugins/chat-subagent/skills/chat-subagent/
  SKILL.md                          # MODIFY: remove chat.sh usage, teach curl directly
  thinking-filter.jq                # KEEP: OpenAI format filter (unchanged)
  thinking-filter-lmstudio.jq       # ADD: LM Studio native format filter
  references/
    openai-api.md                   # ADD: OpenAI curl template + response parsing
    lmstudio-api.md                 # ADD: LM Studio native curl template + response parsing

  chat.sh                           # DELETE
  test-thinking-filter.sh           # DELETE
```

### SKILL.md Changes

**Remove:**
- "Calling the Endpoint" section (chat.sh usage)
- Permission setup section (chat.sh-specific Bash rules)

**Replace "Calling the Endpoint" with:**

```markdown
## Calling the Endpoint

Use `curl` directly via Bash. Do NOT use WebFetch (it cannot POST).

1. Read the endpoint config from `chat-subagent.local.md`
2. Check the `type` field:
   - `type: lmstudio` → read `references/lmstudio-api.md`
   - Absent or `type: openai` → read `references/openai-api.md`
3. Build the curl command per the reference doc
4. If `thinking: true` in config, pipe through the appropriate jq filter
5. jq filter files are in the same directory as this SKILL.md
```

**Replace permission setup with:**

```markdown
## Permission Setup

On first use, proactively update the project-level `.claude/settings.local.json`:

{
  "permissions": {
    "allow": [
      "Bash(curl *)",
      "Bash(jq *)",
      "Read(//<absolute-path-to-probes-dir>/**)"
    ]
  }
}

Resolve the absolute path from this SKILL.md's cache location.
Note: pipe commands (curl ... | jq ...) may require the full pattern to match.
Verify actual permission requirements during implementation.
```

### chat.sh Responsibilities → New Owner

| chat.sh feature | New handling |
|---|---|
| Auto-append `/chat/completions` path | Reference docs specify full paths |
| `-s` system prompt | Claude builds `messages` array / `input` string directly |
| `-m` model | Claude reads `model` from config, puts in JSON body |
| `-k` API key | Claude reads env var specified by `api_key_env` config field |
| `-t` timeout | Claude adds `--max-time` to curl |
| `-T` thinking filter | Claude checks `thinking: true` in config, pipes through jq |
| Error handling | Claude uses `curl --fail-with-body` and checks exit code |

### references/openai-api.md

Covers:
- Full curl template for `POST {url}/v1/chat/completions`
- How to build `messages` array (system + user messages)
- Authentication via `Authorization: Bearer` header
- Response structure: `.choices[0].message.content`
- Thinking filter: pipe through `thinking-filter.jq` (same directory as SKILL.md)
- Example jq extraction: `jq -f /path/to/thinking-filter.jq | jq --raw-output '.choices[0].message.content'`

### references/lmstudio-api.md

Covers:
- Full curl template for `POST {url}/api/v1/chat`
- `input` string format (replaces `messages` array)
- `integrations` array from config
- `context_length` parameter
- Authentication (same Bearer token scheme)
- Response structure: `.output[]` typed array
- Thinking filter: pipe through `thinking-filter-lmstudio.jq`
- Example jq extraction: `jq -f /path/to/thinking-filter-lmstudio.jq | jq --raw-output '[.output[] | select(.type == "message") | .content] | join("\n")'`
- MCP tool call items in response (for logging/review, not execution)

### thinking-filter-lmstudio.jq

```jq
# Filter out reasoning items from LM Studio native API response
# and strip thinking tags from message content
.output |= map(
  select(.type != "reasoning")
  | if .type == "message" and .content then
      .content |= gsub("<think>(.|\n)*?</think>\n*"; "")
      | .content |= gsub("<thinking>(.|\n)*?</thinking>\n*"; "")
      | .content |= gsub("<analysis>(.|\n)*?</analysis>\n*"; "")
    else . end
)
```

### Config Format

Extends existing `chat-subagent.local.md` with `type` and `integrations` fields:

```yaml
endpoints:
  homelab:
    url: http://192.168.50.50:1234
    model: qwen3.5-9b
    type: lmstudio
    thinking: true
    api_key_env: LM_STUDIO_API_KEY
    integrations:
      - mcp/web-search
      - mcp/fetch
  cloud:
    url: https://api.deepseek.com/v1
    model: deepseek-reasoner
    type: openai
    thinking: true
    api_key_env: DEEPSEEK_API_KEY
```

- `type` (optional): `lmstudio` or `openai`. Defaults to `openai` if absent.
- `integrations` (optional): array of MCP server identifiers. Only used when `type: lmstudio`.

### Unchanged

- Probe flow (plain text in/out, works with both APIs)
- Delegation pattern
- Prompt injection defense (native API adds server-executed tool calls — model interpretation still untrusted, same review protocol)
- Endpoint alias management (save/list/remove)
- `thinking-filter.jq` (existing file, no changes)

## Verified MCP Tools

Tested on homelab (LM Studio 0.4.x):

- `mcp/web-search` — Bing web search, returns structured results
- `mcp/fetch` — URL fetching, model auto-selects sub-tools: `fetch_readable`, `fetch_markdown`, `fetch_html`, `get-single-web-page-content`

## Documentation Source

https://lmstudio.ai/docs/developer/core/mcp
