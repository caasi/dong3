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

FP-thinking review and refactor for pre-RSC React (classes, hooks, Redux/MobX/observable, Reselect, Immer). Ships only architectural rules where neither TypeScript nor `eslint-plugin-react-hooks` already enforces the principle. Five active categories: state architecture (`model-`), effects (`effect-`), composition (`compose-`), render purity (`purity-`), and hook applicability (`hooks-`). Two categories (`immutable-`, `message-`) defer to existing tooling. One slash command: `/old-react [review|refactor] [path]`.

See [plugins/old-react/skills/old-react/README.md](plugins/old-react/skills/old-react/README.md) and [SKILL.md](plugins/old-react/skills/old-react/SKILL.md) for the canonical rule list.

### owasp

Security review using OWASP frameworks with offline reference data from 8 Top 10 projects (Web, API, LLM, MCP, Agentic, Mobile, CI/CD, Kubernetes) and a CheatSheetSeries index.

See [plugins/owasp/skills/owasp/README.md](plugins/owasp/skills/owasp/README.md) for full documentation.

### review-loop

Assisted (not autonomous) multi-reviewer convergence loop for any change — code or design artifacts. Local reviewers run first (a Claude subagent always, plus headless Codex via `codex exec review` when `codex` is on `PATH`), then GitHub Copilot for PR targets. Classifies comments into tiers, auto-fixes the mechanical ones, pauses for your judgment on the architectural ones, and never merges on its own. One slash command: `/review-loop [PR# | branch | blank]`.

See [plugins/review-loop/skills/review-loop/README.md](plugins/review-loop/skills/review-loop/README.md) for full documentation.

### tsugu

A git-native skill for unattended work preparation and human–agent convergence. Using git's DAG as the coordination substrate, an agent prepares engineering work privately on git branches (often while you are away), records evidence in committed `.tsugu/` notes, and packages a convergence packet; when you return you converge — review the prepared evidence, decide together what becomes public, and complete the disposition in the same session (cut a handoff branch / open a PR, human-gated — the merge lands when you approve it). Three routines: `init` (set up or migrate the repo's `.tsugu/` workspace + `policy.md`), `prepare` (private git work on the configured work prefixes — defaults `prepare/* investigate/* review/*` — + tests + evidence while you are absent), `converge` (present the packet, decide with you, and complete the disposition + a read-only morning status view). State is derived from refs and the DAG, not stored in status fields, so **merge commits are recommended**; `.tsugu/` MAY land on the mainline by default (`public-branch-tsugu: include|exclude`). Never auto-merges; light and script-free; invokes no user-installed skill by default (per-repo `policy.md` may opt-in). Three slash commands: `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`.

See [plugins/tsugu/skills/tsugu/README.md](plugins/tsugu/skills/tsugu/README.md) for full documentation.

## Install

```bash
claude plugin marketplace add caasi/dong3
```

## License

MIT
