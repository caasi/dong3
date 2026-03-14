# chat-subagent

A Claude Code skill that lets you delegate tasks to external OpenAI-compatible chat endpoints. Probe capabilities first, then delegate with awareness of what can go wrong.

## What it does

- Calls any OpenAI-compatible `/v1/chat/completions` endpoint via a lightweight bash script (`curl` only, zero dependencies)
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
claude plugin add caasi/chat-subagent
```

## Usage

Once installed, tell Claude something like:

> "Use `http://localhost:11434/v1` as a subagent to help analyze this code."

Claude will:

1. **Probe** the endpoint with a few diagnostic questions
2. **Report** what the model is good/bad at
3. **Delegate** appropriate tasks based on probe results
4. **Review** responses before acting on them

### Permission setup

Claude Code prompts for each `chat.sh` call because arguments differ. Add this allow rule once to skip repeated prompts:

```
Bash(/path/to/chat.sh *)
```

Add via Settings > Permissions > Allow, or in `~/.claude/settings.local.json` under `permissions.allow`.

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
- **`<think>` blocks leak.** Some models include chain-of-thought in their output. The skill instructs Claude to filter these out.
- **WebFetch can't POST.** The skill uses a bash script with `curl` instead.

## License

MIT
