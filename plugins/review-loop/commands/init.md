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
- **Asks for the roster as two roles.** A **routine panel** runs on every review — compose it
  from the session's own model, other Claude models, and `codex`; several at once is normal
  (Opus + Sonnet + gpt-5.5), and same-family members are first-class, not a fallback. An
  **on request** reviewer runs only in a review where you name it, and the loop never proposes
  it — use it for an expensive model, or for a provider you want to call only by hand. `init`
  shows the rough cost of each reviewer so you can decide. Each reviewer is written with its
  `role` (`routine` | `on_request`).
- **Presence is not authentication, and Copilot is not enrollable.** The built-in GitHub Copilot
  adapter needs **no enrollment**: it runs for PR targets whenever `gh` is authenticated and `jq`
  is present, unless you opt out. `init` checks `gh auth status` *and* `command -v jq` so it can
  tell you whether Phase B will reach Copilot — it writes no Copilot enrollment record.
  Enrollment is for a *declared* reviewer on another forge.
- **Never asks for `sudo`, never fixes your host.** If Codex's native sandbox is blocked, `init`
  records `form: embedded` — a fully supported path, not a degradation — and may point once at
  `references/codex-sandbox-host-fixes.md`. Restoring the native path is an AppArmor/sysctl change
  affecting every `bwrap` caller on the machine: separate work, which you own.
- **Records who runs the reviewer, and how the loop reaches it.** Each entry gets `harness`
  (`claude` when a Claude subagent sends all of the input, `external` when another harness reads
  the files by itself) and, for a reviewer that is not a Claude model, `via`. When a delegate
  skill for the CLI is installed (`pi-delegate`, `codex-delegate`), `via` names the skill and
  `init` verifies through it: the skill carries the fixes for known problems of the CLI. The
  verified command is still stored, with its read-only option, and `verified_with` holds the CLI
  version and the skill version. `cli` is for a CLI with no delegate skill.
- **Asks about private content.** `init` asks for the `private_repos` list, and for
  `private_content: allow | deny` for each reviewer that is not a Claude model. It suggests
  `deny` for a reviewer on a provider that you have not accepted for private content. A missing
  value counts as `deny` for each entry that is not `kind: claude-model`.
- **Endpoints are declared, never discovered.** Name one and `init` records the name. Where it is
  an alias in the `chat-subagent` registry the entry is marked `via: chat-subagent`, and the url
  and `api_key_env` stay in that plugin's files. **No secrets are ever written.** The roster
  also holds no url and no name of a key variable or a key file: those belong to the
  configuration of the delegate skill or of `chat-subagent`.
- **Idempotent, and it stamps its schema.** The config carries a `review-loop-config` stamp, now
  `2`; `init` writes it and, on re-run, migrates an older one — removing the stale stamp rather
  than leaving both. Re-running re-probes, prints a diff of what changed, and preserves explicit
  opt-outs (`enabled: false` is a decision, not an absence).
- **Migrates stamp 1 faithfully — the YAML form and the prose form.** A stamp-1 file can hold a
  `panel:` list, or only the stamp and prose tables that hand edits extended. Both migrate the
  same way:
  1. Each fact that a field can hold goes into that field: reviewer, model, role, opt-out, the
     verified command and its version.
  2. Each rule in force that no field holds becomes a YAML comment on the entry it applies to.
     A rule in prose that matches a field becomes that field — for example "do not send it
     private content" becomes `private_content: deny`. Look for rules also inside research
     text: a conclusion such as "request it by hand, once" is a rule.
  3. `role: direction`, or a reviewer that the prose holds back from every round, becomes
     `on_request` unless you choose `routine`. A reviewer that the prose says runs only when you
     ask is `on_request`.
  4. History and research do not go into the new roster. `init` lists each such passage and asks
     which ones to save to the memory of the harness. It saves only what you choose.
  5. A key value in the old file stops the migration: say where it is, and write nothing. A key
     variable name or a key file name does not go into the roster. `init` tells you, so that you
     can move it to the configuration of the skill.
  6. Before it writes, `init` shows the new file and a table that maps each passage of the old
     file to a field, a comment, or "history or research". It writes only after your yes, and it
     keeps the old file as `review-loop.local.md.stamp1`.
- **Keeps comments on a re-run.** A YAML comment holds a rule, so edit the file in place. Do not
  generate the YAML again from the parsed data, because that drops the comments.
- **Never a precondition.** With no config the loop works exactly as it does today, and hints at
  `init` once.

Writes `~/.claude/review-loop.local.md` (global), overridden per project by
`<project-root>/.claude/review-loop.local.md`. The schema is in the skill (§ *The roster file*).
Offers to add `.claude/*.local.md` to `.gitignore` if absent.
