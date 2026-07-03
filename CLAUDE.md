# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code plugin marketplace (`caasi/dong3`) containing nine independent plugins under `plugins/`. No traditional build system — this is a skill/plugin distribution repo.

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
  review-loop/                    # Assisted multi-reviewer loop (Claude + Codex → Copilot), never auto-merges
  tsugu/                          # Git-native preparation & human–agent convergence (init/prepare/converge)
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

**old-react:** FP-thinking review/refactor for pre-RSC React (classes, hooks, Redux/MobX/observable, Reselect, Immer). Ships **architectural** rules only — categories already covered by the React-Compiler diagnostics in `eslint-plugin-react-hooks` v5+ (`recommended-latest`) and TypeScript discriminated unions are deferred. Five active categories: `model-`, `effect-`, `compose-`, `purity-`, `hooks-`. Two deferred: `immutable-`, `message-`. Canonical rule list lives in `plugins/old-react/skills/old-react/SKILL.md` (don't duplicate counts here — they drift). Rule bodies use FP/TEA pattern terms only; brand names live in `references/lib-suggestions.md`. Rules ship from real review examples, not a planned list (see spec §9 "Adding rules — real-example-driven"). One slash command: `/old-react [review|refactor] [path]`. Spec: `docs/superpowers/specs/001-old-react-skill-design.md`. Lineage source: `docs/old-react.md`.

**review-loop:** Assisted, not autonomous, multi-reviewer convergence loop. Local reviewers run first — a Claude subagent always, plus Codex via `codex exec review` (headless) when `codex` is on `PATH`; tmux optional for a live-watch pane — then GitHub Copilot for PR targets. Helper scripts in `skills/review-loop/scripts/` (`copilot.sh`, `pr-comments.sh`) are referenced via `${CLAUDE_PLUGIN_ROOT}`. Target scope is any changed artifact: code or design artifacts (specs, plans, docs). One slash command: `/review-loop [PR# | branch | blank]`. Spec: `docs/superpowers/specs/002-review-loop-plugin-design.md` (Codex channel superseded by `docs/superpowers/specs/003-review-loop-headless-codex-design.md`).

**tsugu:** Git-native skill for unattended work preparation and human–agent convergence (継ぐ — "to inherit / continue / carry forward"). Schema 6 (lineage: 004 → 005 → 006 → 007 → 008 → 011 → 012 → 013). Using git's DAG as the coordination substrate, an agent prepares engineering work privately on git branches (often while the human is away), records evidence in per-ref `context.md`, and promotes durable findings into `knowledge/`; the human then converges — reads prepared branches live, decides what becomes public, and hands the work off for landing in one human-present session. Four routines: `init` (set up the repo's committed `.tsugu/` workspace + `policy.md`; idempotent; migrates older schemas), `prepare` (private **local-first** git work on the configured work-prefix branches — default `prepare/*`, kept local by default and pushed only on the cross-machine `push-prepare-branches: yes` opt-in — that **gathers understanding** rather than finalizing: investigation, root cause, option space, trade-offs, with reference code optional/partial and a scope-only branch a first-class outcome; + tests + evidence; **freshness-rebases each in-progress work branch onto the fetched default** first when `## Freshness`'s `rebase-prepare-onto-default` reads `yes` (fresh-init default; absent → `no`, fail-safe), with a forced-merge conflict backend, `context.md` union-merged, and any real conflict aborting + skipping that branch for the run; recurses into `.tsugu/`-bearing submodules; external silence), `converge` (read branches live, present status view — including each candidate's derived **"behind default by N"** and, for pushed branches, local/remote divergence — decide with the human, accept/park/drop, promote knowledge; for a behind-default candidate, **offers a freshness-refresh as the first per-branch decision**, before accept/park/drop, default **Y/n**, conflicts resolved or parked live, independent of the `prepare`-side flag; **accept itself is still a handoff-only rename** — `git branch -m prepare/<slug> <accepted-prefix>/<slug>` — with no build/verify/push/PR, gated behind a **human-marked maintenance exception** that unlocks the complete-to-ready path; the agent never self-classifies maintenance; invokes no skill — the human triggers skills by keyword), `prune` (human-present, read-only-until-approved sweep of unused local + remote branches: deletes settled / leftover-worktree on confirm, surfaces dropped / possibly-landed / orphaned-accepted / taken-over (redundant prepare) for explicit per-item confirmation, never touches unfinished work). Committed `.tsugu/` is a **WIP-knowledge layer** — a richer, agent-maintained sibling of `AGENTS.md`/`CLAUDE.md` — holding three knowledge parts: `policy.md` + `context.md` + `knowledge/`, plus a one-line infrastructure file, `.gitattributes` (`context.md merge=union`, so the narrative never blocks a merge/rebase). Everything about how Tsugu operates for one human lives in a **personal global folder** (`~/.claude/tsugu/<project-key>/`, per machine, never committed): observation sources, opt-in skills, and the converge packet (derived, regenerated live). **State is single-layer** — no status fields, no intake notes, no `runs/`, no recorded landed-SHA; settled = containment in the default branch; taken-over = a non-default, non-work branch (an accepted-prefix handoff **or** a human's own branch) contains the tip, so a human now owns it (slug-pairing is the complementary catch for a history-rewriting landing). A forced-squash severs containment derivation, so the work re-surfaces live at each `converge` until the human confirms landing (retain the accepted branch; no SHA recorded). Accepted-prefixes default `feature/* bugfix/* chore/*`. **Merge commits are recommended.** **Never auto-merges** (no public coordination without approval). **Light / script-free** — recipes are documented guidance; no scripts shipped. **Invokes no user-installed skill by default** — native git + its own built-in subagents only; a human's **personal config** (`~/.claude/tsugu/<project-key>/config.md`) may opt in to named skills per machine. Four slash commands: `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`, `/tsugu:prune`. Spec: `docs/superpowers/specs/004-tsugu-skill-design.md` + `docs/superpowers/specs/005-tsugu-agent-first-design.md` + `docs/superpowers/specs/006-tsugu-workspace-transfer-design.md` + `docs/superpowers/specs/007-tsugu-thin-core-design.md` + `docs/superpowers/specs/008-tsugu-submodule-recursion-design.md` + `docs/superpowers/specs/011-tsugu-handoff-converge-design.md` + `docs/superpowers/specs/012-tsugu-local-first-prepare-design.md` + `docs/superpowers/specs/013-tsugu-rebase-prepare-onto-default-design.md`.

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
