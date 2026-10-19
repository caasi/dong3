# CLAUDE.md

## What This Is

A Claude Code plugin marketplace (`caasi/dong3`) containing ten independent plugins under `plugins/`. No traditional build system — this is a skill/plugin distribution repo.

Install: `claude plugin marketplace add caasi/dong3`

## Repository Structure

```
.claude-plugin/marketplace.json   # Central manifest (all plugin versions)
plugins/
  compose/                        # Arrow-style DSL for workflow pipelines
  constraint/                     # NL constraints → deterministic test artifacts
  dataflow/                       # Explore a codebase with the user, one step at a time (data flow + types)
  kami/                           # Socratic dialogue on human-AI stewardship
  old-react/                      # FP-thinking review/refactor for pre-RSC React
  review-loop/                    # Assisted review loop; never auto-merges
  tsugu/                          # Git-native preparation & convergence (init/prepare/converge/prune)
tools/<plugin>/                   # Repo-level dev tooling (NOT shipped to skill users)
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

> Versions live in `.claude-plugin/marketplace.json` — don't duplicate them here. The compose binary comes from GitHub releases of `caasi/ocaml-compose-dsl`; there is no package registry.

**compose:** Validates with the `ocaml-compose-dsl` binary (`scripts/install.sh` puts it in `~/.local/bin/`): `ocaml-compose-dsl pipeline.arr`, or `--literate doc.md` for Markdown. Grammar in `references/dsl-grammar.md`, examples in `examples/`.

**dataflow:** One skill, auto-triggered. Explore a codebase with the user, one step at a time. The SKILL.md is deliberately short: it states only what the model does not do by default. Measured with `claude -p` simulation runs; the numbers are in the skill README. Design record: issue #91 — **no spec file**.

**constraint:** Three skills for NL metaprogramming — humans write constraints in structured natural language (`constraints/*.md` with Given/When/Then/Unless/Examples/Properties), agents generate deterministic test artifacts. `constraint-write` for authoring, `constraint-generate` for language-agnostic artifact generation (see `references/toolchain-matrix.md`; TS is the primary reference, OCaml verified), `constraint-enforce` for running the enforcement pipeline.

**old-react:** FP-thinking review/refactor for pre-RSC React. Ships **architectural** rules only; what the React-Compiler diagnostics in `eslint-plugin-react-hooks` v5+ and TypeScript discriminated unions cover is deferred. The rule list lives in `plugins/old-react/skills/old-react/SKILL.md` (don't duplicate counts here — they drift). Rules ship from real review examples (spec §9). One slash command: `/old-react [review|refactor] [path]`. Spec: `docs/superpowers/specs/001-old-react-skill-design.md`. Lineage source: `docs/old-react.md`.

**review-loop:** Assisted, not autonomous. Local reviewers answer blind and in parallel on the same unfixed diff; each gives its own per-round verdict; the loop runs until K dry rounds; then GitHub Copilot for PR targets. Every rule of the loop lives in `skills/review-loop/SKILL.md` — do not restate it here. Specs: `docs/superpowers/specs/*-review-loop-*`. Three releases have no spec file; the issue is the design record: 0.12.0 kept command (#84), 0.13.0 roster stamp 2 (#96), 0.14.0 usage record (#92). Two slash commands: `/review-loop [PR# | branch | blank]` and `/review-loop:init`.

**tsugu:** Git-native preparation and convergence (継ぐ — "to carry forward"). Four routines, each a slash command: `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`, `/tsugu:prune`. Never auto-merges; no scripts shipped; invokes no user-installed skill by default. Every rule lives in `skills/tsugu/SKILL.md`. Schema 8. Specs: `docs/superpowers/specs/*-tsugu-*`, read in number order (004 → 022).

## Conventions

- Commits follow **conventional commits** scoped by plugin: `feat(compose):`, `docs(kami):`, `chore(tsugu):`, etc.
- Planning docs (specs, plans) can go directly on `main`. Code changes must go on a feature branch.
- Bash scripts use `set -euo pipefail`.

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

Claude Code hooks **沒有 `PreCommit` 事件**（有的是 `PreToolUse`、`PostToolUse`、`Stop`、`Notification` 等）。要讓 agent 頻繁跑測試，直接在 skill 的工作流程裡指示它每次產出後執行，不要推給可能不存在的 hook。
