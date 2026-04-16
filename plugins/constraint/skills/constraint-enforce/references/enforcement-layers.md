# Enforcement Layers

Constraints are enforced in four layers, executed in order. Each layer builds
on the guarantees provided by the previous one. **Fail fast**: if a layer
fails, fix the violations before proceeding to the next layer.

For concrete install/run commands per language, consult the **toolchain matrix**
at `constraint-generate/references/toolchain-matrix.md`. This document describes
the semantics of each layer; the toolchain matrix provides the commands.

---

## Layer 1: Lint (static analysis + structural rules)

Static analysis catches style violations, banned patterns, and structural
anti-patterns before any code runs.

**Typical tools by language:**

| Language | Formatter/Linter | Structural lint |
|---|---|---|
| TypeScript | Biome | ast-grep |
| OCaml | ocamlformat | semgrep |
| Rust | clippy | ast-grep |
| Python | ruff | ast-grep / semgrep |

### Expected output

- Exit code `0` = clean, no violations.
- Non-zero exit code = one or more violations.

### On failure

1. Collect every violation with **file path + line number**.
2. Present violations grouped by rule.
3. Suggest auto-fixable corrections where the tool supports it.
4. Do **not** proceed to Layer 2 until all lint violations are resolved.

---

## Layer 2: Validation (runtime type/schema enforcement)

Runtime validation ensures that data crossing trust boundaries conforms to
declared schemas or type constraints. The necessity and approach varies by
language's type system (see Type System Context below).

**Typical tools by language:**

| Language | Validation approach |
|---|---|
| TypeScript | Typia / ArkType / Zod at trust boundaries |
| OCaml | Pattern matching + Gospel/Ortac for specs |
| Rust | Type system + serde; validator/garde for external input |
| Python | pydantic models at trust boundaries |

### Expected output

- Build/type check passes (language-specific).
- All validation unit tests pass = runtime validators confirm data conforms
  to schemas at trust boundaries.

### On failure

1. Report each type mismatch at the trust boundary where it occurs.
2. Include the expected type and the actual type (or value shape).
3. Do **not** proceed to Layer 3 until all type mismatches are resolved.

### Type System Context

A language's type system is itself a constraint enforcement mechanism. The
stronger the type system, the less runtime validation is needed:

| Language | Type system | What the type system enforces | What still needs runtime validation |
|---|---|---|---|
| **OCaml** | Strong static, algebraic data types, exhaustive pattern matching | Shape, variants, nullability (option types). The compiler rejects ill-typed programs; pattern match warnings catch missing cases. | External input (JSON, network), business-rule ranges, cross-field invariants |
| **Rust** | Strong static, ownership + borrowing, algebraic types, no null | Shape, variants, memory safety, thread safety. The borrow checker eliminates data races and use-after-free at compile time. | External input (serde boundaries), business-rule ranges, cross-field invariants |
| **TypeScript** | Structural, gradual (any/unknown escape hatches), erased at runtime | Shape at compile time only. Types disappear at runtime — `any` and type assertions can bypass checks. Advanced type-level techniques (phantom types, HKT emulation via defunctionalization) exist but are uncommon and still do not provide runtime guarantees, so do not assume a project uses them. | **Everything at trust boundaries** — external input, API responses, DB results. The type system provides zero runtime guarantees. |
| **Python** | Dynamic, optional type hints (mypy/pyright) | Nothing at runtime by default. Type hints are documentation unless enforced by a checker. | **Everything at trust boundaries**, plus internal data flows where type hints are absent or unenforced |

**Implication for constraint enforcement:** In OCaml and Rust, Layer 2 can
focus narrowly on external input boundaries. In TypeScript and Python, Layer 2
must guard every trust boundary because the type system does not enforce types
at runtime.

---

## Layer 3: PBT (property-based testing)

Property-based tests generate random inputs (100+ per property by default) to
verify that constraints hold across the entire input space, not just
hand-picked examples.

**Typical tools by language:**

| Language | PBT library |
|---|---|
| TypeScript | fast-check |
| OCaml | QCheck |
| Rust | proptest |
| Python | Hypothesis |

### Expected output

- All property tests pass across the configured number of random inputs.

### On failure

1. Report the **counterexample** found by the PBT library.
2. Include the **shrunk minimal input** — PBT libraries automatically reduce
   failing inputs to the smallest reproducing case.
3. Identify which property was violated and the constraint it represents.
4. Do **not** proceed to Layer 4 until all property tests pass.

---

## Layer 4: Mutation Testing

Mutation testing verifies that the property tests from Layer 3 are strong
enough to detect real faults. The mutation tool introduces small code mutations
and checks whether at least one test fails for each.

**Typical tools by language:**

| Language | Mutation tool |
|---|---|
| TypeScript | Stryker |
| OCaml | mutaml |
| Rust | cargo-mutants |
| Python | mutmut |

### Expected output

- Report containing:
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
  is nothing for the mutation tool to evaluate mutations against.
- A full enforcement run executes all four layers in sequence. Partial runs
  (e.g., Layers 1-2 only) are acceptable during early development but the
  complete pipeline must pass before merging.
