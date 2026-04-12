# Enforcement Layers

Constraints are enforced in four layers, executed in order. Each layer builds
on the guarantees provided by the previous one. **Fail fast**: if a layer
fails, fix the violations before proceeding to the next layer.

---

## Layer 1: Lint (Biome + ast-grep)

Static analysis catches style violations, banned patterns, and structural
anti-patterns before any code runs.

### Commands

```bash
# Biome — formatting, linting, import ordering
npx @biomejs/biome check .

# ast-grep — structural rules defined in project sgconfig.yml
npx ast-grep scan
```

### Expected output

- Exit code `0` = clean, no violations.
- Non-zero exit code = one or more violations.

### On failure

1. Collect every violation with **file path + line number**.
2. Present violations grouped by rule.
3. Suggest auto-fixable corrections where the tool supports `--apply`.
4. Do **not** proceed to Layer 2 until all lint violations are resolved.

---

## Layer 2: Validation (Typia / ArkType / Zod)

Runtime type validation ensures that data crossing trust boundaries conforms
to declared schemas. Compile-time checks verify tooling setup only.

### Commands

```bash
# Step 1: Build/tooling check (Typia transformer configured correctly)
npx tsc --noEmit

# Step 2: Run tests that exercise runtime validators at trust boundaries
npm test -- --grep "constraint.validation"
```

### Expected output

- `tsc --noEmit` succeeds = tooling/build check passed (does **not** prove
  runtime data is valid).
- All validation unit tests pass = runtime validators confirm data conforms
  to schemas at trust boundaries.

### On failure

1. Report each type mismatch at the trust boundary where it occurs.
2. Include the expected type and the actual type (or value shape).
3. Do **not** proceed to Layer 3 until all type mismatches are resolved.

---

## Layer 3: PBT (fast-check)

Property-based tests generate random inputs (100+ per property by default) to
verify that constraints hold across the entire input space, not just
hand-picked examples.

### Commands

```bash
npm test -- --grep "constraint.pbt"
```

### Expected output

- All property tests pass across the configured number of random inputs.

### On failure

1. Report the **counterexample** found by fast-check.
2. Include the **shrunk minimal input** — fast-check automatically reduces
   failing inputs to the smallest reproducing case.
3. Identify which property was violated and the constraint it represents.
4. Do **not** proceed to Layer 4 until all property tests pass.

---

## Layer 4: Mutation Testing (Stryker)

Mutation testing verifies that the property tests from Layer 3 are strong
enough to detect real faults. Stryker introduces small code mutations and
checks whether at least one test fails for each.

### Commands

```bash
npx stryker run
```

### Expected output

- JSON report containing:
  - **Mutation score**: killed mutants / total mutants.
  - Per-mutant status: killed, survived, timed out, or no coverage.
- Default target: mutation score >= 80%.

### On failure

If surviving mutants bring the score below the target, follow the feedback
loop described in [mutation-feedback-guide.md](mutation-feedback-guide.md).

---

## Execution Order

```
Layer 1 (Lint)
  │ pass
  ▼
Layer 2 (Validation)
  │ pass
  ▼
Layer 3 (PBT)
  │ pass
  ▼
Layer 4 (Mutation Testing)
```

- Each layer assumes all previous layers are green.
- Layer 4 depends on Layer 3 tests existing — without property tests, there
  is nothing for Stryker to evaluate mutations against.
- A full enforcement run executes all four layers in sequence. Partial runs
  (e.g., Layers 1-2 only) are acceptable during early development but the
  complete pipeline must pass before merging.
