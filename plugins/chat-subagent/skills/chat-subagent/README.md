# chat-subagent

A Claude Code skill that lets you delegate tasks to external chat endpoints (OpenAI-compatible and LM Studio native API). Probe capabilities first, then delegate with awareness of what can go wrong.

## What it does

- Calls OpenAI-compatible (`/v1/chat/completions`) or LM Studio native (`/api/v1/chat`) endpoints via `curl` directly — no wrapper scripts needed
- LM Studio native API supports server-side MCP tool calling (web search, fetch)
- Filters out thinking/reasoning output from responses via `jq` — supports DeepSeek, OpenAI, OpenRouter, Anthropic (via litellm), Qwen3 `<think>` blocks, and LM Studio native reasoning items
- Probes the remote model's abilities before trusting it with real work (reasoning, instruction-following, counting, coding)
- Provides delegation patterns: what to offload vs. what to keep local
- Includes prompt injection awareness (not a guarantee — just practical guardrails)

## Who this is for

- **Local model users** — already running Ollama, LM Studio, or vLLM and want Claude to orchestrate them
- **Cost-conscious developers** — offload low-value tasks to cheaper models
- **Privacy-minded users** — keep some processing on local infrastructure
- **Multi-model experimenters** — exploring how different models can collaborate

## What it is not

This is not a security solution. Prompt injection from untrusted model responses is a hard problem. The skill includes practical heuristics (red flag detection, expect-then-verify pattern, factual claim skepticism) but does not claim to be foolproof.

## Install

```bash
claude plugin marketplace add caasi/dong3
claude plugin install chat-subagent@caasi-dong3
```

## Usage

Once installed, tell Claude something like:

> "Use `http://localhost:11434` as a subagent to help analyze this code."

Claude will:

1. **Probe** the endpoint with a few diagnostic questions
2. **Report** what the model is good/bad at
3. **Delegate** appropriate tasks based on probe results
4. **Review** responses before acting on them

### Endpoint aliases

Save endpoints so you don't have to type full URLs every time. Create `~/.claude/chat-subagent.local.md` (global) or `<project>/.claude/chat-subagent.local.md` (per-project):

```yaml
---
endpoints:
  homelab:
    url: http://localhost:1234
    model: my-model
    thinking: true              # auto-filter thinking output
  homelab-native:
    url: http://localhost:1234
    model: my-model
    type: lmstudio              # use LM Studio native API
    thinking: true
    integrations:               # MCP servers to enable
      - mcp/web-search
      - mcp/fetch
  cloud:
    url: https://api.example.com
    api_key_env: MY_API_KEY     # reads from env var
---
```

**Note:** The `url` field is the base URL **without** `/v1` prefix. The skill appends the correct path automatically based on `type`.

Then just say: *"Use homelab to analyze this code."*

### Thinking output filtering

Models like DeepSeek, Qwen3, and OpenAI o-series produce reasoning tokens alongside their answers. Setting `thinking: true` in endpoint aliases filters these out via `jq`:

**JSON fields** (removed from `choices[].message`):
- `reasoning_content` (DeepSeek)
- `reasoning`, `reasoning_details` (OpenRouter / OpenAI)
- `thinking_blocks` (Anthropic via litellm)

**XML blocks** (stripped from `content`):
- `<think>...</think>` — Qwen3 official thinking format
- `<thinking>...</thinking>` — observed in distilled models (e.g. Claude-Opus-Reasoning-Distilled)
- `<analysis>...</analysis>` — observed in distilled models

> **Note on distilled models:** Models fine-tuned on Claude reasoning traces (like `Qwen3.5-*-Claude-4.6-Opus-Reasoning-Distilled`) are trained to use `<think>` tags, but occasionally emit `<thinking>` or `<analysis>` blocks as well. These are not part of the official Qwen3 format — they leak from the distillation source. The filter handles all three.

Requires `jq`. For LM Studio native API responses, the filter also removes `type: reasoning` items from the `output[]` array.

Only activates when `thinking: true` is set in the endpoint config.

### Permission setup

Claude Code will prompt for permission on the first `curl` call and probe file reads. Allow it once, and Claude will update the project-level `.claude/settings.local.json` to cover all future calls automatically.

You can also set it up manually:

```json
{
  "permissions": {
    "allow": [
      "Bash(curl *)",
      "Bash(jq *)",
      "Read(//<HOME>/.claude/plugins/cache/caasi-dong3/chat-subagent/<VERSION>/skills/chat-subagent/probes/**)"
    ]
  }
}
```

Replace `<HOME>` with your home directory and `<VERSION>` with the installed version (e.g. `0.4.0`).

**Note:** `Bash(curl *)` and `Bash(jq *)` are system-wide wildcards that permit all `curl`/`jq` invocations, not just those from this skill. If you prefer tighter control, omit these rules and rely on Claude Code's per-invocation permission prompts instead.

## Probe system

The skill includes 19 diagnostic questions in `probes/`, each ~3 lines:

| Prefix | Category | Tests |
|--------|----------|-------|
| `r1`–`r6` | Reasoning | Logic traps, probability, optimization |
| `i1`–`i4` | Instruction following | Format constraints, negative constraints |
| `c1`–`c5` | Counting & spatial | Letter counting, number comparison, state tracking |
| `d1`–`d4` | Coding | Algorithms, spec compliance, data transformation |

Each question has a known correct answer. Claude picks 1 per relevant category, sends them, and grades the results before deciding what to delegate.

Questions sourced from:
- [Easy Problems That LLMs Get Wrong](https://arxiv.org/abs/2405.19616) (Williams et al., 2024)
- [LLM Test Questions](https://mer.vin/2024/09/llm-test-questions/) (Mervin Praison, 2024)

## Lessons learned (from real usage)

These are baked into the skill based on actual testing:

- **Subagents hallucinate facts confidently.** Never delegate factual queries. Use them for reasoning and analysis over data you provide.
- **"Be concise" is mandatory.** Without it, responses are 3-5x longer than needed.
- **Probe results predict real performance.** A model weak on instruction-following in probes will fail format constraints in real tasks too.
- **Thinking blocks leak in various formats.** Qwen3 uses `<think>`, but distilled models (especially those fine-tuned on Claude reasoning traces) may also emit `<thinking>` or `<analysis>` blocks. Set `thinking: true` in endpoint aliases to filter all variants automatically.
- **WebFetch can't POST.** The skill uses `curl` via Bash instead.

## License

MIT
