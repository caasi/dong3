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

1. Read `references/enforcement-layers.md` for the layer execution order
2. Run layers in order: Lint → Validation → PBT → Mutation Testing
3. Fail fast: fix issues at each layer before proceeding to the next
4. For Layer 3+4 feedback loop: read `references/mutation-feedback-guide.md`
5. Default mutation score target: 80%
6. Max 3 feedback rounds
7. Escalation: after 3 rounds or on unresolvable mutants, report to user with mutant summary table

## Final Report

For each layer:
- **Status:** pass / fail
- **Mutation score** (Layer 4)
- **Surviving mutants** (if any)
- **Recommendations** for next steps
