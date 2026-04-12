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

## TypeScript Toolchain (supported)

### Layer 1: Lint

#### Biome

Static analysis, formatting, and (via Biotype) TypeScript type inference.

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
- **Run:** Compile with `tsc` or run tests — Typia validates at compile time
  and runtime
- **Pass/fail:** Compilation success = types match. `TypeGuardError` at runtime
  = validation failure at a trust boundary. Test runner reports assertion
  failures with the mismatched type path.

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

## Other Languages (planned)

No detailed commands yet. Toolchain mapping for future implementation:

| Layer | OCaml | Rust | Python |
|---|---|---|---|
| Lint | ocamlformat | clippy | ruff |
| Validation | Gospel | — | pydantic |
| PBT | QCheck / Ortac | proptest | Hypothesis |
| Mutation | — | cargo-mutants | mutmut |
