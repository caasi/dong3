# Constraint Enforce

Run the 4-layer deterministic enforcement pipeline on generated constraint artifacts.

## Usage

Invoke with `/constraint-enforce` or ask to "enforce constraints", "跑 constraint 驗證".

## Pipeline Layers

1. **Lint** — Biome + ast-grep
2. **Validation** — Typia / ArkType / Zod
3. **PBT** — fast-check property tests
4. **Mutation Testing** — Stryker (with feedback loop)

## Mutation Testing Feedback Loop

- Default target: 80% mutation score
- Max 3 rounds of property strengthening
- Escalates to user for equivalent mutants or stalled progress
