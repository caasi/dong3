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

3. **Detect repo toolchain** — check for `package.json`, `tsconfig.json`, `dune-project`, `Cargo.toml`, `pyproject.toml`, etc. to determine language and available tooling. Adapt all generated artifacts to the detected language — do not refuse non-TypeScript repos or force TypeScript output.

4. **Select tools** — read `references/toolchain-matrix.md` to pick the correct test runner, linter, PBT library, and mutation tool for the detected language. If the matrix has no entry for the detected language, research the ecosystem's idiomatic PBT and lint tools before generating.

5. **Generate artifacts** — for each constraint file, produce the applicable artifacts using the detected language's idiomatic tools and file conventions:

   | Section | Artifact (adapt to language) |
   |---|---|
   | Examples table | Parameterized tests (TS: `it.each`, OCaml: `Alcotest.test_case` with concrete cases, Rust: `#[test]` with test cases, Python: `@pytest.mark.parametrize`) |
   | Properties | PBT tests (TS: fast-check, OCaml: QCheck, Rust: proptest, Python: Hypothesis) |
   | Prohibition + structural lint | `.ast-grep/rules/*.yml` or semgrep rules (check language support in toolchain-matrix) |
   | Validation | Runtime validation at trust boundaries using the language's idiomatic library |

6. **File conventions:**
   - Header comment: `Generated from constraints/<RULE_ID>-<slug>.md — do not edit manually` (use the language's comment syntax)
   - Place artifacts in the repo's existing test directory structure.
   - Follow the language's naming conventions (TS: `*.constraint.test.ts`, OCaml: `test/test_<slug>_properties.ml`, Rust: `tests/<slug>_constraint.rs`, Python: `test_<slug>_constraint.py`).
   - Re-running overwrites previously generated artifacts (idempotent).

7. **Post-generate: verify and suggest** — after generating artifacts:
   - **Run the generated tests immediately** to verify the artifacts are valid. If a failure is caused by an artifact problem (compile error, wrong import, broken test harness, incorrect file placement), fix the artifact and re-run.
   - If a failure appears to reflect a **real constraint violation in the current code**, do **not** weaken or remove the generated test to force green. Instead, report that the repository currently violates the constraint and keep the artifact faithful.
   - Suggest running `/constraint-enforce` for the full 4-layer enforcement pipeline. If a real violation was detected, mention it in the suggestion.
