---
name: constraint-generate
description: >-
  Use when the user asks to "/constraint-generate", "generate constraint
  tests", "generate constraint artifact", "產生 constraint 的 test", or
  "generate test from constraint". Reads constraints/*.md and produces
  deterministic test artifacts.
---

# Constraint Generate

You read constraint files from `constraints/*.md` and generate deterministic test artifacts that enforce them mechanically.

## Workflow

1. **Scan constraints** — read every file matching `constraints/*.md`. Parse YAML frontmatter (`rule`, `kind`, `scope`, `subject`, `enforce`) and body sections (Given, When, Then, Unless, Examples, Properties).

2. **Understand the format** — read `references/constraint-format.md` for the canonical constraint file structure.

3. **Detect repo toolchain** — check for `package.json`, `tsconfig.json`, `dune-project`, `Cargo.toml`, `pyproject.toml`, etc. to determine language and available tooling. **If the detected language is not TypeScript**, inform the user that only TypeScript is currently supported and ask whether to proceed with TypeScript artifacts anyway or stop.

4. **Select tools** — read `references/toolchain-matrix.md` to pick the correct test runner, linter, PBT library, and mutation tool for this repo. Only TypeScript tools are fully supported in v0.1.0.

5. **Generate artifacts** — for each constraint file, produce the applicable artifacts:

   | Section | Artifact |
   |---|---|
   | Examples table | `*.constraint.test.ts` — parameterized tests via `it.each` |
   | Properties | `*.constraint.pbt.test.ts` — fast-check property-based tests |
   | Prohibition + ast-grep | `.ast-grep/rules/*.yml` — structural lint rule |
   | Validation | Runtime validation code at trust boundaries |

6. **File conventions:**
   - Header: `// Generated from constraints/<RULE_ID>-<slug>.md — do not edit manually`
   - Place artifacts in the repo's existing test directory structure.
   - Re-running overwrites previously generated artifacts (idempotent).

7. **Post-generate suggestions** — after generating, suggest two things:
   - "要我用 `/constraint-enforce` 跑驗證嗎？"
   - If no constraint-related PreCommit hook is detected in `.claude/settings.json`, suggest adding one (see template below). **Do not auto-modify settings.**

## Hook Suggestion Template

```json
{
  "hooks": {
    "PreCommit": [{ "matcher": "", "command": "npm test -- --grep constraint" }]
  }
}
```

Suggest this to the user — do not write it automatically.
