---
description: Human-absent preparation — local-first by default: fetch, derive the queue from local + remote refs, work privately on the configured work-prefix branches (default prepare/*), keep work local; remote push is the cross-machine opt-in. External silence
---

# /tsugu:prepare

Invoke the `tsugu` skill and run the **prepare** routine. Pass `$ARGUMENTS`
through as free-form context.

Load-bearing invariants the skill enforces: external silence (interrupt only if
unsafe, destructive, or blocked); state derived from refs and the DAG — no
status fields, single-layer (no committed status notes); **local-first** —
work stays on local `prepare/*` by default, remote push is the cross-machine
opt-in (`push-prepare-branches: yes`); bootstraps personal config (observation sources + opt-in skills,
in the global personal folder) once when interactive and a section is absent — a
scheduled run never blocks; invokes no user-installed skill by default (opt-in
via personal config only). The skill cannot self-wake — the human starts an
external driver (local cron / `/loop` / `/schedule`) on a cadence. By default
that driver runs on the **provisioned machine** (the one holding both the
personal-folder source config and the live MCP/connector credentials —
typically the local homelab); an *unprovisioned* cloud/headless run is allowed
but degrades to git-native only (it works the queue derivable from refs, with
no tracker/source intake).
