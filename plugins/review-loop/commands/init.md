---
description: Discover which coding CLIs this host has, verify how to call each one by actually calling it, and record the reviewer roster you want here — idempotent; re-run whenever the host changes
---

# /review-loop:init

Invoke the `review-loop` skill and run the **init** routine. Pass `$ARGUMENTS` through as
free-form context.

**Usage:** `/review-loop:init`

Why it exists: the roster is a property of *this host* and of your taste. Which reviewers you
can field, and which you want, does not belong hard-coded in a skill.

Load-bearing invariants:

- **Probes presence, verifies invocation, asks for the rest.** The probe is `command -v` over a
  candidate list plus `<cli> --version` — no script, no network, no credentials, no other
  plugin's config. Everything it cannot probe is asked, not guessed.
- **Verifies by trying.** Knowing `codex` exists tells you nothing about how to drive it. `init`
  calls each enrolled CLI once, on a **throwaway fixture — never your real working tree** — and
  stores the literal command line that worked. Bounded to two attempts. A CLI whose invocation
  cannot be established is **detected but not enrolled**, with the reason shown.
- **Asks for the roster as two roles, split by cost.** A **routine panel** runs on every review —
  compose it from the session's own model, other Claude models, and `codex`; several at once is
  normal (Opus + Sonnet + gpt-5.5), and same-family members are first-class, not a fallback. A
  **direction guard** is an expensive model (e.g. Fable) held back from every round; `init` shows
  each reviewer's rough cost so you can decide. The direction guard adds **no sub-command** — it
  runs under the ordinary `/review-loop`, proposed only when the escalation rule fires. Each
  reviewer is written with its `role` (`routine` | `direction`).
- **Presence is not authentication, and Copilot is not enrollable.** The built-in GitHub Copilot
  adapter needs **no enrollment**: it runs for PR targets whenever `gh` is authenticated and `jq`
  is present, unless you opt out. `init` checks `gh auth status` *and* `command -v jq` so it can
  tell you whether Phase B will reach Copilot — it writes no Copilot enrollment record.
  Enrollment is for a *declared* reviewer on another forge.
- **Never asks for `sudo`, never fixes your host.** If Codex's native sandbox is blocked, `init`
  records `form: embedded` — a fully supported path, not a degradation — and may point once at
  `references/codex-sandbox-host-fixes.md`. Restoring the native path is an AppArmor/sysctl change
  affecting every `bwrap` caller on the machine: separate work, which you own.
- **Endpoints are declared, never discovered.** Name one and `init` records the name. Where it is
  an alias in the `chat-subagent` registry the entry is marked `via: chat-subagent`, and the url
  and `api_key_env` stay in that plugin's files. **No secrets are ever written.**
- **Idempotent, and it stamps its schema.** The config carries a `review-loop-config` stamp;
  `init` writes it and, on re-run, migrates an older one — removing the stale stamp rather than
  leaving both. Re-running re-probes, prints a diff of what changed, and preserves explicit
  opt-outs (`enabled: false` is a decision, not an absence).
- **Never a precondition.** With no config the loop works exactly as it does today, and hints at
  `init` once.

Writes `~/.claude/review-loop.local.md` (global), overridden per project by
`<project-root>/.claude/review-loop.local.md`. Offers to add `.claude/*.local.md` to
`.gitignore` if absent.
