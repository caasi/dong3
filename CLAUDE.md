# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code plugin marketplace (`caasi/dong3`) containing seven independent plugins under `plugins/`. No traditional build system — this is a skill/plugin distribution repo.

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
  old-react/                      # FP-thinking review/refactor for pre-RSC React
  owasp/                          # OWASP security review with offline references
tools/                            # Repo-level dev tooling (NOT shipped to skill users)
  old-react/                      # Validator + fixtures for old-react rule files
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

> Versions live in `.claude-plugin/marketplace.json` — don't duplicate them here.

**chat-subagent:** `chat.sh` is a pure bash/curl wrapper for OpenAI-compatible APIs. `thinking-filter.jq` strips reasoning blocks. `probes/` contains diagnostic questions (reasoning, instruction-following, counting, coding). Test the jq filter with `test-thinking-filter.sh`.

**compose:** Uses an OCaml binary (`ocaml-compose-dsl`) for DSL validation. Install via `scripts/install.sh` (downloads to `~/.local/bin/`). Validate `.arr` files with `ocaml-compose-dsl pipeline.arr` or Markdown files with `ocaml-compose-dsl --literate doc.md`. Arrow combinators: `>>>` (sequential), `|||` (branch), `***` (parallel), `&&&` (fanout), `?` (question/branch), `loop()` (feedback). Abstraction: `\x -> expr` (lambda), `let x = expr in body` (let binding). Other syntax: `()` (unit), `;` (statement separator). Epistemic conventions: `gather`, `branch`, `merge`, `leaf`, `check` (cognitive role markers with lint support). Grammar spec in `references/dsl-grammar.md`, examples in `examples/`.

**kami:** Pure dialogue, no runtime dependencies. Grounded in Audrey Tang's Humane Intelligence (仁工智慧) framework and the Civic AI 6-Pack of Care.

**fetch-tips:** Platform-specific fetch strategies for content that resists simple WebFetch.

**owasp:** OWASP security review with offline reference data from 8 Top 10 projects (Web, API, LLM, MCP, Agentic, Mobile, CI/CD, Kubernetes) and a CheatSheetSeries index. Dual-licensed: skill files MIT, OWASP reference files CC BY-SA 4.0.

**constraint:** Three skills for NL metaprogramming — humans write constraints in structured natural language (`constraints/*.md` with Given/When/Then/Unless/Examples/Properties), agents generate deterministic test artifacts. `constraint-write` for authoring, `constraint-generate` for language-agnostic artifact generation (see `references/toolchain-matrix.md`; TS is the primary reference, OCaml verified), `constraint-enforce` for running the enforcement pipeline.

**old-react:** FP-thinking review/refactor for pre-RSC React (classes, hooks, Redux/MobX/observable, Reselect, Immer). Ships **architectural** rules only — categories that the React-Compiler diagnostics in `eslint-plugin-react-hooks` v5+ (`recommended-latest`) and TypeScript discriminated unions already cover are deferred. v0.1.0 ships 7 rules across 3 categories (model 3, effect 2, compose 2): SSOT for remote state, derive-don't-store, controlled-by-default (continuation lens), effects emit named actions, setup/cleanup pairing, leaf purity, effects at the page boundary (Functional Core / Imperative Shell). Brand names live in `references/lib-suggestions.md`; rule bodies use FP/TEA pattern terms only. Rule scope is open (the skill stays small; under 10 rules is fine). One slash command: `/old-react [review|refactor] [path]`. Spec: `docs/superpowers/specs/001-old-react-skill-design.md`. Lineage source: `docs/old-react.md`.

## Versioning

- Plugin versions live in `.claude-plugin/marketplace.json`.
- No package registries; compose binary distributed via GitHub releases of `caasi/ocaml-compose-dsl`.

## Conventions

- Commits follow **conventional commits** scoped by plugin: `feat(compose):`, `docs(kami):`, `chore(chat-subagent):`, etc.
- Planning docs (specs, plans) can go directly on `main`. Code changes must go on a feature branch.
- Bash scripts use `set -euo pipefail`.
- SKILL.md files are system prompts read by Claude — they define trigger conditions and agent behavior. README.md files are user-facing docs.

## Skill-Authoring Principles

### Dev tooling stays out of `plugins/<name>/`

A plugin's directory boundary is its install boundary — anything inside `plugins/<name>/` reaches the user's disk via the marketplace install. Test fixtures, validators, CI helpers, and other dev-time tooling belong outside that boundary. Convention: repo-level `tools/<plugin>/` (e.g. `tools/old-react/` for the rule-file validator + fixtures + test runner). The `compose` plugin is the deliberate exception — its `scripts/install.sh` is a *user-facing* installer, so it ships intentionally.

### constraint-generate 已驗證的非 TypeScript 語言對照

Skill 本身已語言無關（SKILL.md step 3 會偵測語言並改寫產出），這裡記錄已人工驗證的語言/工具對應，新增時請更新：

| 語言 | PBT 框架 | Test runner | 產出檔名慣例 |
|------|---------|-------------|-------------|
| TypeScript | fast-check | vitest/jest | `*.constraint.pbt.test.ts` |
| OCaml | QCheck (qcheck-core + qcheck-alcotest) | alcotest | `test/test_<slug>_properties.ml` |

### 不要建議不存在的 Claude Code hook 事件

曾踩過的雷：建議加 `PreCommit` hook，但 Claude Code hooks **沒有 `PreCommit` 事件**。實際可用事件是 `PreToolUse`、`PostToolUse`、`Stop`、`Notification` 等。

更重要的是：真正的需求不是自動化 hook，而是**讓 coding agent 養成頻繁、確定性地跑測試的習慣**。Skill 應直接在工作流程中指示 agent 在每次產出後執行測試，而非把責任推給可能不存在的基礎設施。
