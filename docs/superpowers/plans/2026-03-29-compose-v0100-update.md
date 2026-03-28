# Compose Skill v0.10.0 Update — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the compose skill with upstream `ocaml-compose-dsl` v0.10.0 — adding lambda, let...in, unit type, semicolon statements, and literate mode to all documentation, grammar reference, and examples.

**Architecture:** Documentation-only update. No runtime code changes. The upstream README EBNF is the source of truth for grammar. SKILL.md stays concise as the LLM entry point; detailed grammar lives in `references/dsl-grammar.md`. New `.arr` examples demonstrate new features; selected existing examples get rewritten with let/lambda where it improves clarity.

**Tech Stack:** `ocaml-compose-dsl` binary (v0.10.0) for validation, `gh` CLI for fetching upstream README.

**Spec:** `docs/superpowers/specs/2026-03-29-compose-v0100-update-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `plugins/compose/skills/compose/references/dsl-grammar.md` | Full EBNF grammar reference (rewrite from upstream) |
| Modify | `plugins/compose/skills/compose/SKILL.md` | LLM entry point — version, combinator table, new sections, patterns |
| Create | `plugins/compose/skills/compose/examples/lambda.arr` | Lambda expression examples |
| Create | `plugins/compose/skills/compose/examples/let-binding.arr` | Let...in binding examples |
| Create | `plugins/compose/skills/compose/examples/unit-type.arr` | Unit value and type examples |
| Create | `plugins/compose/skills/compose/examples/multi-statement.arr` | Semicolon statement separator examples |
| Modify | `plugins/compose/skills/compose/examples/frontend-project.arr` | Extract repeated review-loop pattern with let/lambda |
| Modify | `plugins/compose/skills/compose/examples/ci-pipeline.arr` | Name build pipeline with let |
| Modify | `plugins/compose/skills/compose/examples/test-fix-loop.arr` | Parameterize loop body with lambda |
| Modify | `plugins/compose/skills/compose/examples/update-skill-from-upstream.arr` | Rewrite with let/lambda, reflect actual session workflow |
| Modify | `plugins/compose/skills/compose/README.md` | User-facing docs — features, combinator table, examples |
| Modify | `.claude-plugin/marketplace.json` | Version bump `0.7.0` → `0.10.0` |
| Modify | `CLAUDE.md` | Compose description update — version, combinators |

---

### Task 0: Install ocaml-compose-dsl v0.10.0

The binary is not currently installed on this machine. All subsequent validation steps depend on it.

**Files:**
- Run: `plugins/compose/skills/compose/scripts/install.sh`

- [ ] **Step 1: Run the install script**

```bash
bash plugins/compose/skills/compose/scripts/install.sh
```

Expected: downloads `ocaml-compose-dsl-macos-x86_64` to `~/.local/bin/ocaml-compose-dsl`.

- [ ] **Step 2: Verify version**

```bash
~/.local/bin/ocaml-compose-dsl --version
```

Expected: output contains `0.10.0`.

- [ ] **Step 3: Ensure binary is in PATH**

If `which ocaml-compose-dsl` fails, add `~/.local/bin` to PATH for this session:

```bash
export PATH="${HOME}/.local/bin:${PATH}"
```

---

### Task 1: Rewrite dsl-grammar.md from upstream EBNF

This is the foundation — all other files reference the grammar.

**Files:**
- Modify: `plugins/compose/skills/compose/references/dsl-grammar.md`

- [ ] **Step 1: Fetch upstream README for the complete EBNF**

```bash
gh api repos/caasi/ocaml-compose-dsl/contents/README.md --jq '.content' | base64 --decode > /tmp/upstream-readme.md
```

- [ ] **Step 2: Rewrite dsl-grammar.md**

Replace the entire file. Structure:

1. **Title:** `# Arrow DSL Grammar Reference`
2. **EBNF section:** Copy the complete grammar from the upstream README verbatim. This includes `program`, `stmt`, `let_expr`, `lambda`, `pipeline`, `seq_expr`, `alt_expr`, `par_expr`, `typed_term`, `type_expr`, `type_name`, `term`, `call_args`, `call_arg`, `arg_key`, `value`, `ident`, `reserved`, `ident_start`, `ident_char`, `string`, `number`, `comment`.
3. **Prose after EBNF:** Keep the existing explanatory paragraphs (right-associativity, UTF-8 identifiers, typed_term binding level) but update them to reference new productions — `program` as top-level, `stmt` containing `let_expr | pipeline`, semicolons between statements, `reserved` word exclusion, `()` as type name, `call_arg` with positional + named mixing.
4. **Combinators table:** Expand the existing table. Add rows for:
   - `\` (lambda): `Arrow a b` (parameterized workflow fragment)
   - `let...in`: named binding (abstraction, not a combinator per se — note this)
   - `()` (unit): unit value / type
   - `;` (semicolon): statement separator — multiple independent pipelines in one program
5. **Node Design section:** Keep as-is.
6. **Examples section:** Keep all existing examples. Add new subsections:
   - **Lambda Expressions** — `\name -> hello(to: name) >>> respond` and multi-param
   - **Let Bindings** — `let review = ... in ...` and nested lets
   - **Unit** — `()` standalone, `() >>> start_server :: () -> Server`, `f()` semantics
   - **Multi-Statement** — `planning >>> commit; implementation >>> branch >>> commit`
   - **Literate Arrow Documents** — explain `arrow`/`arr` code fence, `.md` convention
   - **Mixed Call Arguments** — named + positional in the same call: `push(remote: origin, v)` where `v` is a positional pipeline expression
7. **Structural Rules section:** Keep existing content. Add: semicolons not valid inside parentheses.
8. **Warnings section:** Keep existing content as-is.

- [ ] **Step 3: Validate the grammar reference with literate mode**

```bash
ocaml-compose-dsl --literate plugins/compose/skills/compose/references/dsl-grammar.md
```

Expected: exit 0 (all arrow blocks in the file parse cleanly). If any blocks fail, fix the syntax and re-validate.

- [ ] **Step 4: Commit**

```bash
git add plugins/compose/skills/compose/references/dsl-grammar.md
git commit -m "docs(compose): rewrite dsl-grammar.md to match upstream v0.10.0 EBNF"
```

---

### Task 2: Update SKILL.md

**Files:**
- Modify: `plugins/compose/skills/compose/SKILL.md`

- [ ] **Step 1: Update version check**

Change line 18 from:

```
This skill requires **v0.7.0** or later.
```

to:

```
This skill requires **v0.10.0** or later.
```

Also update the comparison text on line 24 from `0.7.0` to `0.10.0`.

- [ ] **Step 2: Update Arrow Combinators table**

In the existing table (lines 30-39):
- Rename `()` → `(expr)` in the Grouping row (row with "Precedence control")
- Add new rows after the existing `()` Grouping row:

| `\x -> expr` | Lambda — parameterized workflow fragment | Abstraction (not a tool call) |
| `let x = expr in body` | Let binding — name a workflow fragment | Abstraction (not a tool call) |
| `()` | Unit — no-input value or trigger | Standalone value |
| `;` | Statement separator — multiple independent pipelines | Separate programs |

- [ ] **Step 3: Add Abstraction section**

Insert after the Type Annotations section (after line 66), before "## Workflow":

```markdown
### Abstraction

Lambda and let bindings are tools for organizing complex workflows — naming reusable fragments and parameterizing patterns. They are part of the DSL, not syntactic sugar that disappears.

**Lambda** creates parameterized workflow fragments:

\```
\name -> hello(to: name) >>> respond
\trigger, fix -> loop(trigger >>> (pass ||| fix))
\```

**Let** names a workflow fragment for reuse:

\```
let review = \trigger, fix ->
  loop(trigger >>> (pass ||| fix))
in
let phase1 = gather >>> review(check?, rework) in
let phase2 = build >>> review(test?, fix) in
phase1 >>> phase2
\```

- `let` requires `in` to delimit scope
- `let...in` works inside parentheses: `(let x = a in x)`
- Named and positional arguments can be freely mixed: `push(remote: origin, v)` where `v` is a positional expression
- Reserved words: `let`, `loop`, `in` cannot be used as identifiers
```

- [ ] **Step 4: Add Statements section**

Insert after the Abstraction section:

```markdown
### Statements

A program can contain multiple independent pipelines separated by `;`:

\```
planning :: Doc -> Commit
  >>> commit(branch: main);

implementation :: Code -> Commit
  >>> branch(pattern: "feature/*") :: Code -> Branch
  >>> commit :: Branch -> Commit
\```

- Trailing semicolon is optional
- Semicolons are not allowed inside parentheses
```

- [ ] **Step 5: Add Unit section**

Insert after the Statements section:

```markdown
### Unit

`()` is a value representing "no input" or "trigger":

\```
() >>> start_server :: () -> Server
\```

- `()` is also valid as a type name in annotations: `:: () -> Server`, `:: Input -> ()`
- `f()` passes Unit as a positional argument — it is not an empty argument list
```

- [ ] **Step 6: Update Type Annotations section**

In the existing Type Annotations section (around line 57), add a note that `()` is a valid type name:

Add after the existing annotation example:

```
Type names can be identifiers or `()` (unit): `:: () -> Server`, `:: Input -> ()`.
```

- [ ] **Step 7: Add literate mode to Workflow section**

In the "Validate Structure" subsection (around line 87), add after the existing `ocaml-compose-dsl pipeline.arr` example:

```markdown
For Markdown files with embedded arrow blocks (fenced with `arrow` or `arr`):

\```bash
ocaml-compose-dsl --literate README.md
\```

Any Markdown file can be a literate Arrow document. Use `arrow` or `arr` as the code fence language tag.
```

- [ ] **Step 8: Add let/lambda pattern to Common Patterns**

Add a new pattern subsection after existing patterns (around line 170):

```markdown
### Reusable Review Loop

\```
let review = \trigger, fix ->
  loop(trigger >>> (pass ||| fix))
in
let phase1 = gather >>> review(check?, rework) in
let phase2 = build >>> review(test?, fix) in
phase1 >>> phase2
\```
```

- [ ] **Step 9: Update Examples list in Additional Resources**

Add entries for the four new `.arr` files in the examples list (around line 206):

```markdown
- **`examples/lambda.arr`** — Lambda expressions: parameterized workflow fragments, multi-param, positional arguments
- **`examples/let-binding.arr`** — Let bindings: named fragments, nested lets, let inside parentheses, multi-phase composition
- **`examples/unit-type.arr`** — Unit value and type: `()` standalone, in type annotations, `f()` semantics
- **`examples/multi-statement.arr`** — Semicolon statement separator: independent pipelines, trailing semicolon
```

- [ ] **Step 10: Validate SKILL.md with literate mode**

```bash
ocaml-compose-dsl --literate plugins/compose/skills/compose/SKILL.md
```

Expected: exit 0. If any arrow blocks fail, fix and re-validate. Note: only blocks fenced with `arrow` or `arr` are checked — standard ``` blocks are ignored.

- [ ] **Step 11: Commit**

```bash
git add plugins/compose/skills/compose/SKILL.md
git commit -m "docs(compose): update SKILL.md for v0.10.0 — abstraction, statements, unit, literate mode"
```

---

### Task 3: Create new example files

**Files:**
- Create: `plugins/compose/skills/compose/examples/lambda.arr`
- Create: `plugins/compose/skills/compose/examples/let-binding.arr`
- Create: `plugins/compose/skills/compose/examples/unit-type.arr`
- Create: `plugins/compose/skills/compose/examples/multi-statement.arr`

- [ ] **Step 1: Create lambda.arr**

```
-- Lambda expressions: parameterized workflow fragments

-- Basic lambda — single parameter
\name -> hello(to: name) >>> respond

-- Multi-param lambda — reusable review pattern
; \trigger, fix -> loop(trigger >>> (pass ||| fix))

-- Lambda as positional argument passed to a node
; let v = some_pipeline in
  push(remote: origin, v)

-- Lambda with type annotations
; \url -> fetch(url: url) :: URL -> HTML
  >>> parse :: HTML -> Data
```

- [ ] **Step 2: Validate lambda.arr**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/lambda.arr
```

Expected: exit 0 with AST output. If it fails, fix syntax and retry.

- [ ] **Step 3: Create let-binding.arr**

```
-- Let bindings: name and reuse workflow fragments

-- Basic let binding
let greet = \name -> hello(to: name) >>> respond in
greet(alice) >>> greet(bob)

-- Nested lets — multi-phase workflow
; let review = \trigger, fix ->
    loop(trigger >>> (pass ||| fix))
  in
  let phase1 = gather >>> review(check?, rework) in
  let phase2 = build >>> review(test?, fix) in
  phase1 >>> phase2

-- Let inside parentheses
; (let x = fetch(url: primary) in x)
  ||| fetch(url: mirror)

-- Let binding a value passed as positional arg
; let v = read(source: "config.yaml") >>> validate in
  deploy(env: staging, v)
```

- [ ] **Step 4: Validate let-binding.arr**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/let-binding.arr
```

Expected: exit 0.

- [ ] **Step 5: Create unit-type.arr**

```
-- Unit value and type

-- Unit as a trigger — no meaningful input
() >>> start_server :: () -> Server

-- Unit in type annotations — both input and output positions
; healthcheck :: () -> Status

-- f() passes Unit as positional argument (not empty args)
; noop() >>> continue

-- Unit with question operator
; ()? >>> (ready ||| wait)
```

- [ ] **Step 6: Validate unit-type.arr**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/unit-type.arr
```

Expected: exit 0.

- [ ] **Step 7: Create multi-statement.arr**

```
-- Semicolon statement separator: independent pipelines in one file

-- Planning and implementation as separate concerns
planning :: Doc -> Commit
  >>> commit(branch: main);

implementation :: Code -> Commit
  >>> branch(pattern: "feature/*") :: Code -> Branch
  >>> commit :: Branch -> Commit;

-- Trailing semicolon is optional on the last statement
deploy(env: staging) >>> verify >>> promote(env: production)
```

- [ ] **Step 8: Validate multi-statement.arr**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/multi-statement.arr
```

Expected: exit 0.

- [ ] **Step 9: Commit all new examples**

```bash
git add plugins/compose/skills/compose/examples/lambda.arr \
        plugins/compose/skills/compose/examples/let-binding.arr \
        plugins/compose/skills/compose/examples/unit-type.arr \
        plugins/compose/skills/compose/examples/multi-statement.arr
git commit -m "feat(compose): add example files for lambda, let-binding, unit-type, multi-statement"
```

---

### Task 4: Update existing examples — frontend-project.arr

The review-loop pattern `loop(提案? >>> (通過 ||| 修正))` repeats 6 times. Extract with let/lambda.

**Files:**
- Modify: `plugins/compose/skills/compose/examples/frontend-project.arr`

- [ ] **Step 1: Add let binding at the top of the file**

After the header comments (line 2), insert:

```
let 審核 = \提案, 修正 ->
  loop(提案? >>> (通過 ||| 修正))
in
```

- [ ] **Step 2: Replace review-loop instances where the pattern fits**

The `審核` lambda fits loops shaped `loop(提案? >>> (通過 ||| 修正))`. Not all 6 review loops in the file match — some have multi-step chains before `?`, non-trivial pass sides, or different structures.

The 6 candidate instances:
1. Lines 41-45 (內部審查)
2. Lines 46-49 (客戶簽核 DocuSign)
3. Lines 59-63 (客戶風格確認)
4. Lines 119-123 (客戶最終簽核)
5. Lines 183-188 (PR Code Review) — uses `"approved"?` and `GitHub(任務: merge)` on pass side
6. Lines 226-230 (客戶驗收) — has multi-step fix pipeline

For each, check:
- Does the pass side just say `通過`? If it does something else (e.g., `GitHub(任務: merge)`), the `審核` pattern does not fit — leave the original `loop`.
- Is there a multi-step chain before `?` that doesn't decompose into a single expression? If so, leave it.
- Only replace instances where the pattern matches cleanly. Expect roughly 3-4 of 6 to fit.

- [ ] **Step 3: Validate**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/frontend-project.arr
```

Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add plugins/compose/skills/compose/examples/frontend-project.arr
git commit -m "refactor(compose): extract review-loop pattern with let/lambda in frontend-project.arr"
```

---

### Task 5: Update existing examples — ci-pipeline.arr and test-fix-loop.arr

**Files:**
- Modify: `plugins/compose/skills/compose/examples/ci-pipeline.arr`
- Modify: `plugins/compose/skills/compose/examples/test-fix-loop.arr`

- [ ] **Step 1: Update ci-pipeline.arr — name the CI pipeline with let**

Replace the entire file content with:

```
-- Workflow: lint + test, gate, build for multiple platforms, upload
let ci =
  (lint &&& test)
  >>> gate(require: [pass, pass])
in
ci
  >>> (build_linux(profile: static) *** build_macos(profile: release))
  >>> upload(tag: "v0.1.0")       -- ref: Bash("gh release create")
```

- [ ] **Step 2: Validate ci-pipeline.arr**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/ci-pipeline.arr
```

Expected: exit 0.

- [ ] **Step 3: Update test-fix-loop.arr — parameterize with lambda**

Replace the entire file content with:

```
-- Workflow: iteratively fix code until tests pass
-- Parameterized with lambda so the loop can be reused for different targets/suites

let test_fix = \target, suite ->
  loop(
    edit(target: target, change: fix)     -- ref: Edit
      >>> test(suite: suite)              -- ref: Bash("npm test")
      >>> "all tests pass"?
      >>> (done ||| retry)               -- exit loop on pass, retry on fail
  )
in
test_fix(code, relevant)
```

- [ ] **Step 4: Validate test-fix-loop.arr**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/test-fix-loop.arr
```

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/compose/skills/compose/examples/ci-pipeline.arr \
        plugins/compose/skills/compose/examples/test-fix-loop.arr
git commit -m "refactor(compose): introduce let/lambda in ci-pipeline and test-fix-loop examples"
```

---

### Task 6: Rewrite update-skill-from-upstream.arr

Rewrite to reflect the actual workflow used in this update session and demonstrate let/lambda and semicolons.

**Files:**
- Modify: `plugins/compose/skills/compose/examples/update-skill-from-upstream.arr`

- [ ] **Step 1: Rewrite the file**

Replace the entire file. The new version should:

1. Define a `fetch_upstream` lambda abstracting the repeated fetch+extract pattern
2. Use `let` to name each phase
3. Add `fetch_prs` in Phase 1 (reflecting actual use of `gh pr view`)
4. Add `update(target: "CLAUDE.md")` in Phase 3
5. Split Phase 4 into "update old examples with new syntax" and "add new examples" more clearly
6. Add `--literate` validation in Phase 5
7. Update minimum version to `v0.10.0` in Phase 7
8. Use `;` to separate phases as independent statements where appropriate

Structure:

```
-- Workflow: check upstream binary repo and align compose skill to match
-- Triggers: new release of ocaml-compose-dsl, grammar changes, new features
-- Covers: docs, examples, metadata (marketplace.json), review cycle
-- Demonstrates: let/lambda abstraction, semicolons, unit

let fetch_upstream = \repo, fields ->
  fetch(repo: repo)                      -- ref: Bash("gh api repos/.../releases/latest")
  >>> extract(fields: fields)
in

let gather =
  (fetch_upstream("caasi/ocaml-compose-dsl", [tag_name, body, assets])
    &&&
    fetch_upstream("caasi/ocaml-compose-dsl", [grammar, examples, usage])
    &&&
    fetch_prs(repo: "caasi/ocaml-compose-dsl")  -- ref: Bash("gh pr view N --json body")
    &&&
    read(source: "skills/compose/SKILL.md")
    &&&
    read(source: "skills/compose/references/dsl-grammar.md")
    &&&
    read(source: "skills/compose/README.md"))
in

let analyze =
  diff(upstream: release_info, local: skill_files)
  >>> plan(changes: required_updates)
in

let update_docs =
  update(target: "references/dsl-grammar.md", source: upstream_ebnf)
  *** update(target: "SKILL.md", sections: [version, combinators, abstraction, statements, unit, workflow, patterns])
  *** update(target: "README.md", sections: [features, combinators, examples])
  *** update(target: "CLAUDE.md", sections: [compose_description, version])
in

let update_examples =
  (update_examples(dir: "examples/", action: introduce_let_lambda)
    *** add_examples(dir: "examples/", for: [lambda, let_binding, unit_type, multi_statement]))
  >>> update(target: "SKILL.md", section: examples_list)
in

let validate =
  collect_arr_files(from: "skills/compose/examples/")
  >>> validate_all(checker: "ocaml-compose-dsl")
  >>> validate_literate(files: ["SKILL.md", "references/dsl-grammar.md", "README.md"])
in

let bump_version =
  update(target: ".claude-plugin/marketplace.json", fields: [version, description])
in

let verify =
  check_version(binary: "ocaml-compose-dsl", minimum: "0.10.0")
in

gather >>> analyze >>> update_docs >>> update_examples >>> validate >>> bump_version >>> verify
```

- [ ] **Step 2: Validate**

```bash
ocaml-compose-dsl plugins/compose/skills/compose/examples/update-skill-from-upstream.arr
```

Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add plugins/compose/skills/compose/examples/update-skill-from-upstream.arr
git commit -m "refactor(compose): rewrite update-skill-from-upstream.arr with let/lambda"
```

---

### Task 7: Update README.md

**Files:**
- Modify: `plugins/compose/skills/compose/README.md`

- [ ] **Step 1: Update "What it does" section**

Add to the bullet list (after line 4):

```markdown
- Supports abstraction with lambda (`\x -> expr`) and let bindings (`let x = expr in body`) for naming and reusing workflow fragments
- Validates arrow blocks embedded in Markdown files via literate mode (`--literate`)
- Supports multiple independent pipelines in one file via semicolon `;` separator
```

- [ ] **Step 2: Update Arrow Combinators table**

Add rows to the existing table (after line 21):

| `\x -> expr` | Lambda — parameterized fragment | — |
| `let x = expr in body` | Let binding — named fragment | — |
| `()` | Unit — no-input value | — |
| `;` | Statement separator | — |

Rename existing `()` Grouping row to `(expr)`.

- [ ] **Step 3: Add lambda/let example**

Add after the existing examples (around line 42):

```markdown
\```
let review = \trigger, fix ->
  loop(trigger >>> (pass ||| fix))
in
let phase1 = gather >>> review(check?, rework) in
let phase2 = build >>> review(test?, fix) in
phase1 >>> phase2
\```
```

- [ ] **Step 4: Update "More examples" text**

Update the examples directory description to mention the new example count (21 examples: 17 existing + 4 new).

- [ ] **Step 5: Commit**

```bash
git add plugins/compose/skills/compose/README.md
git commit -m "docs(compose): update README.md for v0.10.0 features"
```

---

### Task 8: Update CLAUDE.md and marketplace.json

**Files:**
- Modify: `CLAUDE.md` (repo root)
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Update CLAUDE.md compose description**

Replace line 36. Change:

```
**compose (v0.6.1):** Uses an OCaml binary (`ocaml-compose-dsl`) for DSL validation. Install via `scripts/install.sh` (downloads to `~/.local/bin/`). Validate `.arr` files with `ocaml-compose-dsl pipeline.arr`. Arrow combinators: `>>>` (sequential), `|||` (branch), `***` (parallel), `&&&` (fanout), `?` (question/branch), `loop()` (feedback). Grammar spec in `references/dsl-grammar.md`, 16 examples in `examples/`.
```

to:

```
**compose (v0.10.0):** Uses an OCaml binary (`ocaml-compose-dsl`) for DSL validation. Install via `scripts/install.sh` (downloads to `~/.local/bin/`). Validate `.arr` files with `ocaml-compose-dsl pipeline.arr` or Markdown files with `ocaml-compose-dsl --literate doc.md`. Arrow combinators: `>>>` (sequential), `|||` (branch), `***` (parallel), `&&&` (fanout), `?` (question/branch), `loop()` (feedback). Abstraction: `\x -> expr` (lambda), `let x = expr in body` (let binding). Other syntax: `()` (unit), `;` (statement separator). Grammar spec in `references/dsl-grammar.md`, 21 examples in `examples/`.
```

- [ ] **Step 2: Update marketplace.json**

Change the compose version on line 20:

```json
"version": "0.7.0"
```

to:

```json
"version": "0.10.0"
```

Also update the compose description on line 19 to include new combinators:

```json
"description": "Describe multi-step agent workflows using an Arrow-style DSL (>>>, ***, &&&, |||, ?, loop, \\, let...in, (), ;) and validate them structurally"
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md .claude-plugin/marketplace.json
git commit -m "chore(compose): bump version to v0.10.0 in CLAUDE.md and marketplace.json"
```

---

### Task 9: Final validation

Run all `.arr` examples through the checker and literate-validate all Markdown files with arrow blocks.

**Files:**
- None modified — validation only

- [ ] **Step 1: Validate all .arr example files**

```bash
for f in plugins/compose/skills/compose/examples/*.arr; do
  echo "--- $f ---"
  ocaml-compose-dsl "$f" > /dev/null && echo "OK" || echo "FAIL: $f"
done
```

Expected: all files print `OK`.

- [ ] **Step 2: Validate Markdown files with literate mode**

```bash
ocaml-compose-dsl --literate plugins/compose/skills/compose/SKILL.md && echo "SKILL.md OK"
ocaml-compose-dsl --literate plugins/compose/skills/compose/references/dsl-grammar.md && echo "dsl-grammar.md OK"
ocaml-compose-dsl --literate plugins/compose/skills/compose/README.md && echo "README.md OK"
```

Expected: all three print `OK`. Note: only code blocks fenced with `arrow` or `arr` are checked. Standard triple-backtick blocks without a language tag or with other language tags (e.g., `bash`, `ebnf`) are ignored.

- [ ] **Step 3: Fix any failures and re-validate**

If any file fails, fix the syntax error and re-run the validation. Commit fixes with:

```bash
git add <fixed-files>
git commit -m "fix(compose): fix validation errors in <file>"
```

- [ ] **Step 4: Verify final file count**

```bash
ls plugins/compose/skills/compose/examples/*.arr | wc -l
```

Expected: 21 files (17 existing + 4 new).
