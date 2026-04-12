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
