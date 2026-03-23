# Compose Example: Frontend Project Workflow

## Context

The compose skill's `examples/` directory covers basic patterns, CI/CD, and OSINT workflows but has no frontend/product development examples. This spec describes a single large `.arr` file that models a complete frontend project lifecycle — from client requirements to production delivery — with outsourced design and in-house implementation.

## Goals

1. Add a realistic frontend project workflow example to `examples/`
2. Stress-test the `ocaml-compose-dsl` binary with a 220+ line file (current largest is 54 lines)
3. Demonstrate all combinators (`>>>`, `&&&`, `|||`, `?`, `loop`) in a single coherent workflow

## Design Decisions

- **Single file** (`frontend-project.arr`) — maximizes binary stress-test value
- **Mixed language node names** — business-facing nodes in Chinese, technical nodes in English, reflecting real-world bilingual teams
- **Tools as node functions with key:value args** — `Tool(key: value)` syntax (e.g., `Figma(任務: Wireframe, 裝置: mobile)`, `Cursor(任務: 生成元件程式碼)`) instead of `-- ref:` comments, making the DSL self-describing and conforming to the grammar's `arg = ident ":" value` rule
- **Maximum parallelism** — every step that can run concurrently uses `&&&` fanout
- **LLM vs traditional fallback** — Phase 3 handoff uses `? |||` to model Figma MCP → Cursor path with fallback to manual Zeplin workflow

## Phases

### Phase 1: Discovery
- Stakeholder + user interviews (with Fireflies transcription, Claude analysis) fanout with competitor research (SimilarWeb, Figma, Claude)
- IA drafting, tech evaluation, and cost estimation in 3-way parallel
- Claude drafts spec → internal review loop (`loop` + `?` + `|||`) → client sign-off loop

### Phase 2: Design (outsourced)
- Visual inspiration 3-way parallel (Pinterest, Dribbble, Mobbin)
- Brand exploration (color & typography parallel) → moodboard → client style gate
- Wireframe (mobile & desktop parallel) → client design review gate
- Design tokens (3 parallel definitions) → design system → 7 component libraries parallel
- Hi-fi mockups (6 pages parallel) → interaction states (6 parallel) → responsive breakpoints (3 parallel)
- Prototype assembly (2 parallel) → usability testing → 2 rounds of corrections → client final sign-off gate

### Phase 3: Handoff
- Dev Mode → component docs & token export parallel
- LLM path (Figma MCP → Cursor → Claude review → fix) with `? |||` fallback to traditional (Zeplin → 3 parallel spec docs)
- Token conversion, asset export, and spec docs in parallel
- Handoff meeting

### Phase 4: Implementation
- Next.js init → 8 project config tasks all parallel
- Shared layout first → Header & Footer parallel → 6 page implementations parallel
- 4-way parallel testing (Storybook, Playwright, Chromatic, axe)
- Code review loop (`loop` + `?` + `|||`)
- Staging deploy → 3-way parallel QA → bug fix loop

### Phase 5: Delivery
- Checklist & env vars parallel → 4-way infra setup parallel
- Production deploy → 4-way monitoring verification parallel
- Tutorial, ops docs 3-way parallel → client acceptance gate → 4-way asset handover parallel

## Combinators Used

| Combinator | Usage |
|-----------|-------|
| `>>>` | Sequential phase progression, step chaining |
| `&&&` | Fanout everywhere — parallel tasks on same input |
| `\|\|\|` | LLM vs traditional handoff fallback; review loop retry |
| `?` | Client sign-off gates, internal review, QA verification |
| `loop` | All approval gates (7 total), code review cycle, bug fix cycle |

## File

`plugins/compose/skills/compose/examples/frontend-project.arr`

## Known Issues

- **False positive warning at Phase 3 handoff:** `?` at end of `>>>` chain inside grouped `|||` triggers `'?' without matching '|||' in scope`. AST is correct. Tracked in [caasi/ocaml-compose-dsl#16](https://github.com/caasi/ocaml-compose-dsl/issues/16).
