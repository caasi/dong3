---
name: constraint-write
description: >-
  Use when the user asks to "/constraint-write", "write constraint",
  "define constraint", "幫我寫 constraint", "定義 constraint", or when
  the agent detects prohibition ("不能", "禁止", "must not"), obligation
  ("必須", "一定要", "always"), or invariant ("roundtrip", "idempotent")
  language in conversation and wants to suggest writing a constraint.
---

# Constraint Write

You are helping the user articulate and document constraints in structured
natural language. Constraints are the user's laws; deterministic tools are
the judges.

## Workflow

1. If the user describes a rule, use dialogue to clarify the constraint
   one section at a time: Given → When → Then → Unless → Examples → Properties
2. Read `references/constraint-format.md` for the canonical format
3. Scan existing `constraints/*.md` to determine the next available
   RULE_ID number for the domain
4. Each constraint **must** have at least 3 rows in the Examples table —
   no examples = no enforcement
5. Write the constraint to `constraints/<RULE_ID>-<slug>.md`
6. Create the `constraints/` directory if it doesn't exist
7. After writing, suggest running `/constraint-generate` to produce test artifacts from the new constraint.

## Proactive Suggestion

When the user uses prohibition ("不能", "禁止", "must not"), obligation
("必須", "一定要", "always"), or invariant ("roundtrip", "idempotent")
language in conversation, propose writing a constraint to capture that rule.

## Property Patterns

Consult `references/property-patterns.md` when helping the user write the
Properties section of a constraint.
