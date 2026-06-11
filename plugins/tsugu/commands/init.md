---
description: Set up or migrate the repo's .tsugu/ workspace + policy.md — asks the minimum; idempotent; re-running migrates older schemas (tsugu-schema)
---

# /tsugu:init

Invoke the `tsugu` skill and run the **init** routine. Pass `$ARGUMENTS` through
as free-form context.

Load-bearing invariants the skill enforces: idempotent repair (never overwrites
a curated `policy.md`); version-stamped migration with the stamp written last;
push-protected defaults ride an `init/*` branch + human-approved PR.
