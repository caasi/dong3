# dong3

A Claude Code plugin marketplace by [caasi](https://github.com/caasi).

## Skills

### chat-subagent

Delegate tasks to external OpenAI-compatible chat endpoints with capability probing, delegation patterns, and prompt injection awareness.

See [skills/chat-subagent/README.md](skills/chat-subagent/README.md) for full documentation.

### compose

Describe multi-step agent workflows using an Arrow-style DSL and validate them structurally with the `ocaml-compose-dsl` binary. The DSL is a planning language — the agent expands it into concrete tool calls.

See [skills/compose/SKILL.md](skills/compose/SKILL.md) for full documentation.

## Install

```bash
# 1. Add the marketplace
claude plugin marketplace add caasi/dong3

# 2. Install a plugin
claude plugin install chat-subagent@caasi-dong3
```

## License

MIT
