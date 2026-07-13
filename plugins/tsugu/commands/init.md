---
description: Set up or migrate the repo's .tsugu/ workspace + policy.md — asks the minimum; idempotent; re-running migrates older schemas (1→2→3→4→5→6→7) (tsugu-schema)
---

# /tsugu:init

Invoke the `tsugu` skill and run the **init** routine. Pass `$ARGUMENTS` through
as free-form context.

Load-bearing invariants the skill enforces: stamps `tsugu-schema: 7`; the
default work prefix is `prepare/*` and policy carries an `## Accepted Prefixes`
list (default `feature/* bugfix/* chore/*`); no repo `intake/`, `runs/`,
`packets/`, or `templates/` directory is created — templates are read from the
plugin by reference; idempotent repair (never overwrites a curated `policy.md`);
migration applies steps in order (1→2→3→4→5→6→7, stamp written last; the 3→4
prefix-collapse to single `prepare/*` is proposed, not forced; the 4→5 step pins
the old `push-prepare-branches: yes` when absent so local-first does not silently
flip an existing repo); push-protected
defaults ride an `init/*` branch + human-approved PR. `init` also writes the
always-loaded agent-md routing pointer (`CLAUDE.md`, and `AGENTS.md` if the repo
uses one) — append-only, marker-idempotent, human-approved.
