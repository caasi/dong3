# Constraint Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the `constraint` plugin for the dong3 marketplace with three skills (`constraint-write`, `constraint-generate`, `constraint-enforce`) that turn natural language constraints into deterministic test artifacts.

**Architecture:** One plugin with three independent skills following the Guided Flow pattern. Each skill has its own SKILL.md, README.md, and references/ directory. No runtime dependencies — skills are pure system prompts that guide agent behavior. Reference files provide format specs, toolchain matrices, and enforcement guides.

**Tech Stack:** Markdown (SKILL.md system prompts, reference files), JSON (plugin.json, marketplace.json)

**Spec:** `docs/superpowers/specs/2026-04-12-constraint-plugin-design.md`

---

## File Structure

```
plugins/constraint/
  .claude-plugin/plugin.json                          # Plugin metadata
  skills/
    constraint-write/
      SKILL.md                                        # System prompt for constraint authoring
      README.md                                       # User-facing docs
      references/
        constraint-format.md                          # Format spec + examples
        property-patterns.md                          # PBT property pattern catalog
    constraint-generate/
      SKILL.md                                        # System prompt for artifact generation
      README.md                                       # User-facing docs
      references/
        constraint-format.md                          # Format spec (shared content with write)
        toolchain-matrix.md                           # 4-layer toolchain × language matrix
    constraint-enforce/
      SKILL.md                                        # System prompt for enforcement pipeline
      README.md                                       # User-facing docs
      references/
        enforcement-layers.md                         # Layer execution order + tool commands
        mutation-feedback-guide.md                    # Mutant interpretation + loop termination
```

Also modified:
- `.claude-plugin/marketplace.json` — add constraint plugin entry

---

### Task 1: Plugin scaffold + plugin.json + marketplace registration

**Files:**
- Create: `plugins/constraint/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 0: Create feature branch**

```bash
git checkout -b feat/constraint-plugin
```

- [ ] **Step 1: Create plugin.json**

```json
{
  "name": "constraint",
  "description": "Natural language constraints → deterministic test artifacts",
  "author": {
    "name": "caasi"
  },
  "homepage": "https://github.com/caasi/dong3",
  "repository": "https://github.com/caasi/dong3",
  "license": "MIT",
  "keywords": ["constraint", "testing", "pbt", "mutation-testing", "verification"],
  "skills": "./skills/"
}
```

- [ ] **Step 2: Add to marketplace.json**

Add this entry to the `plugins` array in `.claude-plugin/marketplace.json`:

```json
{
  "name": "constraint",
  "source": "./plugins/constraint",
  "description": "Natural language constraints → deterministic test artifacts. Write constraints in structured Markdown, generate unit tests / PBT / mutation tests, enforce with deterministic tools.",
  "version": "0.1.0"
}
```

- [ ] **Step 3: Commit**

```bash
git add plugins/constraint/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(constraint): scaffold plugin and register in marketplace"
```

---

### Task 2: constraint-format.md — the shared format reference

This is the canonical format specification used by both `constraint-write` and `constraint-generate`. Write it once, then copy to both skills' references/ directories.

**Files:**
- Create: `plugins/constraint/skills/constraint-write/references/constraint-format.md`
- Create: `plugins/constraint/skills/constraint-generate/references/constraint-format.md` (same content)

- [ ] **Step 1: Write constraint-format.md**

Content should cover:

1. **File location convention:** `constraints/<RULE_ID>-<slug>.md`
2. **RULE_ID naming:** `<DOMAIN>_<NNN>` format, zero-padded sequential number
3. **Frontmatter fields table:** `rule` (required), `kind` (required), `scope` (required), `subject` (optional), `enforce` (optional)
4. **Kind classification table:** permission, prohibition, obligation, invariant, protocol — with semantic meaning and typical enforce mapping
5. **Kind as default enforce:** when `enforce` is omitted, use the Kind table's typical enforce column
6. **Body sections:** Given, When, Then, Unless, Examples, Properties — each with purpose and test mapping
7. **Unless syntax:** condition lines (no arrow) + outcome lines (`→` prefix), multiple groups separated by blank lines, logical OR
8. **Examples section:** must be a Markdown table with at least 3 rows. No concrete examples = no enforcement. The table maps directly to parameterized unit tests (`it.each` / `test.each`)
9. **Properties section:** `forall X where condition: property` semi-formal syntax, maps to `fc.property()`
10. **Two complete examples:** domain/state constraint (USER_003) and code-level constraint (MONEY_001), taken from the spec

Source: spec sections "Constraint Format" through "Example: Code-Level Constraint" (lines 41–183)

- [ ] **Step 2: Copy to constraint-generate/references/**

The content is identical. Both skills need to parse the format — `constraint-write` to produce it, `constraint-generate` to consume it.

- [ ] **Step 3: Commit**

```bash
git add plugins/constraint/skills/constraint-write/references/constraint-format.md \
       plugins/constraint/skills/constraint-generate/references/constraint-format.md
git commit -m "docs(constraint): add constraint format reference"
```

---

### Task 3: property-patterns.md — PBT pattern catalog

**Files:**
- Create: `plugins/constraint/skills/constraint-write/references/property-patterns.md`

- [ ] **Step 1: Write property-patterns.md**

A catalog of common property-based testing patterns. For each pattern, provide:
- Pattern name
- One-sentence description
- Semi-formal template (`forall ...`)
- Concrete TypeScript fast-check example

Patterns to cover (from the spec's source document):

| Pattern | Template | Example domain |
|---|---|---|
| **Roundtrip** | `forall x: parse(serialize(x)) === x` | JSON, API request/response |
| **Idempotent** | `forall x: f(f(x)) === f(x)` | Formatting, normalization |
| **Invariant** | `forall xs: sort(xs).length === xs.length` | Collection operations |
| **Commutative** | `forall a, b: merge(a, b) === merge(b, a)` | Set operations, config merge |
| **Model-based** | `forall input: impl(input) === reference(input)` | Refactored code vs original |
| **State machine** | `forall transitions: apply(transitions, initial).state ∈ validStates` | Entity lifecycle |

For each, include a concrete fast-check code snippet like:

```typescript
fc.assert(fc.property(fc.json(), (input) => {
  const parsed = JSON.parse(input);
  expect(parse(serialize(parsed))).toEqual(parsed);
}));
```

Also include a "Common pitfalls" section warning about trivially true properties (`x === x`) and how mutation testing catches them.

- [ ] **Step 2: Commit**

```bash
git add plugins/constraint/skills/constraint-write/references/property-patterns.md
git commit -m "docs(constraint): add PBT property patterns catalog"
```

---

### Task 4: constraint-write SKILL.md + README.md

**Files:**
- Create: `plugins/constraint/skills/constraint-write/SKILL.md`
- Create: `plugins/constraint/skills/constraint-write/README.md`

- [ ] **Step 1: Write SKILL.md**

Follow the owasp SKILL.md conventions: YAML frontmatter (name + description with trigger conditions), compact body (~40-50 lines), workflow steps, references pointers.

Exact frontmatter:

```yaml
---
name: constraint-write
description: >-
  Use when the user asks to "/constraint-write", "write constraint",
  "define constraint", "幫我寫 constraint", "定義 constraint", or when
  the agent detects prohibition ("不能", "禁止", "must not"), obligation
  ("必須", "一定要", "always"), or invariant ("roundtrip", "idempotent")
  language in conversation and wants to suggest writing a constraint.
---
```

Body sections:
1. **Role statement:** You are helping the user articulate and document constraints in structured natural language. Constraints are the user's laws; deterministic tools are the judges.
2. **Workflow:**
   - If the user describes a rule → use dialogue to clarify Given/When/Then/Unless/Examples/Properties one section at a time
   - Read `references/constraint-format.md` for the canonical format
   - Scan existing `constraints/*.md` to determine the next available RULE_ID number for the domain
   - Each constraint must have at least 3 rows in the Examples table — no examples = no enforcement
   - Write the constraint to `constraints/<RULE_ID>-<slug>.md`
   - Create `constraints/` directory if it doesn't exist
   - After writing, suggest: "Constraint 已寫好。要我用 `/constraint-generate` 產生 test artifact 嗎？"
3. **Proactive suggestion:** When the user says prohibition ("不能", "禁止", "must not"), obligation ("必須", "一定要", "always"), or invariant ("roundtrip", "idempotent") language → propose writing a constraint
4. **Property patterns:** Consult `references/property-patterns.md` when helping the user write the Properties section

- [ ] **Step 2: Write README.md**

Follow owasp README.md conventions: overview, usage triggers, format summary, link to spec.

```markdown
# Constraint Write

Conversational constraint authoring — turn natural language rules into structured `constraints/*.md` files.

## Usage

Invoke with `/constraint-write` or ask to "write a constraint", "定義 constraint".

The agent also proactively suggests writing constraints when it detects
prohibition, obligation, or invariant language in conversation.

## Constraint Format

Each constraint file uses Given/When/Then/Unless/Examples/Properties sections
in a legal/BDD hybrid structure. See `references/constraint-format.md` for the
full specification and examples.

## Guided Flow

After writing a constraint, the skill suggests running `/constraint-generate`
to produce deterministic test artifacts.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/constraint/skills/constraint-write/SKILL.md \
       plugins/constraint/skills/constraint-write/README.md
git commit -m "feat(constraint): add constraint-write skill"
```

---

### Task 5: toolchain-matrix.md — deterministic toolchain reference

**Files:**
- Create: `plugins/constraint/skills/constraint-generate/references/toolchain-matrix.md`

- [ ] **Step 1: Write toolchain-matrix.md**

Content:

1. **TypeScript toolchain (supported)** — one section per layer:
   - **Layer 1: Lint** — Biome (static analysis + formatting, Biotype for TS type inference), ast-grep (structural code search for prohibition enforcement)
   - **Layer 2: Validation** — Typia (preferred, zero schema duplication), ArkType (set-theory based), Zod (if already in stack). Decision logic: check existing dependencies first, default to Typia for new projects
   - **Layer 3: PBT** — fast-check. Include detection: check if `fast-check` is in package.json devDependencies
   - **Layer 4: Mutation** — Stryker Mutator. Include detection: check for `@stryker-mutator/core` in devDependencies

   For each tool, include:
   - Install command (npm)
   - Init command (if applicable)
   - Run command
   - How to interpret output for pass/fail

2. **Other languages (planned)** — table only, no details:

   | Layer | OCaml | Rust | Python |
   |---|---|---|---|
   | Lint | ocamlformat | clippy | ruff |
   | Validation | Gospel | — | pydantic |
   | PBT | QCheck / Ortac | proptest | Hypothesis |
   | Mutation | — | cargo-mutants | mutmut |

3. **Language detection** — how to identify repo language:
   - `package.json` or `tsconfig.json` → TypeScript
   - `dune-project` → OCaml
   - `Cargo.toml` → Rust
   - `pyproject.toml` or `setup.py` → Python
   - Multiple detected → ask user which to target

4. **Mapping from constraint kind/enforce to toolchain layer:**
   - `lint` / `ast-grep` → Layer 1
   - `validation` → Layer 2
   - `pbt` → Layer 3
   - `mutation` → Layer 4

- [ ] **Step 2: Commit**

```bash
git add plugins/constraint/skills/constraint-generate/references/toolchain-matrix.md
git commit -m "docs(constraint): add toolchain matrix reference"
```

---

### Task 6: constraint-generate SKILL.md + README.md

**Files:**
- Create: `plugins/constraint/skills/constraint-generate/SKILL.md`
- Create: `plugins/constraint/skills/constraint-generate/README.md`

- [ ] **Step 1: Write SKILL.md**

Exact frontmatter:

```yaml
---
name: constraint-generate
description: >-
  Use when the user asks to "/constraint-generate", "generate constraint
  tests", "generate constraint artifact", "產生 constraint 的 test", or
  "generate test from constraint". Reads constraints/*.md and produces
  deterministic test artifacts.
---
```

Body sections:
1. **Role statement:** You read constraint files from `constraints/*.md` and generate deterministic test artifacts that enforce them mechanically.
2. **Workflow:**
   - Scan `constraints/*.md` — read each file, parse frontmatter and body sections
   - Read `references/constraint-format.md` to understand the format
   - Detect repo language/toolchain (check for package.json, tsconfig.json, etc.)
   - Read `references/toolchain-matrix.md` to select tools
   - For each constraint, generate artifacts:
     - Examples table → `*.constraint.test.ts` with parameterized tests (`it.each`)
     - Properties → `*.constraint.pbt.test.ts` with fast-check property tests
     - Prohibition + ast-grep → `.ast-grep/rules/*.yml` ast-grep rule
     - Validation → runtime validation code at trust boundaries
   - File header: `// Generated from constraints/<RULE_ID>-<slug>.md — do not edit manually`
   - Place artifacts in repo's existing test directory structure
   - Re-running overwrites existing generated artifacts
   - After generating, suggest two things:
     1. "要我用 `/constraint-enforce` 跑驗證嗎？"
     2. If no constraint-related PreCommit hook detected in `.claude/settings.json`, suggest adding one
3. **Hook suggestion template:**
   ```json
   {
     "hooks": {
       "PreCommit": [{ "matcher": "", "command": "npm test -- --grep constraint" }]
     }
   }
   ```
   Suggest to the user — do not auto-modify settings.

- [ ] **Step 2: Write README.md**

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add plugins/constraint/skills/constraint-generate/SKILL.md \
       plugins/constraint/skills/constraint-generate/README.md
git commit -m "feat(constraint): add constraint-generate skill"
```

---

### Task 7: enforcement-layers.md + mutation-feedback-guide.md

**Files:**
- Create: `plugins/constraint/skills/constraint-enforce/references/enforcement-layers.md`
- Create: `plugins/constraint/skills/constraint-enforce/references/mutation-feedback-guide.md`

- [ ] **Step 1: Write enforcement-layers.md**

Layer-by-layer execution guide:

1. **Layer 1: Lint (Biome + ast-grep)**
   - Run: `npx @biomejs/biome check .` for Biome, `npx ast-grep scan` for ast-grep rules
   - Expected output: list of violations, exit code 0 = clean
   - On failure: report violations with file + line, suggest fixes

2. **Layer 2: Validation (Typia / ArkType / Zod)**
   - Run: compile-time check (Typia) or unit test execution
   - Expected output: compilation success or test pass
   - On failure: report type mismatches at trust boundaries

3. **Layer 3: PBT (fast-check)**
   - Run: `npm test -- --grep constraint.pbt`
   - Expected output: all property tests pass (100+ random inputs per property)
   - On failure: report counterexample found by fast-check with shrunk minimal input

4. **Layer 4: Mutation Testing (Stryker)**
   - Run: `npx stryker run`
   - Expected output: JSON report with mutation score
   - On failure: see mutation-feedback-guide.md for the feedback loop

Execution order: Layer 1 → 2 → 3 → 4. Fail fast: if Layer 1 fails, fix before proceeding. Layer 4 depends on Layer 3 tests existing.

- [ ] **Step 2: Write mutation-feedback-guide.md**

Content:

1. **What is mutation score:** killed mutants / total mutants. Default target: 80%.
2. **How to interpret surviving mutants:**
   - Equivalent mutant: the mutation doesn't change observable behavior (can't kill, ignore)
   - Weak test: the property doesn't assert on the mutated behavior → strengthen the property
   - Missing test: no property covers this code path → add a new property
3. **Feedback loop:**
   - Round 1: Run Stryker → collect surviving mutants → for each, analyze which property should catch it → strengthen or add property → re-run PBT to confirm new property passes
   - Round 2: Re-run Stryker → check if previously surviving mutants are now killed
   - Round 3: Final attempt if mutants remain
   - Max 3 rounds total
4. **Early termination:**
   - Same mutant survives after 2 rounds of strengthening → likely equivalent mutant, report to user
   - Mutation score plateaus (no improvement between rounds) → report remaining mutants to user
5. **Escalation:** After 3 rounds or on unresolvable mutants, produce a summary table:
   | Mutant | Location | Mutation | Survived rounds | Likely cause |
   And ask the user to judge whether each is an equivalent mutant or a real gap.

- [ ] **Step 3: Commit**

```bash
git add plugins/constraint/skills/constraint-enforce/references/enforcement-layers.md \
       plugins/constraint/skills/constraint-enforce/references/mutation-feedback-guide.md
git commit -m "docs(constraint): add enforcement layers and mutation feedback references"
```

---

### Task 8: constraint-enforce SKILL.md + README.md

**Files:**
- Create: `plugins/constraint/skills/constraint-enforce/SKILL.md`
- Create: `plugins/constraint/skills/constraint-enforce/README.md`

- [ ] **Step 1: Write SKILL.md**

Exact frontmatter:

```yaml
---
name: constraint-enforce
description: >-
  Use when the user asks to "/constraint-enforce", "enforce constraints",
  "run constraint tests", "跑 constraint 驗證", or "run constraint
  enforcement". Runs the 4-layer deterministic enforcement pipeline on
  generated constraint artifacts.
---
```

Body sections:
1. **Role statement:** You run the deterministic enforcement pipeline on generated constraint artifacts and report results.
2. **Workflow:**
   - Read `references/enforcement-layers.md` for the layer execution order
   - Run layers in order: Lint → Validation → PBT → Mutation Testing
   - Fail fast: fix issues at each layer before proceeding to the next
   - For Layer 3+4 feedback loop: read `references/mutation-feedback-guide.md`
   - Default mutation score target: 80%
   - Max 3 feedback rounds
   - Escalation: after 3 rounds or on unresolvable mutants, report to user with mutant summary table
   - Final report: per-layer pass/fail, mutation score, surviving mutant list (if any), recommendations

- [ ] **Step 2: Write README.md**

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add plugins/constraint/skills/constraint-enforce/SKILL.md \
       plugins/constraint/skills/constraint-enforce/README.md
git commit -m "feat(constraint): add constraint-enforce skill"
```

---

### Task 9: Update CLAUDE.md with constraint plugin info

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add constraint plugin to the plugin details section**

Add after the owasp entry in the "Plugin Details" section:

```markdown
**constraint (v0.1.0):** Three skills for NL metaprogramming — humans write constraints in structured natural language (`constraints/*.md` with Given/When/Then/Unless/Examples/Properties), agents generate deterministic test artifacts. `constraint-write` for authoring, `constraint-generate` for artifact generation (TypeScript: Biome, ast-grep, Typia, fast-check, Stryker), `constraint-enforce` for running the enforcement pipeline.
```

- [ ] **Step 2: Add constraint to Repository Structure**

Add `constraint/` line to the structure diagram in CLAUDE.md.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add constraint plugin to CLAUDE.md"
```

---

### Task 10: Final verification

- [ ] **Step 1: Verify all files exist**

Run: `find plugins/constraint -type f | sort`

Expected output:
```
plugins/constraint/.claude-plugin/plugin.json
plugins/constraint/skills/constraint-enforce/README.md
plugins/constraint/skills/constraint-enforce/SKILL.md
plugins/constraint/skills/constraint-enforce/references/enforcement-layers.md
plugins/constraint/skills/constraint-enforce/references/mutation-feedback-guide.md
plugins/constraint/skills/constraint-generate/README.md
plugins/constraint/skills/constraint-generate/SKILL.md
plugins/constraint/skills/constraint-generate/references/constraint-format.md
plugins/constraint/skills/constraint-generate/references/toolchain-matrix.md
plugins/constraint/skills/constraint-write/README.md
plugins/constraint/skills/constraint-write/SKILL.md
plugins/constraint/skills/constraint-write/references/constraint-format.md
plugins/constraint/skills/constraint-write/references/property-patterns.md
```

- [ ] **Step 2: Verify marketplace.json is valid JSON**

Run: `python3 -c "import json; json.load(open('.claude-plugin/marketplace.json')); print('valid')"`

- [ ] **Step 3: Verify SKILL.md frontmatter is valid YAML**

For each SKILL.md, verify the frontmatter parses correctly:

```bash
for f in plugins/constraint/skills/*/SKILL.md; do
  echo "--- $f ---"
  sed -n '/^---$/,/^---$/p' "$f" | python3 -c "import sys, yaml; yaml.safe_load(sys.stdin); print('valid')"
done
```

- [ ] **Step 4: Review git log for clean commit history**

Run: `git log --oneline | head -10`

Expected: a clean sequence of conventional commits scoped to `(constraint)`.
