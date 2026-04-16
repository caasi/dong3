# Mutation Feedback Guide

This guide describes how to interpret mutation testing results and
systematically improve property tests until surviving mutants are eliminated
or identified as equivalent. The workflow applies to any mutation tool
(Stryker, mutaml, cargo-mutants, mutmut) — use the one matching your
language per the toolchain matrix.

---

## Mutation Score

```
mutation score = killed mutants / total mutants
```

- **Killed**: a test failed when the mutation was applied — the test suite
  detects this fault.
- **Survived**: no test failed — the test suite has a gap.
- **Default target**: 80% mutation score.

---

## Interpreting Surviving Mutants

Each surviving mutant falls into one of three categories:

### 1. Equivalent Mutant

The mutation does not change observable behavior. For example, replacing
`x >= 0` with `x > -1` when `x` is always an integer. These mutants
**cannot be killed** because no test can distinguish the original from the
mutant.

**Action**: Mark as equivalent and ignore. No property change needed.

### 2. Weak Test

A property test covers the mutated code path but does not assert on the
specific behavior that changed. The property is too permissive.

**Action**: Strengthen the existing property. Add tighter postconditions or
narrower invariants that would fail under the mutation.

### 3. Missing Test

No property test covers the mutated code path at all.

**Action**: Write a new property test that exercises the code path and
asserts on the behavior the mutation alters.

---

## Feedback Loop

### Round 1

1. **Run the mutation tool** to collect the full mutation report.
2. **Collect surviving mutants** — note file, line, and mutation operator
   for each.
3. **Analyze each survivor**: determine which existing property *should*
   catch it, or whether a new property is needed.
4. **Strengthen or add properties**:
   - For weak tests: tighten the assertion or add a new postcondition.
   - For missing tests: write a new property covering the code path.
5. **Re-run PBT** (use the language's test command) to confirm the
   new or strengthened properties pass against the unmutated code.

### Round 2

1. **Re-run the mutation tool** to check if previously surviving mutants are now
   killed.
2. For any mutants that still survive:
   - Re-analyze: is this an equivalent mutant, or does the property need
     further strengthening?
   - Apply fixes and re-run PBT to confirm.

### Round 3

1. **Final mutation run**.
2. Any mutants still surviving after three rounds are candidates for
   escalation (see below).

**Maximum**: 3 rounds total. Do not loop indefinitely.

---

## Early Termination

Stop the feedback loop early when further rounds will not help:

- **Same mutant survives after 2 rounds of strengthening**: The mutant is
  likely equivalent. Report it to the user for judgment rather than
  continuing to modify tests.
- **Mutation score plateaus** (no improvement between consecutive rounds):
  The remaining survivors are likely equivalent mutants or require
  architectural changes beyond test strengthening. Report the plateau and
  remaining mutants to the user.

---

## Escalation

After 3 rounds, or when early termination conditions are met, produce a
summary table of all unresolved mutants:

| Mutant | Location | Mutation | Survived rounds | Likely cause |
|--------|----------|----------|-----------------|--------------|
| M1 | `src/foo.<ext>:42` | `>=` to `>` | 3 | Equivalent mutant |
| M2 | `src/bar.<ext>:17` | Removed call to `validate()` | 2 | Weak test |
| M3 | `src/baz.<ext>:88` | Negated condition | 3 | Equivalent mutant |

For each row, include:

- **Mutant**: identifier from the mutation report.
- **Location**: file path and line number.
- **Mutation**: what the tool changed (operator, deletion, negation, etc.).
- **Survived rounds**: how many feedback rounds this mutant survived.
- **Likely cause**: your best assessment — equivalent mutant, weak test, or
  missing test.

Present this table to the user and ask them to judge whether each surviving
mutant represents an equivalent mutant (acceptable) or a real gap in test
coverage (requires further action).
