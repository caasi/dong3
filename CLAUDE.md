# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code plugin marketplace (`caasi/dong3`) containing six independent plugins under `plugins/`. No traditional build system — this is a skill/plugin distribution repo.

Install: `claude plugin marketplace add caasi/dong3`

## Repository Structure

```
.claude-plugin/marketplace.json   # Central manifest (all plugin versions)
plugins/
  chat-subagent/                  # Delegate to external LLM endpoints (bash/curl)
  compose/                        # Arrow-style DSL for workflow pipelines
  constraint/                     # NL constraints → deterministic test artifacts
  fetch-tips/                     # Platform-specific fetch strategies
  kami/                           # Socratic dialogue on human-AI stewardship
  owasp/                          # OWASP security review with offline references
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

**compose (v0.11.0):** Uses an OCaml binary (`ocaml-compose-dsl`) for DSL validation. Install via `scripts/install.sh` (downloads to `~/.local/bin/`). Validate `.arr` files with `ocaml-compose-dsl pipeline.arr` or Markdown files with `ocaml-compose-dsl --literate doc.md`. Arrow combinators: `>>>` (sequential), `|||` (branch), `***` (parallel), `&&&` (fanout), `?` (question/branch), `loop()` (feedback). Abstraction: `\x -> expr` (lambda), `let x = expr in body` (let binding). Other syntax: `()` (unit), `;` (statement separator). Epistemic conventions: `gather`, `branch`, `merge`, `leaf`, `check` (cognitive role markers with lint support). Grammar spec in `references/dsl-grammar.md`, 22 examples in `examples/`.

**kami (v0.1.0):** Pure dialogue, no runtime dependencies. Grounded in Audrey Tang's 仁工智慧 framework and the Civic AI 6-Pack of Care.

**fetch-tips (v0.1.0):** Platform-specific fetch strategies for content that resists simple WebFetch.

**owasp (v0.1.0):** OWASP security review with offline reference data from 8 Top 10 projects (Web, API, LLM, MCP, Agentic, Mobile, CI/CD, Kubernetes) and a CheatSheetSeries index. Dual-licensed: skill files MIT, OWASP reference files CC BY-SA 4.0.

**constraint (v0.1.0):** Three skills for NL metaprogramming — humans write constraints in structured natural language (`constraints/*.md` with Given/When/Then/Unless/Examples/Properties), agents generate deterministic test artifacts. `constraint-write` for authoring, `constraint-generate` for artifact generation (TypeScript: Biome, ast-grep, Typia, fast-check, Stryker), `constraint-enforce` for running the enforcement pipeline.

## Versioning

- Plugin versions live in `.claude-plugin/marketplace.json`.
- No package registries; compose binary distributed via GitHub releases of `caasi/ocaml-compose-dsl`.

## Conventions

- Commits follow **conventional commits** scoped by plugin: `feat(compose):`, `docs(kami):`, `chore(chat-subagent):`, etc.
- Planning docs (specs, plans) can go directly on `main`. Code changes must go on a feature branch.
- Bash scripts use `set -euo pipefail`.
- SKILL.md files are system prompts read by Claude — they define trigger conditions and agent behavior. README.md files are user-facing docs.

## Known Issues & Lessons

### constraint-generate: 非 TypeScript 語言要自行變通

Skill 描述寫「only TypeScript is currently supported」，但實際使用時遇到非 TypeScript 專案，agent 應依據偵測到的語言和 PBT 工具自行調整產出格式，而非拒絕執行或硬套 TypeScript。

已驗證的語言對照表：

| 語言 | PBT 框架 | Test runner | 產出檔名慣例 |
|------|---------|-------------|-------------|
| TypeScript | fast-check | vitest/jest | `*.constraint.pbt.test.ts` |
| OCaml | QCheck (qcheck-core + qcheck-alcotest) | alcotest | `test/test_properties.ml` |

### constraint-generate: 不要建議不存在的 hook 事件

Skill 的 post-generate suggestion 曾建議加 `PreCommit` hook，但 Claude Code hooks **沒有 `PreCommit` 事件**。實際可用的事件是 `PreToolUse`、`PostToolUse`、`Stop`、`Notification` 等。不要在 skill 中建議不存在的 hook 事件。

更重要的是：真正的需求不是自動化 hook，而是**讓 coding agent 養成頻繁、確定性地跑測試的習慣**。Skill 應直接在工作流程中指示 agent 在每次產出後執行測試，而非把責任推給可能不存在的基礎設施。
