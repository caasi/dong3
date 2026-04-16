# Constraint Format Reference

This document is the canonical format specification for constraint files. Both `constraint-write` (authoring) and `constraint-generate` (artifact generation) depend on this format.

## File Location Convention

All constraint files live in the repository root under:

```
constraints/<RULE_ID>-<slug>.md
```

- `<RULE_ID>`: unique identifier (see RULE_ID Naming below)
- `<slug>`: kebab-case human-readable summary

Example: `constraints/USER_003-soft-deleted-no-login.md`

## RULE_ID Naming

Format: `<DOMAIN>_<NNN>`

- **DOMAIN**: short uppercase label chosen by the user (e.g. `USER`, `MONEY`, `API`, `AUTH`, `ORDER`)
- **NNN**: zero-padded sequential number within that domain (e.g. `001`, `002`, `003`)

`constraint-write` should scan existing `constraints/*.md` files and suggest the next available number for the given domain.

## Frontmatter

Every constraint file begins with YAML frontmatter between `---` fences.

| Field | Required | Description |
|---|---|---|
| `rule` | yes | Unique identifier (e.g. `USER_003`). Used for cross-reference and artifact file naming. |
| `kind` | yes | Constraint classification: `permission`, `prohibition`, `obligation`, `invariant`, or `protocol`. See Kind Classification below. |
| `scope` | yes | Glob pattern(s) specifying which source files this constraint covers (e.g. `src/auth/**, src/user/**`). |
| `subject` | no | The domain entity involved (e.g. `User`, `Invoice`, `Transaction`). |
| `enforce` | no | Comma-separated enforcement methods: `lint`, `ast-grep`, `validation`, `pbt`, `mutation`. When omitted, `constraint-generate` uses the Kind table's typical enforce column as default. |

## Kind Classification

| Kind | Semantic Meaning | Typical Enforce |
|---|---|---|
| `permission` | Under certain conditions, an action is allowed | validation |
| `prohibition` | An action is forbidden | lint, ast-grep |
| `obligation` | An action is required | lint, validation |
| `invariant` | A mathematical property that must always hold | pbt |
| `protocol` | An ordering or sequencing constraint on operations | pbt (state machine) |

### Kind as Default Enforce

When the `enforce` field is omitted from frontmatter, `constraint-generate` uses the **Typical Enforce** column from the Kind table above as the default. The generator may also add extra enforcement layers based on the constraint body content (e.g. adding `pbt` if a Properties section is present).

## Body Sections

The constraint body uses a legal/BDD hybrid structure. Each section maps directly to a test generation target.

| Section | Purpose | Maps To |
|---|---|---|
| **Given** | Preconditions / initial state | Test setup (arrange) |
| **When** | Triggering action | Test action (act) |
| **Then** | Expected outcome | Test assertion (assert) |
| **Unless** | Exception conditions + alternative outcomes | Additional test branches |
| **Examples** | Concrete input/output table | Parameterized unit tests (e.g. TS: `it.each`, Python: `@pytest.mark.parametrize`) |
| **Properties** | Semi-formal universal properties | PBT tests (e.g. TS: fast-check, OCaml: QCheck, Rust: proptest, Python: Hypothesis) |

All sections use `## Heading` level.

### Unless Syntax

Unless contains one or more exception groups. Each group has **condition lines** (no arrow prefix) and **outcome lines** (`→` prefix):

```markdown
## Unless
- condition (no arrow)
- → outcome (arrow prefix)

- another condition
- → another outcome
```

Key rules:
- **Condition lines**: plain list items describing when the exception applies
- **Outcome lines**: prefixed with `→`, describing what happens instead of the Then outcome
- **Multiple groups**: separated by a blank line between them
- **Logical OR**: groups are combined with OR semantics — if any group's conditions are met, its outcome applies
- The agent distinguishes condition lines from outcome lines by the `→` prefix

### Examples Section

The Examples section **must** be a Markdown table with **at least 3 rows** of data (not counting the header). This is a hard requirement:

> No concrete examples = no enforcement.

The table maps directly to parameterized unit tests in the detected language (e.g. TS: `it.each`, Python: `@pytest.mark.parametrize`, OCaml: `Alcotest.test_case` list, Rust: `#[test]` with test cases). Each row becomes one test case. Column headers become parameter names.

### Properties Section

Properties use a semi-formal universal quantifier syntax:

```
forall X where condition: property
forall (X, Y): property
```

The `where` clause is optional. When present, it becomes a filter or precondition. Each property maps to a PBT assertion in the detected language's library (e.g. `fc.property()` in fast-check, `QCheck.Test.make` in QCheck, `proptest!` in proptest, `@given` in Hypothesis). The `forall` variables become arbitraries and the property expression becomes the assertion.

## Complete Examples

### Example 1: Domain/State Constraint

```markdown
# constraints/USER_003-soft-deleted-no-login.md
---
rule: USER_003
kind: permission
scope: src/auth/**, src/user/**
subject: User
enforce: validation, pbt
---

## Given
- user.state = soft_deleted

## When
- password login attempted

## Then
- deny login
- return AUTH_DENIED

## Unless
- user.state = recoverable AND deleted_at <= 30 days
- → allow recovery flow only, return RECOVERY_REQUIRED

## Examples
| user.state | deleted_at | action | expected |
|---|---|---|---|
| soft_deleted | 60 days ago | login | AUTH_DENIED |
| hard_deleted | 90 days ago | login | AUTH_DENIED |
| recoverable | 10 days ago | login | RECOVERY_REQUIRED |
| recoverable | 45 days ago | login | AUTH_DENIED |
| active | - | login | SUCCESS |

## Properties
- forall user where state = soft_deleted AND NOT recoverable:
  login(user) → AUTH_DENIED
- forall user where state = hard_deleted:
  search(query) never contains user
```

### Example 2: Code-Level Constraint

```markdown
# constraints/MONEY_001-no-float-money.md
---
rule: MONEY_001
kind: prohibition
scope: src/billing/**, src/payment/**
enforce: ast-grep, pbt
---

## Given
- Any code that handles monetary amounts

## When
- Declaring variables, function parameters, or return values involving money

## Then
- Must use Decimal type
- Multiplication and division must specify rounding mode

## Unless
- Display-only formatting functions (toDisplayString) may return string
- Test fixture data may use literal numbers

## Examples
| context | type used | valid |
|---|---|---|
| calculateTotal() return | Decimal | yes |
| calculateTotal() return | number | no |
| invoice.amount field | Decimal | yes |
| invoice.amount field | float | no |
| toDisplayString() return | string | yes |
| test fixture | 19.99 (literal) | yes |

## Properties
- forall (a: Decimal, b: Decimal, c: Decimal):
  (a + b) + c === a + (b + c)
- forall (amount: Decimal, currency: Currency):
  toUSD(toTWD(amount)) - amount < 0.01
```
