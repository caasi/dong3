---
description: Set up or migrate the repo's .tsugu/ workspace + policy.md — asks the minimum; idempotent; re-running migrates older schemas (1→2→3) (tsugu-schema)
---

# /tsugu:init

Invoke the `tsugu` skill and run the **init** routine. Pass `$ARGUMENTS` through
as free-form context.

Load-bearing invariants the skill enforces: stamps `tsugu-schema: 3`; no repo
`intake/`, `runs/`, `packets/`, or `templates/` directory is created — templates
are read from the plugin by reference; idempotent repair (never overwrites a
curated `policy.md`); migration applies steps in order (1→2→3, stamp written
last); push-protected defaults ride an `init/*` branch + human-approved PR.
