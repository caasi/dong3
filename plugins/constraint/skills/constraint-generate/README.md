# Constraint Generate

Read `constraints/*.md` files and generate deterministic test artifacts.

## Usage

Invoke with `/constraint-generate` or ask to "generate constraint tests".

## What It Generates

| Constraint Section | Generated Artifact |
|---|---|
| Examples table | Parameterized unit tests (`*.constraint.test.ts`) |
| Properties | fast-check PBT tests (`*.constraint.pbt.test.ts`) |
| Prohibition (ast-grep) | ast-grep rule YAML |
| Validation | Runtime validation at trust boundaries |

## Supported Languages

Language-agnostic — detects the repo's primary language and adapts the generated artifacts accordingly. See `references/toolchain-matrix.md` for the tool mapping.

- **TypeScript** — primary reference (Biome, ast-grep, Typia, fast-check, Stryker)
- **OCaml** — verified (QCheck + alcotest)
- Other languages — the agent researches idiomatic PBT/lint tools if not in the matrix

## Guided Flow

After generating artifacts, runs the generated tests immediately to verify them, then suggests `/constraint-enforce` for the full enforcement pipeline.
