# chat-subagent

A Claude Code skill that lets you delegate tasks to external OpenAI-compatible chat endpoints. Probe capabilities first, then delegate with awareness of what can go wrong.

## What it does

- Calls any OpenAI-compatible `/v1/chat/completions` endpoint via a lightweight bash script (`curl` only, `jq` optional)
- Filters out thinking/reasoning output from responses (`-T` flag) — supports DeepSeek, OpenAI, OpenRouter, Anthropic (via litellm), and Qwen3 `<think>` blocks
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

> "Use `http://localhost:11434/v1` as a subagent to help analyze this code."

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
    url: http://localhost:1234/v1
    model: my-model
    thinking: true        # auto-filter thinking output
  cloud:
    url: https://api.example.com/v1
    api_key_env: MY_API_KEY  # reads from env var
---
```

Then just say: *"Use homelab to analyze this code."*

### Thinking output filtering

Models like DeepSeek, Qwen3, and OpenAI o-series produce reasoning tokens alongside their answers. The `-T` flag (or `thinking: true` in aliases) filters these out:

**JSON fields** (removed from `choices[].message`):
- `reasoning_content` (DeepSeek)
- `reasoning`, `reasoning_details` (OpenRouter / OpenAI)
- `thinking_blocks` (Anthropic via litellm)

**XML blocks** (stripped from `content`):
- `<think>...</think>` — Qwen3 official thinking format
- `<thinking>...</thinking>` — observed in distilled models (e.g. Claude-Opus-Reasoning-Distilled)
- `<analysis>...</analysis>` — observed in distilled models

> **Note on distilled models:** Models fine-tuned on Claude reasoning traces (like `Qwen3.5-*-Claude-4.6-Opus-Reasoning-Distilled`) are trained to use `<think>` tags, but occasionally emit `<thinking>` or `<analysis>` blocks as well. These are not part of the official Qwen3 format — they leak from the distillation source. The filter handles all three.

Requires `jq`. Only activates when `-T` is passed.

### Permission setup

Claude Code will prompt for permission on the first `chat.sh` call and probe file reads. Allow it once, and Claude will update the project-level `.claude/settings.local.json` to cover all future calls automatically.

You can also set it up manually. Replace `<HOME>` with your home directory and `<VERSION>` with the installed version (e.g. `0.1.1`). Permissions target the **cache** folder, which is where Claude Code resolves scripts from at runtime:

```json
{
  "permissions": {
    "allow": [
      "Bash(<HOME>/.claude/plugins/cache/caasi-dong3/chat-subagent/<VERSION>/skills/chat-subagent/chat.sh *)",
      "Read(//<HOME>/.claude/plugins/cache/caasi-dong3/chat-subagent/<VERSION>/skills/chat-subagent/probes/**)"
    ]
  }
}
```

**Note:** After updating the plugin, the cache path changes with the new version number. You will need to allow permissions again or update the version in your rules.

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
- **Thinking blocks leak in various formats.** Qwen3 uses `<think>`, but distilled models (especially those fine-tuned on Claude reasoning traces) may also emit `<thinking>` or `<analysis>` blocks. Use `-T` flag or set `thinking: true` in endpoint aliases to filter all variants automatically.
- **WebFetch can't POST.** The skill uses a bash script with `curl` instead.

## License

MIT
