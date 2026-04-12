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

- **TypeScript** — fully supported (Biome, ast-grep, Typia, fast-check, Stryker)
- OCaml, Rust, Python — planned

## Guided Flow

After generating artifacts, suggests running `/constraint-enforce` and adding
a PreCommit hook for automated enforcement.
