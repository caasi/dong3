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
  review-loop/                    # Assisted loop — local reviewers blind & parallel (enrolled roster), then Copilot; never auto-merges
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

**review-loop:** Assisted, not autonomous, multi-reviewer convergence loop. Local reviewers answer **blind and in parallel** on the same unfixed diff, before any fix — a Claude subagent always, plus any models/CLIs enrolled per host (Codex via headless `codex exec` when present, native `review` on a working sandbox or the embedded-diff form when it is `broken`); tmux optional for a live-watch pane. The verdict names which reviewers actually ran — heterogeneity is a bonus, not a gate, and same-family review is never a downgrade. **Convergence is each reviewer's own explicit per-round verdict** (`{ converged, still_open, reason }`; Codex: an NL `CONVERGED`/`STILL-OPEN` line), not the facilitator's round-count: the loop runs **until-dry** (K consecutive rounds where every live reviewer reports converged), with the facilitator owning **K** (sticky, set on the ground-truth axis) and the **escalation-to-direction-guard** decision (issue #64, 0.6.0). Then GitHub Copilot for PR targets. Helper scripts in `skills/review-loop/scripts/` (`copilot.sh`, `pr-comments.sh`) are referenced via `${CLAUDE_PLUGIN_ROOT}`. Target scope is any changed artifact: code or design artifacts (specs, plans, docs). **Reproduction follows the reader** — a behaviour claim about a runtime prompt is settled by five independent simulation runs and never by a string comparison; a presence claim is still settled by a `grep`; deterministic output keeps TDD (issue #73, 0.8.0). **Author checkpoints are published at A0 and then held** — the author pass, one batched message per round that has a T2/T3 finding, the hand-off; two stops plus one per such round, nothing in between, three named exceptions that re-publish the shape. **A T3 that comes back after a fix is a drift signal**: that round's message re-confirms the direction of the whole change with the author as well as asking for the item's fix, and it is not an extra stop (issue #70, 0.9.0). **The loop is not a journal** — it keeps no prose record of its own that carries from one review to the next; the round log stays because it is one line of fixed fields that nothing reads during a loop and nothing reduces. A repository that still has `.claude/pr-review-journal.md` is offered its removal at A0 (asked again each run while the file is there — nothing records a no), and **every reviewer's brief is told the file is not a source**, since `Non-goals` lives in the skill and no reviewer reads the skill (0.11.0). **A settled finding keeps the command that settled it** — when a command reproduced the finding, that command already ran; it is kept in a scratch directory outside the repo and re-run at the start of each round and before each commit, so a defect written back into settled prose fails the kept command instead of costing a reviewer round. On executable code the test suite already did this job. § Tiers does give prose a practice — one logical edit per finding, reviewed for clarity, consistency, structure and factual accuracy — but it puts no runnable check in its place, which is why the same defect can return round after round with only a reviewer to catch it. The kept command is the settling evidence itself, **never a check written afterwards**: a finding no command settled — a behaviour claim, or a judgement — keeps nothing. Without that rule an accumulating directory of green greps makes the cheap `grep` the route that gets taken, which is what `Prompt outputs are run` exists to prevent. Writing a check after the fact is a decision, and the cheap route is chosen at that decision; keeping the command removes the decision instead of guarding it with a sentence of prose. The first two five-run simulations each carried such a sentence and each still produced one check kept for a judgement-settled finding; the third replaced the sentence with this rule and produced none (issue #84, 0.12.0 — **no spec file**: the rewritten issue is the design record, so a spec would only restate it and later disagree with it). Two slash commands: `/review-loop [PR# | branch | blank]` and `/review-loop:init` (enrol the per-host roster; never a precondition). Specs: `docs/superpowers/specs/002-review-loop-plugin-design.md`, `003-review-loop-headless-codex-design.md` (headless Codex), `014-review-loop-reviewer-roster-design.md` (0.5.0 — enrolled roster + blind-parallel review), `018-review-loop-prompt-outputs-are-run-design.md` (0.8.0 — prompt outputs are run), `019-review-loop-author-checkpoints-design.md` (0.9.0 — author checkpoints + the recurring-T3 direction rule), `020-review-loop-log-is-a-record-design.md` (0.10.0 — the log is one line per round and nothing else; the UserPromptSubmit hook, the `object` line and the marker convention are removed, superseding the hook half of 016), `021-review-loop-not-a-journal-design.md` (0.11.0 — `Learning capture` removed, the `Not a journal` statement it needed, the A0 removal offer, and the not-a-source line in every reviewer's brief; the transcript defect in `Prompt outputs are run` is deferred there with its reason).

**tsugu:** Git-native skill for unattended work preparation and human–agent convergence (継ぐ — "to inherit / continue / carry forward"). Schema 8 (lineage: 004 → 005 → 006 → 007 → 008 → 011 → 012 → 013 → 015 → 017 → 022). Using git's DAG as the coordination substrate, an agent prepares engineering work privately on git branches (often while the human is away), records the narrative in per-ref `context.md` and the runnable artifacts in per-ref `evidence/`; the human then converges — reads prepared branches live, decides what becomes public, and hands the work off for landing in one human-present session. Four routines: `init` (set up the repo's committed `.tsugu/` workspace + `policy.md`; idempotent; migrates older schemas), `prepare` (private **local-first** git work on the configured work-prefix branches — default `prepare/*`, kept local by default and pushed only on the cross-machine `push-prepare-branches: yes` opt-in — that **gathers understanding** rather than finalizing: investigation, root cause, option space, trade-offs, with reference code optional/partial and a scope-only branch a first-class outcome; + tests + evidence; **freshness-rebases each in-progress work branch onto the fetched default** first when `## Freshness`'s `rebase-prepare-onto-default` reads `yes` (fresh-init default; absent → `no`, fail-safe), with a forced-merge conflict backend, a `.tsugu/` conflict resolved by the agent (with one line in the narrative saying what it kept) or declined, and any other conflict aborting + skipping that branch for the run; recurses into `.tsugu/`-bearing submodules; external silence), `converge` (read branches live, present status view — including each candidate's derived **"behind default by N"** and, for pushed branches, local/remote divergence — decide with the human, accept/park/drop, promote knowledge; for a behind-default candidate, **offers a freshness-refresh as the first per-branch decision**, before accept/park/drop, default **Y/n**, conflicts resolved or parked live, independent of the `prepare`-side flag; **accept itself is still a handoff-only rename** — `git branch -m prepare/<slug> <accepted-prefix>/<slug>` — with no build/verify/push/PR, gated behind a **human-marked maintenance exception** that unlocks the complete-to-ready path; the agent never self-classifies maintenance; invokes no skill — the human triggers skills by keyword), `prune` (human-present, read-only-until-approved sweep of unused local + remote branches: deletes settled / leftover-worktree on confirm, surfaces dropped / possibly-landed / orphaned-accepted / taken-over (redundant prepare) for explicit per-item confirmation, never touches unfinished work). Committed `.tsugu/` is a **work-in-progress layer** — a richer, agent-maintained sibling of `AGENTS.md`/`CLAUDE.md` — holding three parts and no infrastructure file: `policy.md` + `context.md` + `evidence/`. `evidence/` is per-ref like `context.md` and is **emptied at landing**: what is still needed afterwards moves to the agent md, `docs/` or the test suite, and the rest is deleted (spec 022). Everything about how Tsugu operates for one human lives in a **personal global folder** (`~/.claude/tsugu/<project-key>/`, per machine, never committed): observation sources, opt-in skills, and the converge packet (derived, regenerated live). **State is single-layer** — no status fields, no intake notes, no `runs/`, no recorded landed-SHA; settled = containment in the default branch; taken-over = a non-default, non-work branch (an accepted-prefix handoff **or** a human's own branch) contains the tip, so a human now owns it (slug-pairing is the complementary catch for a history-rewriting landing). A forced-squash severs containment derivation, so the work re-surfaces live at each `converge` until the human confirms landing (retain the accepted branch; no SHA recorded). Accepted-prefixes default `feature/* bugfix/* chore/*`. **Merge commits are recommended.** **Never auto-merges** (no public coordination without approval). **Light / script-free** — recipes are documented guidance; no scripts shipped. **Invokes no user-installed skill by default** — native git + its own built-in subagents only; a human's **personal config** (`~/.claude/tsugu/<project-key>/config.md`) may opt in to named skills per machine. Four slash commands: `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`, `/tsugu:prune`. Spec: `docs/superpowers/specs/004-tsugu-skill-design.md` + `docs/superpowers/specs/005-tsugu-agent-first-design.md` + `docs/superpowers/specs/006-tsugu-workspace-transfer-design.md` + `docs/superpowers/specs/007-tsugu-thin-core-design.md` + `docs/superpowers/specs/008-tsugu-submodule-recursion-design.md` + `docs/superpowers/specs/011-tsugu-handoff-converge-design.md` + `docs/superpowers/specs/012-tsugu-local-first-prepare-design.md` + `docs/superpowers/specs/013-tsugu-rebase-prepare-onto-default-design.md` + `docs/superpowers/specs/015-tsugu-context-cleanup-hint-design.md` + `docs/superpowers/specs/017-tsugu-blindspots-verify-design.md` + `docs/superpowers/specs/022-tsugu-evidence-not-knowledge-design.md`; 015 adds a standing **post-handoff cleanup** block in the mainline `context.md` plus an always-loaded **agent-md routing pointer** (`init` writes it to `CLAUDE.md`/`AGENTS.md`) so the finishing agent resets the branch narrative before landing. 017 adds a `## Blindspots` section to the `context.md` template (unknown unknowns from the prepare sweep, material + grounded; a branch-working section) plus a converge reminder to verify findings with the human before a workflow skill fires — a template + SKILL change, no schema bump. 022 renames `knowledge/` to `evidence/` and re-scopes it from a repo-wide wiki on a coordination ref to a per-ref directory emptied at landing; removes the union merge driver, `.gitattributes`, the coordination ref, `## Promotion candidates` and the POST-HANDOFF block's byte-immutability; and adds a write-time redaction rule, since `evidence/` is committed and reaches the default branch in `include` mode (schema 7 → 8).

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
