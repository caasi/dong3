---
name: compose
description: This skill should be used when the user asks to "describe a workflow", "compose a pipeline", "write a pipeline in DSL", "plan tool composition", "validate a pipeline", "check DSL syntax", mentions Arrow DSL or `.arr` files, or wants to structure multi-step agent workflows before execution. Also triggers when the user asks to install `ocaml-compose-dsl`.
---

# Compose — Arrow DSL for Agent Workflow Composition

Describe multi-step workflows using an Arrow-style DSL, then validate them structurally with the `ocaml-compose-dsl` binary. The DSL is a **planning language, not an execution engine** — the agent itself expands the DSL into concrete tool calls.

## Prerequisites

The `ocaml-compose-dsl` binary must be installed at `~/.local/bin/ocaml-compose-dsl`. If not found, inform the user and offer to run the install script bundled with this skill at `scripts/install.sh`. The script downloads the correct pre-built binary from [caasi/ocaml-compose-dsl releases](https://github.com/caasi/ocaml-compose-dsl/releases) for the current platform (Linux x86_64, macOS x86_64, macOS arm64) and places it in `~/.local/bin/`.

Ensure `~/.local/bin` is in `PATH`.

### Version Check

This skill requires **v0.11.0** or later. After confirming the binary exists, verify the version:

```bash
ocaml-compose-dsl --version
```

If the output is lower than `0.11.0` or the `--version` flag is not recognized, the binary is outdated. Offer to re-run `scripts/install.sh` to upgrade to the latest release.

## Core Concepts

### Arrow Combinators

| Syntax | Meaning | Tool Call Expansion |
|--------|---------|---------------------|
| `>>>` | Sequential — run left then right (infixr 1) | Sequential tool calls |
| `\|\|\|` | Branch — try left, fallback to right (infixr 2) | Conditional fallback |
| `***` | Parallel — run both concurrently (infixr 3) | Multiple tool calls in one message |
| `&&&` | Fanout — run both on same input (infixr 3) | Multiple tool calls, same input |
| `loop()` | Feedback — repeat body iteratively | Retry / iterative refinement |
| `?` | Question — marks step as producing Either | Branching via `\|\|\|` |
| `(expr)` | Grouping | Precedence control |
| `\x -> expr` | Lambda — parameterized workflow fragment | Abstraction (not a tool call) |
| `let x = expr in body` | Let binding — name a workflow fragment | Abstraction (not a tool call) |
| `()` | Unit — no-input value or trigger | Standalone value |
| `;` | Statement separator — multiple independent pipelines | Separate programs |

All operators are **right-associative**. `***` and `&&&` bind tighter than `|||`, which binds tighter than `>>>`.

### Node Design

Nodes describe **purpose**, not specific tools:

```
read(source: "data.csv")  -- ref: Read, cat, fetch
```

- The node name and arguments express intent
- Comments (`--`) annotate purpose or suggest reference tools
- The expanding agent chooses which concrete tool to use

### Type Annotations

Nodes and terms can carry optional type annotations using `::`:

```
fetch(url: "https://example.com") :: URL -> HTML
  >>> parse :: HTML -> Data
  >>> format(as: report) :: Data -> Report
```

Annotations document intended data flow for humans and agents reading the pipeline. The checker parses them but performs no type checking.

Type names can be identifiers or `()` (unit): `:: () -> Server`, `:: Input -> ()`.

### Abstraction

Lambda and let bindings are tools for organizing complex workflows — naming reusable fragments and parameterizing patterns. They are part of the DSL, not syntactic sugar that disappears.

**Lambda** creates parameterized workflow fragments:

```
\name -> hello(to: name) >>> respond
\trigger, fix -> loop(trigger >>> (pass ||| fix))
```

**Let** names a workflow fragment for reuse:

```arrow
let review = \trigger, fix ->
  loop(trigger >>> (pass ||| fix))
in
let phase1 = gather >>> review(check?, rework) in
let phase2 = build >>> review(test?, fix) in
phase1 >>> phase2
```

- `let` requires `in` to delimit scope
- `let...in` works inside parentheses: `(let x = a in x)`
- Named and positional arguments can be freely mixed: `push(remote: origin, v)` where `v` is a positional expression
- Reserved words: `let`, `loop`, `in` cannot be used as identifiers

### Statements

A program can contain multiple independent pipelines separated by `;`:

```arrow
planning :: Doc -> Commit
  >>> commit(branch: main);

implementation :: Code -> Commit
  >>> git_branch(pattern: "feature/*") :: Code -> Branch
  >>> commit :: Branch -> Commit
```

- Trailing semicolon is optional
- Semicolons are not allowed inside parentheses

### Unit

`()` is a value representing "no input" or "trigger":

```arrow
() >>> start_server :: () -> Server
```

- `()` is also valid as a type name in annotations: `:: () -> Server`, `:: Input -> ()`
- `f()` passes Unit as a positional argument — it is not an empty argument list

For detailed grammar (EBNF), combinators, and examples, consult **`references/dsl-grammar.md`**.

## Workflow

### 1. Plan the Pipeline

When given a multi-step task, draft the workflow as DSL before executing:

```
read(source: "config.yaml")
  >>> validate(schema: app_config)
  >>> (extract(section: database) *** extract(section: logging))
  >>> apply(target: environment)
```

### 2. Validate Structure

Write the DSL to a `.arr` file and validate with the checker:

```bash
echo 'read(source: "config.yaml") >>> validate(schema: app_config)' | ocaml-compose-dsl
```

Or from a file:

```bash
ocaml-compose-dsl pipeline.arr
```

For Markdown files with embedded arrow blocks (fenced with `arrow` or `arr`):

```bash
ocaml-compose-dsl --literate README.md
```

Any Markdown file can be a literate Arrow document. Use `arrow` or `arr` as the code fence language tag.

The binary exits `0` with AST output (OCaml constructor format) on valid input, `1` with error messages (with `line:col` positions) on structural problems. Warnings go to stderr without affecting exit code. Fix any structural errors before proceeding.

### 3. Expand and Execute

After validation, expand each node into concrete tool calls based on available tools. The DSL is the plan; execution follows the plan's structure:

- `>>>` nodes → execute sequentially
- `***` nodes → execute as parallel tool calls in one message (each side gets its own input)
- `&&&` nodes → execute as parallel tool calls in one message (both sides get the same input)
- `|||` nodes → try first branch, use second on failure
- `loop()` → repeat the body iteratively (use `?` + `|||` for exit conditions)

### 4. Save Successful Pipelines

Store validated, successfully-executed pipelines as `.arr` files for reuse. Include comments describing the use case:

```
-- Deploy config update: validate then apply to staging
read(source: "config.yaml")       -- ref: Read
  >>> validate(schema: app_config) -- ref: Bash("yq")
  >>> apply(target: staging)       -- ref: Bash("kubectl apply")
```

When a similar task arises, load and modify the existing pipeline instead of reasoning from scratch.

### Checker Warnings

The checker emits warnings to stderr without affecting exit code. Currently:

- `?` without matching `|||` — the Either produced by `?` has no consumer
- `?` as operand of `|||` — `?` already implies `|||` with an implicit empty branch; using both is redundant
- `branch` without matching `merge` in the same statement — warns that an epistemic branch has no convergence point
- `leaf` without matching `check` in the same statement — suggests adding a verification step after the bounded reasoning zone

Warnings help catch structural oversights early. They do not block validation.

### Epistemic Conventions

Five identifier names serve as **epistemic operators** — cognitive role markers for human-LLM shared reasoning scaffolds, inspired by [λ-RLM](https://github.com/lambda-calculus-LLM/lambda-RLM). They are ordinary identifiers (not reserved words) matched by name only.

| Name | Intent | Common Pattern |
|------|--------|----------------|
| `gather` | Collect evidence/sub-questions before reasoning | `gather >>> leaf` |
| `branch` | Explore multiple candidate paths | `branch >>> ... >>> merge` |
| `merge` | Converge candidates into auditable artifact | `... >>> merge >>> check?` |
| `leaf` | High-cost reasoning zone — bounded sub-problem | `leaf >>> check?` |
| `check` | Verifiable validation step | `check? >>> (pass \|\|\| fix)` |

The checker lints two conventions: `branch` without `merge`, and `leaf` without `check`. These are warnings, not errors.

**Avoiding false positives:** If a node named `branch` means something else (e.g., git branching), rename it to avoid the lint — e.g., `git_branch(pattern: "feature/*")`.

## Common Patterns

### Data Processing

```
read(source: input) >>> parse(format: fmt) >>> transform(mapping: m) >>> write(dest: output)
```

### Resilient Fetch

```
fetch(url: primary)?
  >>> (process ||| (fetch(url: mirror) >>> process))
```

### Test-Fix Loop

```
loop(
  edit(target: code, change: fix)
    >>> test(suite: relevant)
    >>> "all tests pass"?
    >>> (done ||| retry)
)
```

### Parallel Analysis

```
read(source: file)
  >>> (lint *** typecheck *** test(suite: unit))
  >>> report(format: summary)
```

### Fanout (Same Input, Multiple Checks)

```
(lint &&& test)
  >>> gate(require: [pass, pass])
  >>> (build_linux(profile: static) *** build_macos(profile: release))
  >>> upload(tag: "v0.1.0")
```

`&&&` feeds the same input to both sides; `***` feeds separate inputs to each side.

### Numeric Parameters

Numeric literals — integers, floats, negatives, and unit suffixes — can be used directly as values:

```
resize(width: 1920, height: 1080)
  >>> compress(quality: 85)
  >>> dose(amount: 100mg)       -- unit suffix
  >>> adjust(offset: -3.14)     -- negative float
```

### Unicode Identifiers

Node names, argument keys, and unit suffixes support full UTF-8 identifiers, including non-ASCII characters. The DSL works naturally with non-Latin scripts:

```
読み込み(ソース: "データ.csv")
  >>> フィルタ(条件: "年齢 > 18")
  >>> 出力
```

```
加熱(溫度: 72.5℃, 時間: 30分鐘)
  >>> 冷卻(目標: 4℃)
```

Error positions report codepoint-level columns, not byte offsets, so diagnostics stay accurate for multibyte characters.

### Reusable Review Loop

```arrow
let review = \trigger, fix ->
  loop(trigger >>> (pass ||| fix))
in
let phase1 = gather >>> review(check?, rework) in
let phase2 = build >>> review(test?, fix) in
phase1 >>> phase2
```

## Additional Resources

### Examples

The `examples/` directory contains ready-to-use `.arr` files demonstrating common patterns:

- **`examples/update-skill-from-upstream.arr`** — Meta-workflow: how this skill checks the upstream repo and aligns docs, examples, and metadata. Demonstrates `&&&` fanout, `***` parallel, and multi-phase pipelines
- **`examples/data-pipeline.arr`** — Read → parse → filter → parallel aggregation → format
- **`examples/ci-pipeline.arr`** — Fanout lint+test → gate → parallel multi-platform build → upload
- **`examples/test-fix-loop.arr`** — Iterative edit-test feedback loop using `?` + `|||` for exit condition
- **`examples/resilient-fetch.arr`** — Primary/mirror fallback with `|||`
- **`examples/numeric-literals.arr`** — Numeric literal values: integers, floats, negatives, and unit suffixes
- **`examples/mixed-par-fanout.arr`** — Mixing `***` and `&&&`: precedence behavior and explicit grouping
- **`examples/unicode-identifiers.arr`** — Unicode node names, argument keys, and unit suffixes with non-Latin scripts
- **`examples/question-operator.arr`** — Question operator `?`: marking steps as producing Either for `|||` branching
- **`examples/type-annotations.arr`** — Type annotation syntax (`:: Ident -> Ident`) on sequential, parallel, fanout, loop, and question terms
- **`examples/lambda.arr`** — Lambda expressions: parameterized workflow fragments, multi-param, positional arguments
- **`examples/let-binding.arr`** — Let bindings: named fragments, nested lets, let inside parentheses, multi-phase composition
- **`examples/unit-type.arr`** — Unit value and type: `()` standalone, in type annotations, `f()` semantics
- **`examples/multi-statement.arr`** — Semicolon statement separator: independent pipelines, trailing semicolon
- **`examples/epistemic-debugging.arr`** — Systematic debugging workflow using all five epistemic operators: gather symptoms, branch hypotheses, merge evidence, leaf root-cause analysis, check fix verification

The following OSINT examples are illustrative and should be used only in lawful, ToS-compliant, and privacy-respecting contexts. Person-targeting examples model defensive workflows (tracing dox attackers) and include de-identification, public methodology disclosure, and legal reporting steps.

- **`examples/osint-social-media-forensics.arr`** — Trace who spread a victim's personal data; de-identify results, publish methodology, report to law enforcement
- **`examples/osint-account-correlation.arr`** — Trace the source of a dox attack via cross-platform correlation; de-identify before public disclosure, file full evidence with authorities
- **`examples/osint-evidence-compilation.arr`** — Compile scattered dox evidence into court-ready folders; publish redacted methodology summary, export full evidence for legal proceedings
- **`examples/osint-geolocation.arr`** — Geolocate facilities from broadcast footage by cross-referencing with satellite imagery
- **`examples/osint-media-monitoring.arr`** — Monitor state media for military unit designations and map to known bases
- **`examples/osint-infrastructure-change.arr`** — Temporal satellite imagery comparison to detect new military construction
- **`examples/frontend-project.arr`** — Full product lifecycle: discovery → outsourced design → handoff → in-house implementation → delivery. Stress-tests all combinators at 225 lines

Use these as starting points: copy, modify node names/arguments, and validate with `ocaml-compose-dsl`.

### Reference Files

- **`references/dsl-grammar.md`** — Full EBNF grammar, combinator table, node design principles, structural rules, and extended examples

### Scripts

- **`scripts/install.sh`** — Platform-aware installer for `ocaml-compose-dsl` binary. Downloads from GitHub Releases to `~/.local/bin/`

### External

- [caasi/ocaml-compose-dsl](https://github.com/caasi/ocaml-compose-dsl) — Source repository with parser, checker, and CI/CD
- [Plan 000: Arrow DSL Design](https://github.com/caasi/ocaml-compose-dsl/blob/main/docs/superpowers/plans/000-dsl.md) — Original design document
