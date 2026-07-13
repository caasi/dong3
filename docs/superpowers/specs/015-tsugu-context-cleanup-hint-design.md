# 015 — Tsugu plants a standing post-handoff cleanup hint in `context.md` and routes agents to it via the agent md: the finishing agent resets the branch narrative before it lands (schema 6 → 7)

> Numbered **015**, not 014: the interleaved `docs/superpowers/specs/` sequence already holds
> `014-review-loop-reviewer-roster-design.md`. This spec continues the **tsugu** lineage
> (004–008, 011–013) and takes the next free global number.

## Relationship to 004 / 005 / 006 / 007 / 008 / 011 / 012 / 013

This spec **extends** the tsugu lineage `004 → 005 → 006 → 007 → 008 → 011 → 012 → 013`. Everything those
specs establish stands: git-native intake, derived state (refs + DAG + containment + recency; no
status fields), the no-skill-orchestration rule, the no-force principle, the storage split (committed
`.tsugu/` vs personal global folder), the work-prefix / accepted-prefix partition, 011's
handoff-oriented converge (accept = mode-agnostic rename **and stop**; completion is the human's;
maintenance exception; curation; `prune`), 012's local-first `prepare`, 013's freshness-rebase +
`context.md merge=union`, and the never-auto-merge / public-coordination-needs-approval boundary.

015 closes one gap none of them address: **after a handed-off branch is finished by the human (with an
agent) and lands on the default branch, the mainline `context.md` accumulates the dead branch's story,
and nobody is reminded to reset it — because that moment is outside tsugu's lifecycle.**

## The problem

`context.md` is **per-ref** and carries `merge=union` (013's `.tsugu/.gitattributes`). A work branch
rewrites the inherited mainline form into *that branch's own story* — its investigation, open
questions, next actions (that first rewrite commit *is* the claim). At `accept`, 011 hands the work off
by **renaming** `prepare/<slug>` → `<accepted-prefix>/<slug>` **and stopping**: the agent does *not*
rewrite `context.md` to a mainline narrative, build, push, or open a PR — completion is the human's
(SKILL.md `converge`, Accepted). So the branch's **own-story** `context.md` rides the rename onto the
accepted branch unchanged.

The human then takes over the accepted branch and **finishes the feature with an agent** — planning,
coding, review. **This is outside tsugu's `prepare → converge → prune` lifecycle**; tsugu stopped at the
rename. When that work lands on the default branch (a merge commit, in `include` mode), two things leak
into the mainline:

1. `merge=union` **concatenates** the branch's whole own-story narrative onto the default branch's
   mainline `context.md`. The mainline note — which should say only "what this repo is, where the
   mainline stands, what recently landed" — now carries the landed branch's *in-flight* Open questions
   and Next actions, describing work that is already shipped. (Concatenation of two full narratives is
   also self-evident in the result: the mainline ends up with **duplicate `##` section headers**.)
2. `knowledge/` entries that were WIP-specific to that branch ride along too — no longer WIP.

The reset belongs to the **finishing agent**, at the moment it and the human are **done, before the
branch lands**: collapse the branch's own story back to a one-line "what recently landed" mainline note,
so what merges to default is clean. But that moment is **outside tsugu**, so no routine prompts it, and
agents consistently forget. Filed as **issue #62**.

### Who cleans, and the two surfaces that reach them

- **converge does not clean.** Its job is to *prepare* context for the human and the next agent — the
  morning status view, the regenerated packet, the handed-off branch — and then hand off. Adding a
  "collapse the mainline" step to converge would be wrong: at converge the work is not yet finished, so
  there is nothing landed to collapse.
- **The finishing agent cleans, at finish-time, before landing.** It owns the accepted branch and the
  landing, so it is the one actor positioned to reset `context.md` so the merge stays clean. But it is
  working **outside tsugu** — often a **tsugu-unaware** agent that is just helping the human implement,
  with no tsugu skill loaded and no reason to open `.tsugu/context.md`. So the reminder must reach it
  through **two surfaces**, and the second is what makes the first reliable:
  1. **The block rides the branch.** The standing block (below) is planted by `init` in the mainline
     `context.md`, inherited by every `prepare` branch, and carried by the accept rename onto the
     accepted branch — so it sits in the very `context.md` the finishing agent edits if it opens the
     file. On its own this is *opportunistic*: it fires only if the agent happens to open that file near
     landing.
  2. **The agent md routes any agent to it (Change E).** `init` also writes a short standing pointer
     into the repo's **agent md** (`CLAUDE.md`, and `AGENTS.md` if the repo uses one) — the file
     agents in the repo load at session start (whichever of the two a given agent honors; writing both
     covers the common set). The pointer tells an agent that loads the agent md, tsugu-aware or not,
     that when it finishes an accepted-prefix branch carrying `.tsugu/context.md`, it must read that
     file's `POST-HANDOFF CLEANUP` block and reset the narrative before landing. This is the concrete
     routing channel a bare in-file comment lacks: loaded at session start, so it reaches even a
     tsugu-unaware finishing agent, and re-loaded at the (often later) landing session where the reset
     actually happens.

015 is **passive** by explicit choice — a reminder a future agent reads and acts on, delivered through
an always-loaded pointer, **not** an active detector (a routine that scans for accumulated narratives
and collapses them) and **not** a human-absent daemon. The active detector was considered and
**deferred**; the marker below is greppable so one could be layered on later, but it is out of scope.
Passive keeps 015 self-contained: no new routine step in `prepare`/`converge`/`prune`, pure narrative +
one migration.

| Line | Change | What it supersedes | Issue |
| --- | --- | --- | --- |
| A | **`init` writes a standing POST-HANDOFF CLEANUP block at the end of the mainline `context.md`.** Every work branch inherits it (it is part of the form the branch rewrites), so it **rides the accept rename onto the accepted branch** and reaches the finishing agent. In the normal inherited-from-merge-base path, `merge=union` keeps a **single** copy so long as the block stays byte-identical (unchanged from the merge base on both sides, so never a conflicting hunk). The block is an HTML comment naming the actor (the finishing agent), the moment (done, before landing), the collapse action, the **merge-base-scoped** `knowledge/` reconcile with its human-approval gate, and **its own byte-for-byte self-protection** | Nothing planted a reminder for the out-of-lifecycle finish moment; the mainline silently accumulated landed-branch narrative | #62 |
| B | **`prepare` preserves the block byte-for-byte when it rewrites the branch's `context.md`.** Step 8's "rewrite the inherited mainline form into the branch's own story" gains one clause: carry the trailing standing block through **verbatim — do not delete it and do not retype it**. Byte-identity is load-bearing: only an unchanged-on-both-sides block stays a single copy under `merge=union`; a retyped (drifted) block becomes a conflicting hunk that union would then duplicate, and a dropped block is deleted from default on the human's merge (a clean delete-vs-unchanged 3-way resolution union does not save). Drift/duplication is **repaired by `init` re-run normalization** (Change D), since the failure leaves the marker present and a plain append would not heal it | 011/013 step 8 described a free narrative rewrite with no mention of a must-survive trailing block | #62 |
| C | **The standing block is the *named home* for the out-of-lifecycle finish-time reset; converge prepares it, never runs it.** SKILL.md documents it once (spine `context.md` description) and cross-references it from `converge` (handoff *prepares* the context and leaves the block intact on the handed-off branch — converge does **not** collapse anything) and `prune` (which sweeps branches, not content). The stale `notes-and-packet.md` § "Rewrite on merge-back" — which predates 011 and claims converge rewrites `context.md` to a clean mainline before merge — is **reconciled** to the 011 model | The finish-time content reset had no documented home; and a pre-011 paragraph asserted converge already cleaned the mainline, contradicting the problem | #62 |
| E | **`init` writes a standing POST-HANDOFF pointer into the repo's agent md (`CLAUDE.md` / `AGENTS.md`) — the always-loaded routing channel.** It routes any agent that finishes an accepted-prefix branch carrying `.tsugu/context.md` to the block, and doubles as the routed **backstop** ("if the default's `context.md` already shows duplicate `##` headers, collapse it"). Because `init` is human-present and this writes a human-facing doc, it is **asked once and human-approved** (the public-coordination boundary), **idempotent** (skip when the pointer marker is present), and on a push-protected default rides the same `init/*` PR as `policy.md`. Absent an agent md, `init` offers to create a minimal one | The in-file block alone was opportunistic — no channel routed a tsugu-unaware finishing agent to it, and the on-default "backstop" had no actor that both reads default's `context.md` and may lawfully collapse it | #62 |
| D | **Schema 6 → 7 migration: normalize the block *and* add the agent-md pointer to existing repos.** For the mainline `context.md`, `init` re-run / migration **normalizes** — strips every `POST-HANDOFF CLEANUP` comment block and re-appends one canonical copy (heals absent, canonical, and drifted/duplicated alike), never touching the surrounding curated narrative. It also adds the Change-E agent-md pointer (human-approved, idempotent). Work branches inherit the block on their next freshness-rebase (union merge) or next active rewrite; the migration touches no branch refs | A template-only change would leave already-`init`-ed repos without the reminder or the routing pointer; and a grep-then-append idempotency check cannot heal a drifted/duplicated block (Change B) | #62 |

Everything in 004–013 not named here is unchanged.

## The principle (the spine)

> **The mainline `context.md` describes the mainline — not the branches that have already flowed into
> it.** A branch's `context.md` is a live investigation; once the human finishes the handed-off branch,
> that investigation is history and belongs collapsed to a one-line "what landed" **before the branch
> lands**, not carried verbatim into the mainline note on merge. That finish happens outside tsugu, so
> the reminder must reach the finishing agent through a channel it is guaranteed to load (the agent md)
> and ride the branch it is editing (the block).

Four consequences follow:

- **Planted + routed — reliable delivery, honestly bounded.** The bug is "agents forget." Baking the
  block into the template makes the reminder *present* on the branch; the agent-md pointer (Change E)
  makes it *delivered* — always-loaded, so a tsugu-unaware finishing agent is told to open the file at
  finish-time, and re-told at the landing session. This is far stronger than an opportunistic in-file
  comment. It is still **not a hard guarantee**: an agent can ignore a loaded instruction, `prepare`
  must preserve the block (Change B), and if a rewrite drops or drifts it the block is lost/duplicated
  on the human's merge — the self-heal is an `init` re-run *normalizing* the block (Change D). 015
  states this plainly rather than overclaiming "structural."
- **What the standing block buys over a cheaper accept-time note.** A converge-time note appended at
  `accept` would reach every branch that passes converge with no schema bump. The standing block's extra
  cost buys one thing the note cannot: it also covers **containment takeovers** (a human carried the
  work onto their own branch, `isaac/fix-thing`, that never passed converge) — that branch still
  inherited the block, so its finishing agent is still reminded. 015 keeps the standing block for that
  coverage; Change E's pointer is what makes either form actually reach the agent.
- **A permanent immutable region in a "freely maintained" file — owned explicitly.** `context.md` is
  otherwise pure narrative, maintained freely; the block introduces a small **standing, byte-immutable**
  region at its end. That carve-out is deliberate and is called out here (and in the spine description),
  not left implicit in Change B.
- **`merge=union`-stable and mode-aware.** Kept byte-identical (Change B), the block is present in the
  merge base on both sides in the normal inherited path, so union never duplicates it — one copy through
  every rebase and merge (a hand-repaired history that reintroduces the block on a divergent base is the
  out-of-band exception, healed by Change D normalization). In `exclude` mode
  (`public-branch-tsugu: exclude`) the human strips `.tsugu/` before the public PR, so no branch
  narrative reaches default; the block is then **inert** — present but never acted on. It does real work
  only in `include` mode.

### Cost, in plain accounting

015 is a schema bump (6 → 7), a migration, and edits across ~13 files, for what is fundamentally a
standing comment plus an agent-md pointer. That weight is consistent with the repo's migration contract
(013's 5→6 set the precedent for a behavior-affecting default reaching existing repos), and the
append-only-into-a-curated-file novelty is called out below. The honest bound on efficacy: **the block
fires reliably only insofar as the finishing agent honors the always-loaded agent-md pointer** — that
routing is what turns "hope it opens the file" into "it is told to," but it presupposes the finishing
agent **loads the repo agent md at all** (most coding agents do; writing both `CLAUDE.md` and
`AGENTS.md` covers the common set, but an agent that honors neither is never reached), and even a routed
agent can disregard a loaded instruction. 015 does not claim otherwise.

### The block

`init` writes this as the final lines of the mainline `context.md` (after `## Promotion candidates`):

```
<!-- POST-HANDOFF CLEANUP (standing instruction — keep this block verbatim; never
     delete it, never retype it). After tsugu hands a work branch off (converge
     accept renames prepare/<slug> to an accepted branch and stops), a human takes
     over and finishes the feature with an agent — OUTSIDE tsugu's prepare → converge
     → prune lifecycle, so no tsugu routine runs there. If you are that finishing
     agent: when you and the human are DONE, and BEFORE the branch lands on the
     default branch, reset this context.md back to the mainline form — collapse this
     branch's own story ("Why this ref exists" / "Open questions" / "Next actions")
     into a one-line "what recently landed" note under "Current understanding" — so
     what lands on default is clean and the mainline note does not accumulate a dead
     branch's narrative on merge. Then reconcile the knowledge/ entries THIS branch
     added (diff against the merge-base to find them — never touch inherited mainline
     entries): prune the transient ones; a durable one is promoted to the agent md
     (CLAUDE.md / AGENTS.md) only with the human's approval (that promotion is public
     coordination). BACKSTOP: if this reset was missed and the mainline context.md on
     the default branch already shows a landed branch's story (duplicate "##" section
     headers), the next agent that reads it collapses it the same way — but that edits
     .tsugu/context.md ON THE DEFAULT BRANCH, which is public coordination, so get the
     human's approval first. Leave THIS block in place — it must survive the reset for
     the next work. -->
```

- **Marker.** The stable string `POST-HANDOFF CLEANUP` is the block's identity: it lets `init`
  re-run / migration find and **normalize** the block (Change D) and gives a **future** active detector
  (deferred) a greppable anchor. The marker text is fixed within schema 7.
- **HTML comment, not a section.** Guidance for the reading agent, in the template's existing `<!-- -->`
  style — so it never renders as mainline "content."
- **`knowledge/` reconcile is merge-base-scoped and human-gated.** "The entries THIS branch added" is
  operationalized (diff against the merge-base), so an eager agent cannot delete inherited mainline
  knowledge; and promotion into the agent md carries the "only with the human's approval" gate
  (`policy.md` "Public Coordination (ask first)"; `notes-and-packet.md` "the agent drafts, the human
  approves; never an autonomous write"). The block does **not** mention the personal packet
  (personal/ephemeral, regenerated live, never committed).

### The agent-md pointer (Change E)

`init` writes (human-approved, once) a short standing block into the repo's agent md — the routing
channel. Illustrative form:

```
## tsugu — post-handoff cleanup
This repo uses tsugu (git-native prepare/converge). When you FINISH work on an
accepted branch (an <accepted-prefix>/* branch — default feature/* bugfix/* chore/* —
that carries a .tsugu/context.md), then BEFORE it lands on the default branch, read
that file's POST-HANDOFF CLEANUP block and reset the branch narrative to the mainline
form, so the merge does not pollute the mainline note. If you ever find the default
branch's .tsugu/context.md already carrying a landed branch's narrative (duplicate
"##" section headers), collapse it the same way — but that edits the DEFAULT branch
(public coordination), so get the human's approval before you commit it.
```

It is **appended as a new `## tsugu — post-handoff cleanup` section**; `init` **never rewrites existing
agent-md content** (per the migration contract's "leaves everything else untouched" rule), so an
existing curated `CLAUDE.md` is not clobbered. It carries its own idempotency marker
(`tsugu — post-handoff cleanup`), so `init` re-run / migration skips it when present. Written to
`CLAUDE.md` and, if the repo uses one, `AGENTS.md`; absent any agent md, `init` offers to create a
minimal `CLAUDE.md`. This is the one place 015 has `init` write a human-facing doc — done human-present,
asked once, per the public-coordination boundary; on a push-protected default it rides the `init/*` PR
with `policy.md`.

- **Why grep-skip here, not the block's normalize (Change D).** The agent md does **not** carry
  `merge=union` (that attribute is scoped to `.tsugu/context.md`), so there is no concatenation engine
  to duplicate the pointer — presence-skip suffices, and the pointer text is fixed within a schema. The
  only case grep-skip cannot heal is a *future intentional* change to the pointer wording, which rides a
  **schema bump** (the migration re-authors it), not an `init` re-run — so the non-healing property the
  block's normalize exists to avoid never bites the pointer within a schema.
- **A tsugu operational convention, not a promoted finding.** This is the first tsugu-authored *standing*
  content in the human-facing agent md, which softens the "committed `.tsugu/` is a *sibling* of
  `CLAUDE.md`" store split. It does **not** breach the one-place `knowledge/ ↔ agent-md` rule: the
  pointer is a tsugu **operational convention** (how to finish a handed-off branch), a different content
  class from a promoted `knowledge/` finding, so nothing lives in two stores. The tension is deliberate
  and disclosed, not hidden.
- **Inert in `exclude` mode, like the block.** Under `public-branch-tsugu: exclude` the human strips
  `.tsugu/` before the public PR, so `.tsugu/context.md` never reaches default; the pointer's reset and
  backstop are then moot — the pointer is written in both modes but does real work only in `include`
  mode, exactly as the block.

## Change A — `init` plants the standing block

`init` writes the mainline `context.md` from `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/context.md`;
015 appends the standing block to that template, so every fresh `init` carries it on the default branch
from commit one. The template's opening comment gains a one-line pointer noting the trailing block is a
standing instruction, not part of the narrative skeleton. The stamp becomes `tsugu-schema: 7`.

The block reaches the finishing agent by **riding the branch**: the inherited mainline form (with the
block) is what a `prepare` branch rewrites into its own story, and the accept rename carries that
`context.md` — block included — onto the accepted branch. The copy on default serves as the routed
backstop (Change E).

## Change B — `prepare` preserves the block byte-for-byte

`prepare` step 8 gains one clause: **the trailing POST-HANDOFF CLEANUP block is a standing instruction;
carry it through verbatim — do not delete it, and do not retype it.** The narrative rewrite happens in
the sections *above* the block, so preserving it is the natural case — the clause exists so an agent
reformatting the whole file neither drops it (which deletes it from default on merge) nor retypes it
with drift (which turns it into a conflicting hunk `merge=union` would then duplicate). Byte-identity is
what keeps the single-copy invariant true; when it is lost anyway, `init` re-run **normalization**
(Change D) is the repair path. The block is never *acted on* during `prepare` — a work branch is
pre-finish; the reset is the finishing agent's job after handoff.

## Change C — the named home, converge's role, and the stale-paragraph reconciliation

- **Spine (`context.md` description).** The bullet describing `context.md` gains: the form ends with a
  **standing, byte-immutable POST-HANDOFF CLEANUP block** — the reminder that rides the accept rename to
  the finishing agent (routed by the agent-md pointer, Change E), who resets the branch narrative before
  landing; it is kept byte-for-byte and never deleted, and is the one immutable region in an otherwise
  freely-maintained file.
- **`converge` prepares it; it never runs it.** converge's handoff (accept) renames and stops; 015 adds
  that part of *preparing the handoff context* is that the standing block is present and intact on the
  handed-off branch — the finishing agent's reminder. **converge does not collapse `context.md`.** Near
  B4's `prune` pointer, a companion sentence notes the mainline reset after landing is the standing
  block's job (the finishing agent's), not a converge step.
- **`prune`.** `prune` sweeps **branches**, never `context.md` content; 015 adds one line noting the
  finish-time *content* reset is out of `prune`'s scope and lives in the standing block + agent-md
  pointer.
- **Reconcile the stale `notes-and-packet.md` § "Rewrite on merge-back (`include` mode)".** That
  paragraph claims converge rewrites `context.md` into a ready-to-merge mainline narrative before merge,
  so "there is no state line to clean up afterwards." That is **pre-011** language: 011 made accept a
  rename-that-stops which explicitly does **not** rewrite `context.md` to a mainline narrative (SKILL.md
  `converge`, Accepted). Left as-is it both contradicts 015's problem statement and is wrong about
  current behavior — and 015 already edits this file. 015 **rewrites** the paragraph to the 011 model:
  the branch's own-story `context.md` rides the accept rename unchanged; the human and the finishing
  agent complete the work outside tsugu; the finishing agent resets `context.md` to the mainline form
  **before landing** (prompted by the standing block, routed by the agent-md pointer); converge does not
  rewrite it.

No `prepare` / `converge` / `prune` routine gains an **active detect-and-collapse** step — `init`'s
one-time, human-present pointer-write (Change E) is setup, not a runtime detector. The block + pointer
are the whole mechanism; the docs say where they live and who acts. (An active detector is deferred; the
greppable marker is the only forward-compat.)

## Change E — the agent-md routing pointer

`init` ensures the repo's agent md carries the standing POST-HANDOFF pointer (text above). Rationale:
the in-file block is present on the branch but a tsugu-unaware finishing agent has no reason to open
`.tsugu/context.md`; the agent md is loaded every session by every agent, so it is the reliable channel
that routes the agent to the block at finish-time and at the (often later) landing session. The pointer
also carries the **backstop** clause, giving the on-default backstop a real, permitted actor: an agent
in a human-present session that notices duplicate `##` headers on default's `context.md` collapses it
(committing to default is lawful there — human present, approval available), which the human-absent
`prepare` posture could not do.

Mechanics: human-present, asked once, idempotent by a pointer marker, `CLAUDE.md` (+`AGENTS.md` if
present), minimal-`CLAUDE.md` creation offered when none exists, `init/*` PR on a push-protected default.
It never becomes an *autonomous* write — `init` is interactive and the human approves it, consistent
with the public-coordination boundary.

## Change D — schema 6 → 7 migration (normalize + pointer)

Schema-gated, consistent with 5→6. 6→7 is **structural additions only** — no policy default changes, no
branch refs move:

- **Fresh `init`** stamps `tsugu-schema: 7`, writes the block into the mainline `context.md`, and writes
  the agent-md pointer (Change E).
- **Existing repos** (`tsugu-schema: 6`): the migration **normalizes** the mainline `context.md` block —
  strip every `POST-HANDOFF CLEANUP` HTML-comment block and re-append **one canonical** copy. This heals
  all three states in one rule: absent → adds it; present-and-canonical → no-op (strip + re-append is
  identity); drifted/duplicated (Change B's predicted failure) → replaced by one canonical copy. The strip matches
  **only the HTML-comment shape carrying the reserved marker** (`<!-- POST-HANDOFF CLEANUP … -->`);
  `POST-HANDOFF CLEANUP` is a **reserved string inside `.tsugu/context.md` comments** — a curated
  comment must not reuse it — so normalization cannot remove unrelated curated content. It
  never rewrites or reorders the surrounding curated narrative — only the schema-owned block region is
  touched. This is the **first** migration to *modify* an existing curated `context.md` (5→6 only *added
  a new file*), so the novelty is called out; normalizing a schema-owned region is "restructure the
  schema part," not "overwrite curated content." The migration also adds the agent-md pointer
  (human-approved, idempotent).
- **Work branches are not migrated centrally** — like 5→6, only the default branch's mainline
  `context.md` (and the agent md) are touched; in-flight branches inherit the block on their next
  freshness-rebase or active rewrite. No branch ref moves.
- **Stamp written last**; on a push-protected default the whole migration (context.md normalize + agent
  md pointer + stamp) rides an `init/*` branch + human-approved PR — as 004–013 specify.

## State model (unchanged invariant, restated)

015 sets **no status field**. The block and the agent-md pointer are **narrative** — guidance text the
state model already permits ("narrative is maintained freely; it informs judgment, never
classification"). The finish-time reset is a human/agent judgment prompted by reading the pointer/block,
never a derived-state transition and never a recorded flag. State stays derived from refs / DAG /
containment / recency. *Narrative informs judgment, never classification.*

## Files touched

| File | Change |
| --- | --- |
| `plugins/tsugu/skills/tsugu/templates/context.md` | append the **standing POST-HANDOFF CLEANUP block** after `## Promotion candidates`; opening comment gains a one-line pointer that the trailing block is a standing instruction (Change A) |
| `plugins/tsugu/skills/tsugu/templates/agent-md-pointer.md` (new) | the standing agent-md pointer text `init` writes into a repo's `CLAUDE.md`/`AGENTS.md` (Change E), read by reference from `${CLAUDE_PLUGIN_ROOT}` like the other templates |
| `plugins/tsugu/skills/tsugu/SKILL.md` (`init`) | schema stamp `6 → 7`; note the mainline `context.md` ends with the standing block; **new step: write the agent-md POST-HANDOFF pointer** (human-approved, idempotent, `CLAUDE.md`+`AGENTS.md`, minimal-create offer, `init/*` PR on push-protected default — Change E); update the chain string `1→2→3→4→5→6` → `…→7` (line ~96) |
| `plugins/tsugu/skills/tsugu/SKILL.md` (`prepare` step 8) | rewrite clause: **carry the trailing standing block through verbatim — do not delete it, do not retype it** (Change B), with the byte-identity rationale and the normalize-on-`init`-re-run repair path |
| `plugins/tsugu/skills/tsugu/SKILL.md` (spine + `converge` B4 + `prune`) | spine `context.md` bullet names the standing block (rides the rename; routed by the agent-md pointer; byte-immutable region); `converge` handoff *prepares* the block, never collapses; B4 notes the reset is the finishing agent's; `prune` notes the content reset is out of its (branch-only) scope (Change C); schema `6 → 7`, lineage `… → 013 → 015` |
| `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` | **rewrite the stale § "Rewrite on merge-back (`include` mode)"** to the 011 model (accept renames + stops; finishing agent resets `context.md` before landing, routed by the agent-md pointer; converge does not rewrite); **add** the structure note: the form ends with the byte-immutable POST-HANDOFF CLEANUP block, inert in `exclude` mode (Change C) |
| `plugins/tsugu/skills/tsugu/references/migrations.md` | **new `6 → 7` step** — **normalize** the mainline `context.md` block (strip-all + re-append one canonical: heals absent/canonical/drifted alike, append-only w.r.t. surrounding narrative) and add the agent-md pointer (human-approved, idempotent); stamp last; `init/*`-branch + PR on push-protected default (Change D); update the **four** exact `1→2→3→4→5→6` chain strings → `…→7` (lines ~22, ~298, ~442, ~476) **and** the longhand chain at ~299 (append `, then 6→7`) |
| `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` | update the two schema-coupled lines the 5→6 migration also bumped: the stamp mention `(current: `6`)` → `7` (line ~16) and the chain `1→2→3→4→5→6` → `…→7` (line ~21) |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | bump the literal `tsugu-schema: 6` in the init-skeleton recipe (line ~779) → `7`; add the agent-md pointer write to the init-skeleton recipe (Change E) |
| `plugins/tsugu/skills/tsugu/templates/policy.md` | `tsugu-schema: 6 → 7` |
| `plugins/tsugu/skills/tsugu/README.md` | user-facing: after handoff the human finishes the branch with an agent (outside tsugu); on landing `merge=union` would pollute the mainline `context.md`; the standing block + the always-loaded agent-md pointer remind the finishing agent to reset first — passive, out-of-lifecycle |
| `plugins/tsugu/commands/init.md` | note schema 7 and that `init` now also writes the agent-md pointer; update the chain strings `1→2→3→4→5→6` → `…→7` (lines ~2, ~15) |
| `CLAUDE.md` (dong3 root) | tsugu paragraph: **schema 6 → 7**, lineage `… → 013 → 015`, spec-list adds `015-tsugu-context-cleanup-hint-design.md`, a clause on the standing post-handoff block + the agent-md routing pointer. Rides straight to `main` per the docs convention, enumerated here so the second consumer stays consistent |
| `.claude-plugin/marketplace.json` | bump tsugu `0.8.0 → 0.9.0`; description notes the standing post-handoff cleanup block + agent-md pointer + schema 7. (`plugins/tsugu/.claude-plugin/plugin.json` has **no** `version` field — not touched) |
| `tools/tsugu/test-skill-content.sh` | content anchors: the `POST-HANDOFF CLEANUP` marker in the template, the "keep this block verbatim; never delete it, never retype it" clause, `prepare` step 8's verbatim-preserve clause, the agent-md pointer write (Change E) as an **approved, marker-idempotent, append-only new `## tsugu — post-handoff cleanup` section** (never clobbering existing agent-md content), the reserved-marker constraint, the 6→7 **normalize** (strip-all + re-append, matching only the reserved-marker comment shape) migration step, schema `7`, the chain string `1→2→3→4→5→6→7`; **and update the pre-existing schema-6 stale-stamp guards** (`~207` git-recipes, `~354` README/init illustration) to assert schema `7`, not `6` — those `need_in` guards assert presence, so unbumped reference docs would keep them passing against stale files (the drift 015 fights); refute that the block is a `## section` (it is an HTML comment), that any routine *actively* detects/collapses it (015 is passive), that converge collapses `context.md`, and that the migration rewrites the surrounding narrative (it only normalizes the schema-owned block region) |

**Schema migration:** `tsugu-schema: 6 → 7` — normalize the mainline `context.md` block + add the
agent-md pointer. `public-branch-tsugu`, the 011 handoff model, 012 local-first, and 013
freshness-rebase are unchanged.

## Closes

`#62` (a standing POST-HANDOFF CLEANUP block, planted by `init` at the end of the mainline `context.md`
and carried by the accept rename onto the accepted branch, **plus an always-loaded agent-md pointer that
routes any finishing agent — tsugu-aware or not — to it**, reminds the finishing agent to reset the
branch narrative back to mainline form **before it lands**, so `merge=union` does not pollute the
mainline; the pointer's backstop clause gives a human-present agent a lawful way to collapse an
already-polluted mainline. `prepare` preserves the block byte-for-byte, `init` re-run normalizes drift,
converge prepares it but never collapses, and the stale pre-011 "Rewrite on merge-back" paragraph is
reconciled. Passive by design — no active detector, no human-absent daemon; efficacy is bounded by the
finishing agent honoring the loaded pointer, stated plainly.)
