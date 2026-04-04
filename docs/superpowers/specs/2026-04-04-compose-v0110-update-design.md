# Compose Skill v0.11.0 Update — Design Spec

## Context

The upstream `ocaml-compose-dsl` binary has reached v0.11.0. The compose skill in dong3 is at v0.10.0. This update aligns the skill with the new upstream release, which introduces epistemic operator lint rules.

### Upstream Changelog (v0.10.0 → v0.11.0)

**v0.11.0 (2026-04-04, PR #33):**
- Epistemic operator lint rules: `branch` without `merge` warns, `leaf` without `check` suggests verification
- `collect_ident_names` helper for flat identifier scanning across post-reduce AST (descends into `Group` nodes)
- Epistemic Conventions section in README documenting five operator names
- README example renamed `branch(pattern: "feature/*")` → `git_branch(pattern: "feature/*")` to avoid false positive

### Epistemic Operators (from upstream README)

Five identifier names serve as cognitive role markers for human-LLM shared reasoning scaffolds, inspired by [λ-RLM](https://github.com/lambda-calculus-LLM/lambda-RLM):

| Name | Intent | Common Pattern |
|------|--------|----------------|
| `gather` | Collect evidence/sub-questions before reasoning | `gather >>> leaf` |
| `branch` | Explore multiple candidate paths | `branch >>> ... >>> merge` |
| `merge` | Converge candidates into auditable artifact | `... >>> merge >>> check?` |
| `leaf` | High-cost reasoning zone — bounded sub-problem | `leaf >>> check?` |
| `check` | Verifiable validation step | `check? >>> (pass \|\|\| fix)` |

These are naming conventions, not keywords. They can be shadowed by `let` bindings or used as regular nodes. The checker matches by name only.

## Approach

**Docs-first, examples follow.** Update documentation (SKILL.md, README.md, dsl-grammar.md) first to establish the convention reference, then review all 21 existing examples with v0.11.0 checker, then add the new example. Each step validates with the binary.

## Design

### 1. Version & Metadata

| File | Field | Old | New |
|------|-------|-----|-----|
| `marketplace.json` | compose version | `0.10.0` | `0.11.0` |
| `plugin.json` | description (text only, no version field exists) | current | add epistemic operators mention |
| `SKILL.md` | Version Check text | `v0.10.0` | `v0.11.0` |

`install.sh` already fetches latest release — no change.

### 2. SKILL.md Changes

#### Prerequisites

Minimum version: `v0.10.0` → `v0.11.0`.

#### New Section: Epistemic Conventions

Position: after Checker Warnings section.

Content:
- Five operator names table (name, intent, common pattern)
- Explanation: naming convention, not keywords; can be shadowed by `let`
- λ-RLM inspiration reference
- Note on `git_branch` renaming convention to avoid false positive

#### Checker Warnings — New Entries

Add to existing warnings list:
- `branch` without `merge` in the same statement → warning
- `leaf` without `check` in the same statement → suggestion

#### Example List

Add entry for `epistemic-debugging.arr`.

### 3. README.md Changes

- Add Epistemic Conventions subsection (compact version, point to SKILL.md for detail)
- Update version references

### 4. dsl-grammar.md Changes

#### Structural Rules

Add epistemic lint description to what the checker validates.

#### Warnings

Add `branch`/`merge` and `leaf`/`check` warning documentation.

Mention `git_branch` renaming convention (avoid false positive when a node named `branch` is used for non-epistemic purposes like git branching).

### 5. Existing Examples Audit

Run all 21 `.arr` files through v0.11.0 checker. For each file, categorize:

**Rename `branch` to avoid false positive:**
- Any example using `branch` as a non-epistemic node (e.g., git branch semantics) → rename to `git_branch` or similar
- This audit also covers embedded arrow blocks in SKILL.md, README.md, and dsl-grammar.md — not just standalone `.arr` files

**Known `branch` rename targets:**
- `multi-statement.arr` line 8: `branch(pattern: "feature/*")` → `git_branch(pattern: "feature/*")`
- SKILL.md Statements section (inline example): same rename
- dsl-grammar.md Multi-Statement example: same rename

**Introduce epistemic naming where semantically appropriate (only where natural):**

| Example | Candidate Changes | Rationale |
|---------|-------------------|-----------|
| `ci-pipeline.arr` | Check for `branch` naming conflict | CI context may use git branch semantics |
| `test-fix-loop.arr` | `verify` → `check`? | Has verification semantics |
| `frontend-project.arr` | Review loop may have `check` semantics | 225-line file, review carefully |
| `osint-*.arr` (6 files) | `gather` + `check` candidates | Evidence gathering + verification is natural fit |

**Leave unchanged (syntax demos, no epistemic semantics):**
- `data-pipeline.arr`, `resilient-fetch.arr`, `question-operator.arr`, `lambda.arr`, `let-binding.arr`, `unit-type.arr`, `type-annotations.arr`, `numeric-literals.arr`, `mixed-par-fanout.arr`, `unicode-identifiers.arr`

Actual changes determined by running the checker and reviewing each file's semantics during implementation. The table above is initial guidance, not prescriptive.

### 6. New Example: `epistemic-debugging.arr`

**Theme:** Systematic debugging workflow — symptoms to verified fix.

**Structure:**

```arrow
-- Systematic debugging workflow using epistemic operators
-- gather → branch → merge → leaf → check

gather(from: [logs, metrics, traces])
  >>> branch  -- explore multiple hypotheses
  >>> ...parallel investigation with &&&...
  >>> merge   -- converge into ranked diagnosis
  >>> leaf(target: root_cause)  -- bounded deep-dive
  >>> check?
  >>> (pass ||| fix_and_retry)
```

**Features demonstrated:**
- All five epistemic operators (`gather`, `branch`, `merge`, `leaf`, `check`)
- `loop()` wrapping the fix-retry cycle
- `&&&` fanout for parallel evidence collection
- `?` + `|||` for verification branching
- `let` binding for reusable verification fragment
- Type annotations and comments
- ~30-50 lines

### 7. update-skill-from-upstream.arr

Review and update to reflect v0.11.0 workflow (this session). Add epistemic operators if the "check upstream → update docs → verify" flow maps naturally.

### 8. Repo Root CLAUDE.md

Update compose description to mention epistemic operators and v0.11.0.

## Execution Pipeline

```arrow
-- v0.11.0 update workflow

let verify_all = \target ->
  ocaml-compose-dsl(target)
    >>> check?
    >>> (pass ||| fix_and_retry)
in

-- Phase 1: Documentation
(update_skill_md &&& update_readme &&& update_dsl_grammar)
  >>> verify_all("plugins/compose/")

-- Phase 2: Existing examples audit
;
audit_examples(count: 21)
  >>> (rename_branch_conflicts *** introduce_epistemic_naming)
  >>> verify_all("plugins/compose/skills/compose/examples/")

-- Phase 3: New example + meta-example update
;
(write_epistemic_debugging &&& update_skill_from_upstream)
  >>> verify_all("plugins/compose/skills/compose/examples/")

-- Phase 4: Metadata & root docs
;
(bump_versions &&& update_root_claude_md)
  >>> verify_all("--literate CLAUDE.md")
```

## Out of Scope

- Changes to `install.sh` (fetches latest automatically)
- New OSINT examples
- Type checker implementation (upstream has none)
- Changes to other plugins (chat-subagent, kami, fetch-tips)
