---
description: Discover which coding CLIs this host has, verify how to call each one by actually calling it, and record the enrolled reviewer roster — idempotent; re-run whenever the host changes
---

# /review-loop:init

Invoke the `review-loop` skill and run the **init** routine. Pass `$ARGUMENTS`
through as free-form context.

**Usage:** `/review-loop:init`

Load-bearing invariants the skill enforces:

- **Probes presence, verifies invocation, asks for the rest.** The probe is a
  `command -v` sweep plus `<cli> --version` — no script, no network, no credentials,
  no other plugin's config. Everything it cannot probe is asked, not guessed.
- **Verifies by trying.** Knowing `codex` exists tells you nothing about how to
  drive it. `init` calls each enrolled CLI once, on a **throwaway fixture diff —
  never your real working tree** — and stores the literal command line that worked
  in `invocation.command`. Bounded to two attempts per CLI. A CLI whose invocation
  cannot be established is **detected but not enrolled**, with the reason shown.
- **Never asks for `sudo`, and never fixes your host.** If Codex's native sandbox is
  blocked, `init` records `form: embedded` — a fully supported path — and may point
  once at `references/codex-sandbox-host-fixes.md`. Restoring the native path is an
  AppArmor/sysctl change affecting every `bwrap` caller on the machine: **separate
  work, in its own session, which you own.** review-loop never gates on it, never
  blocks for it, and never re-raises it.
- **Presence is not authentication, and Copilot is not enrollable.** The built-in
  GitHub Copilot adapter needs **no enrollment**: it runs for PR targets whenever `gh` is
  authenticated **and `jq` is present**, unless you opt out. `init` checks `gh auth status`
  *and* `command -v jq` so it can tell you whether Phase B will reach Copilot — it writes no
  Copilot enrollment record. Enrollment
  is for a *declared* reviewer on another forge.
- **Endpoints are declared, never discovered.** `init` does not go looking through
  other plugins' registries. Name one and it records the name — url and
  `api_key_env` stay in `chat-subagent`'s files. **No secrets are ever written.**
- **Idempotent, and it stamps its schema.** The config carries a `review-loop-config`
  stamp. `init` writes it, and on re-run migrates an older one — removing the stale
  stamp rather than leaving both behind. Re-running re-probes, prints a diff of what
  changed, and preserves explicit opt-outs (`enabled: false` is a decision, not an
  absence), declared endpoints, and forge reviewers.
- **Never a precondition.** With no config the loop works exactly as it does today
  and hints at `init` once.

Writes `~/.claude/review-loop.local.md` (global), overridden per project by
`<project-root>/.claude/review-loop.local.md`. Offers to add `.claude/*.local.md`
to `.gitignore` if absent.
