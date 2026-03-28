# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code plugin marketplace (`caasi/dong3`) containing three independent plugins under `plugins/`. No traditional build system — this is a skill/plugin distribution repo.

Install: `claude plugin marketplace add caasi/dong3`

## Repository Structure

```
.claude-plugin/marketplace.json   # Central manifest (all plugin versions)
plugins/
  chat-subagent/                  # Delegate to external LLM endpoints (bash/curl)
  compose/                        # Arrow-style DSL for workflow pipelines
  kami/                           # Socratic dialogue on human-AI stewardship
docs/superpowers/                 # Design specs and implementation plans
```

Each plugin follows this layout:
```
plugins/<name>/
  .claude-plugin/plugin.json      # Plugin metadata
  skills/<skill-name>/
    SKILL.md                      # System prompt (Claude reads this)
    README.md                     # User-facing documentation
    references/                   # Deep reference materials
```

## Plugin Details

**chat-subagent (v0.4.0):** `chat.sh` is a pure bash/curl wrapper for OpenAI-compatible APIs. `thinking-filter.jq` strips reasoning blocks. `probes/` contains 19 diagnostic questions (reasoning, instruction-following, counting, coding). Test the jq filter with `test-thinking-filter.sh`.

**compose (v0.10.0):** Uses an OCaml binary (`ocaml-compose-dsl`) for DSL validation. Install via `scripts/install.sh` (downloads to `~/.local/bin/`). Validate `.arr` files with `ocaml-compose-dsl pipeline.arr` or Markdown files with `ocaml-compose-dsl --literate doc.md`. Arrow combinators: `>>>` (sequential), `|||` (branch), `***` (parallel), `&&&` (fanout), `?` (question/branch), `loop()` (feedback). Abstraction: `\x -> expr` (lambda), `let x = expr in body` (let binding). Other syntax: `()` (unit), `;` (statement separator). Grammar spec in `references/dsl-grammar.md`, 21 examples in `examples/`.

**kami (v0.1.0):** Pure dialogue, no runtime dependencies. Grounded in Audrey Tang's 仁工智慧 framework and the Civic AI 6-Pack of Care.

**fetch-tips (v0.1.0):** Platform-specific fetch strategies for content that resists simple WebFetch.

## Versioning

- Plugin versions live in the top-level `marketplace.json`.
- No package registries; compose binary distributed via GitHub releases of `caasi/ocaml-compose-dsl`.

## Conventions

- Commits follow **conventional commits** scoped by plugin: `feat(compose):`, `docs(kami):`, `chore(chat-subagent):`, etc.
- Planning docs (specs, plans) can go directly on `main`. Code changes must go on a feature branch.
- Bash scripts use `set -euo pipefail`.
- SKILL.md files are system prompts read by Claude — they define trigger conditions and agent behavior. README.md files are user-facing docs.
