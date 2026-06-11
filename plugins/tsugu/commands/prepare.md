---
description: Human-absent preparation — fetch, derive the queue from refs, work privately on the configured work-prefix branches (defaults prepare/* investigate/* review/*), push evidence when policy permits. External silence
---

# /tsugu:prepare

Invoke the `tsugu` skill and run the **prepare** routine. Pass `$ARGUMENTS`
through as free-form context.

Load-bearing invariants the skill enforces: external silence (interrupt only if
unsafe, destructive, or blocked); state derived from refs and the DAG — no
status fields, single-layer (no committed status notes); pushes by policy
(default yes); bootstraps personal config (observation sources + opt-in skills,
in the global personal folder) once when interactive and a section is absent — a
scheduled run never blocks; invokes no user-installed skill by default (opt-in
via personal config only). Wire this routine to /schedule or cron — it cannot
self-wake.
