---
description: Human-absent preparation — fetch, derive the queue from refs, work privately on work-prefix branches (prepare/* by default), push evidence. External silence
---

# /tsugu:prepare

Invoke the `tsugu` skill and run the **prepare** routine. Pass `$ARGUMENTS`
through as free-form context.

Load-bearing invariants the skill enforces: external silence (interrupt only if
unsafe, destructive, or blocked); state derived from refs and the DAG — no
status fields; pushes by policy (default yes); asks where tasks come from once,
only when interactive and unconfigured — a scheduled run never blocks; invokes
no user-installed skill by default. Wire this routine to /schedule or cron — it
cannot self-wake.
