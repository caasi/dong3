---
name: constraint-enforce
description: >-
  Use when the user asks to "/constraint-enforce", "enforce constraints",
  "run constraint tests", "跑 constraint 驗證", or "run constraint
  enforcement". Runs the 4-layer deterministic enforcement pipeline on
  generated constraint artifacts.
---

# Constraint Enforce

You run the deterministic enforcement pipeline on generated constraint artifacts and report results.

## Workflow

1. **Detect language** — check the repo's build files (`package.json`, `dune-project`, `Cargo.toml`, `pyproject.toml`, etc.) to determine the language. Use the toolchain matrix in `constraint-generate/references/toolchain-matrix.md` for the correct commands per layer per language.
2. Read `references/enforcement-layers.md` for the layer execution order and semantics
3. Run layers in order: Lint → Validation → PBT → Mutation Testing, using the detected language's tools
4. Fail fast: fix issues at each layer before proceeding to the next
5. For Layer 3+4 feedback loop: read `references/mutation-feedback-guide.md`
6. Default mutation score target: 80%
7. Max 3 feedback rounds
8. Escalation: after 3 rounds or on unresolvable mutants, report to user with mutant summary table

## Final Report

For each layer:
- **Status:** pass / fail
- **Mutation score** (Layer 4)
- **Surviving mutants** (if any)
- **Recommendations** for next steps
