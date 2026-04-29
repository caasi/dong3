# dong3

A Claude Code plugin marketplace by [caasi](https://github.com/caasi).

## Skills

### chat-subagent

Delegate tasks to external OpenAI-compatible chat endpoints with capability probing, delegation patterns, and prompt injection awareness.

See [plugins/chat-subagent/skills/chat-subagent/README.md](plugins/chat-subagent/skills/chat-subagent/README.md) for full documentation.

### compose

Describe multi-step agent workflows using an Arrow-style DSL and validate them structurally with the `ocaml-compose-dsl` binary. The DSL is a planning language — the agent expands it into concrete tool calls.

See [plugins/compose/skills/compose/README.md](plugins/compose/skills/compose/README.md) for full documentation.

### constraint

Natural language constraints → deterministic test artifacts. Write constraints in structured Markdown (`constraints/*.md` with Given/When/Then/Unless/Examples/Properties), generate unit tests / PBT / mutation tests, and enforce with a 4-layer deterministic pipeline.

- [constraint-write](plugins/constraint/skills/constraint-write/README.md) — conversational constraint authoring
- [constraint-generate](plugins/constraint/skills/constraint-generate/README.md) — artifact generation (TypeScript)
- [constraint-enforce](plugins/constraint/skills/constraint-enforce/README.md) — enforcement pipeline

### fetch-tips

Platform-specific fetch strategies for content that resists simple WebFetch. Currently covers Blogspot/Blogger via JSON Feed API.

See [plugins/fetch-tips/skills/blogspot/README.md](plugins/fetch-tips/skills/blogspot/README.md) for full documentation.

### kami

Reflect on human-AI stewardship through Socratic dialogue. A mirror, not a checklist — rooted in Audrey Tang's Humane Intelligence framework and Civic AI 6-Pack of Care.

See [plugins/kami/skills/kami/README.md](plugins/kami/skills/kami/README.md) for full documentation.

### old-react

FP-thinking review and refactor for pre-RSC React (classes, hooks, Redux/MobX/observable, Reselect, Immer). Ships only architectural rules where neither TypeScript nor `eslint-plugin-react-hooks` already enforces the principle: state ownership (SSOT for remote state, derive-don't-store, controlled-by-default), effects-as-data (emit named actions, setup/cleanup pairing), and composition (leaf purity, effects at the page boundary — i.e. Functional Core / Imperative Shell). One slash command: `/old-react [review|refactor] [path]`.

See [plugins/old-react/skills/old-react/README.md](plugins/old-react/skills/old-react/README.md) for full documentation.

### owasp

Security review using OWASP frameworks with offline reference data from 8 Top 10 projects (Web, API, LLM, MCP, Agentic, Mobile, CI/CD, Kubernetes) and a CheatSheetSeries index.

See [plugins/owasp/skills/owasp/README.md](plugins/owasp/skills/owasp/README.md) for full documentation.

## Install

```bash
claude plugin marketplace add caasi/dong3
```

## License

MIT
