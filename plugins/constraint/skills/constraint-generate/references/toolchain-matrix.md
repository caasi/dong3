# Toolchain Matrix

Deterministic toolchain reference for `constraint-generate`. Maps constraint
kinds and enforce directives to concrete tools, with install/run commands and
pass/fail interpretation.

## Language Detection

Detect the repo's primary language by checking for marker files at the repo root:

| Marker file | Language |
|---|---|
| `package.json` or `tsconfig.json` | TypeScript |
| `dune-project` | OCaml |
| `Cargo.toml` | Rust |
| `pyproject.toml` or `setup.py` | Python |

If multiple markers are detected, ask the user which language to target.

**CLI naming note:** The ast-grep binary is called `sg` when installed via
cargo or system package, and `npx ast-grep` when run via npm. They are the
same tool — use whichever matches the project's package manager.

## Constraint Kind/Enforce → Toolchain Layer

| `enforce` value | Toolchain layer |
|---|---|
| `lint`, `ast-grep` | Layer 1 (Lint) |
| `validation` | Layer 2 (Validation) |
| `pbt` | Layer 3 (PBT) |
| `mutation` | Layer 4 (Mutation) |

When a constraint's frontmatter omits `enforce`, use the Kind classification
table's "typical enforce" column as the default (see constraint-format.md).

---

## TypeScript Toolchain

### Layer 1: Lint

#### Biome

Static analysis and formatting for TypeScript projects.

- **Install:** `npm install --save-dev --save-exact @biomejs/biome`
- **Init:** `npx @biomejs/biome init`
- **Run:** `npx @biomejs/biome check .`
- **Pass/fail:** Exit code 0 = clean. Non-zero = violations found. Output lists
  each violation with file path, line number, and rule name.

#### ast-grep

Structural code search for prohibition enforcement. Constraint-generate writes
`.ast-grep/rules/*.yml` rule files from prohibition constraints.

- **Install:** `npm install --save-dev @ast-grep/cli`
- **Run:** `npx ast-grep scan`
- **Pass/fail:** Exit code 0 = no matches (clean). Non-zero = prohibited
  patterns found. Output lists each match with file path, line range, and the
  matched code snippet.

### Layer 2: Validation

Runtime type validation at trust boundaries. Choose a library based on
existing project dependencies:

1. Check `package.json` dependencies for `zod`, `arktype`, or `typia`
2. If one is already present, use it (avoid adding a second validation library)
3. If none is present, default to **Typia** for new projects (zero schema
   duplication — validates directly from TypeScript types)

#### Typia (preferred for new projects)

Zero schema duplication — generates validators directly from TypeScript types.

- **Install:** `npm install --save-dev typia`
- **Init:** `npx typia setup` (configures the TypeScript transformer)
- **Run:** First run `tsc --noEmit` to confirm the TypeScript/Typia transformer
  is configured correctly. Then run unit/integration tests that execute Typia
  validators (`typia.assert(...)`, `typia.validate(...)`) at trust boundaries.
- **Pass/fail:** `tsc --noEmit` success = build/tooling check only; it does
  **not** prove runtime data is valid. Validation passes when validator-exercising
  tests complete without `TypeGuardError`. Runtime failures indicate a
  trust-boundary type mismatch.

#### ArkType (set-theory based)

- **Install:** `npm install arktype`
- **Run:** Run unit tests that call `type.assert(data)` at trust boundaries
- **Pass/fail:** `ArkErrors` thrown = validation failure. Test runner reports
  which fields failed and why.

#### Zod (if already in stack)

- **Install:** `npm install zod`
- **Run:** Run unit tests that call `schema.parse(data)` at trust boundaries
- **Pass/fail:** `ZodError` thrown = validation failure. Error contains an
  `issues` array with path and message for each failing field.

### Layer 3: PBT (Property-Based Testing)

#### fast-check

**Detection:** Check if `fast-check` appears in `package.json` devDependencies.

- **Install:** `npm install --save-dev fast-check`
- **Run:** `npm test -- --grep constraint.pbt`
- **Pass/fail:** All property tests pass (100+ random inputs per property by
  default) = clean. On failure, fast-check reports a **counterexample** — the
  shrunk minimal input that violates the property. The output includes the
  failing property name, the seed (for reproducibility), and the minimal
  counterexample value.

### Layer 4: Mutation Testing

#### Stryker Mutator

**Detection:** Check if `@stryker-mutator/core` appears in `package.json`
devDependencies.

- **Install:** `npm install --save-dev @stryker-mutator/core`
- **Init:** `npx stryker init` (interactive setup — selects test runner,
  mutator plugins, and reporter)
- **Run:** `npx stryker run`
- **Pass/fail:** Produces a JSON report with a **mutation score** (killed
  mutants / total mutants). Default target: 80%. Below target = failing.
  The report lists each mutant with its location, mutation type, and status
  (killed, survived, timeout, no coverage). See `mutation-feedback-guide.md`
  in the `constraint-enforce` skill for the feedback loop on surviving mutants.

---

## OCaml Toolchain

### Layer 1: Lint

#### ocamlformat

- **Install:** `opam install ocamlformat` (pin version in `.ocamlformat`: `version = 0.27.0`)
- **Run:** `dune fmt` (requires `(formatting (enabled_for ocaml))` in `dune-project`)
- **Pass/fail:** Exit code 0 = clean. Exit code 1 = files differ from formatted output.

#### semgrep (structural lint)

ast-grep does not support OCaml. Use semgrep instead.

- **Install:** `pip install semgrep` or `brew install semgrep`
- **Run:** `semgrep --config=auto --lang=ocaml .` or custom YAML rules
- **Pass/fail:** Exit code 0 = no matches. Exit code 1 = findings (treat as violations). Other non-zero = config/runtime error; surface stderr and stop.

### Layer 2: Validation

#### Gospel + Ortac

Gospel adds spec annotations to `.mli` files (`(*@ requires x > 0 *)`). Ortac generates QCheck tests from Gospel specs.

- **Install:** `opam install gospel ortac-runtime ortac-qcheck-stm`
- **Run:** Ortac-generated tests run via `dune runtest`
- **Pass/fail:** Standard test exit codes.

**Note:** Gospel/Ortac is still maturing. For simpler cases, manual validation with pattern matching is idiomatic OCaml.

### Layer 3: PBT

#### QCheck

- **Install:** `opam install qcheck-core qcheck-alcotest`
- **Dune:** Add `(libraries qcheck-core qcheck-alcotest alcotest)` to the test stanza.
- **Run:** `dune runtest`
- **Pass/fail:** Exit code 0 = pass. On failure, QCheck prints a shrunk counterexample to stderr.

### Layer 4: Mutation Testing

#### mutaml

- **Install:** `opam install mutaml`
- **Run:** `mutaml-runner dune runtest` then `mutaml-report`
- **Pass/fail:** Report shows kill rate (%). Set your own threshold. Covers arithmetic, boolean, and pattern-match mutations.

**Note:** Functional but niche. Only real option for OCaml mutation testing.

---

## Rust Toolchain

### Layer 1: Lint

#### clippy

- **Run:** `cargo clippy --all-targets --all-features -- -D warnings`
- **Pass/fail:** Exit code 0 = clean. Non-zero = warnings (treated as errors with `-D warnings`).

#### ast-grep (structural lint)

ast-grep supports Rust via tree-sitter-rust.

- **Install:** `cargo install ast-grep`
- **Run:** `sg scan` with YAML rules
- **Pass/fail:** Exit code 0 = no matches. Treat rule matches as violations. If `sg scan` fails due to invalid rules/config or runtime errors, treat as execution failure and report distinctly.

### Layer 2: Validation

Rust's type system + `serde` handles most validation at compile time. For runtime constraints on external input:

- **validator:** `cargo add validator --features derive` — derive macros for struct field validation (`#[validate(range(min = 1, max = 100))]`)
- **garde:** newer alternative with similar derive-macro approach
- **nutype:** newtype wrappers with built-in validation

### Layer 3: PBT

#### proptest

- **Install:** Add `proptest = "1"` to `[dev-dependencies]` in `Cargo.toml`
- **Run:** `cargo test` (proptest macros generate standard `#[test]` functions)
- **Pass/fail:** Exit code 0 = pass. On failure, prints minimal shrunk counterexample. Seeds stored in `proptest-regressions/` for replay.

### Layer 4: Mutation Testing

#### cargo-mutants

- **Install:** `cargo install cargo-mutants`
- **Run:** `cargo mutants`
- **Pass/fail:** Summary table with caught/missed/timeout/unviable counts. Mutation score = caught / (caught + missed). Results written to `mutants.out/`.

---

## Python Toolchain

### Layer 1: Lint

#### ruff

- **Install:** `pip install ruff` or `uv tool install ruff`
- **Run:** `ruff check .` (lint), `ruff format --check .` (format check)
- **Pass/fail:** Exit code 0 = clean. Exit code 1 = violations. Use `--fix` for auto-fix.

#### ast-grep (structural lint)

ast-grep supports Python via tree-sitter-python.

- **Install:** `brew install ast-grep`, `npm install --global @ast-grep/cli`, or download a release binary
- **Run:** `sg scan` with YAML rules (`language: Python`)
- **Pass/fail:** Exit code 0 = no matches. Treat rule matches as violations. If `sg scan` fails due to invalid rules/config or runtime errors, treat as execution failure and report distinctly.

#### semgrep (structural lint, alternative)

Larger rule library than ast-grep; Python-native.

- **Install:** `pip install semgrep` or `brew install semgrep`
- **Run:** `semgrep --config=auto .`
- **Pass/fail:** Exit code 0 = no findings. Exit code 1 = findings (treat as violations). Other non-zero = config/runtime error; surface stderr and stop.

### Layer 2: Validation

#### pydantic (v2)

- **Install:** `pip install pydantic`
- **Run:** Run tests that exercise pydantic models at trust boundaries.
- **Pass/fail:** Raises `ValidationError` with structured error details on bad input.

### Layer 3: PBT

#### Hypothesis

- **Install:** `pip install hypothesis` or `uv add hypothesis`
- **Run:** `pytest` (Hypothesis works as a pytest plugin automatically)
- **Pass/fail:** Standard pytest exit codes. On failure, prints minimal counterexample. Flaky failures stored in `.hypothesis/` for deterministic replay.

### Layer 4: Mutation Testing

#### mutmut

- **Install:** `pip install mutmut`
- **Run:** `mutmut run --paths-to-mutate=src/` then `mutmut results`
- **Pass/fail:** Reports survived/killed/total. Mutation score = killed/total. No built-in threshold flag; parse output or use `mutmut junitxml` for CI.

---

## Unlisted Languages

If the detected language is not in this matrix, research the ecosystem's
idiomatic tools for each layer before generating. Look for: a formatter/linter,
a PBT library, and a mutation testing tool. Update this matrix with findings.
