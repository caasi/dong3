# 005 — Tsugu v1.1: agent-first revisions

## Relationship to 004

This spec **extends** `004-tsugu-skill-design.md`. The lifecycle, the `.tsugu/`
namespace, git-native intake, the convergence packet, the no-skill-orchestration
rule, and the multi-agent reservations all stand unchanged. 005 revises four
surfaces, found by dogfooding:

| Line | Change | What it supersedes in 004 |
| --- | --- | --- |
| A | One command per routine: `/tsugu:init` `/tsugu:prepare` `/tsugu:converge` `/tsugu:settle` | "Packaging" — the single `commands/tsugu.md` router |
| B | `prepare` asks once where to get tasks/context (recorded, no adapter) | Extends `init`'s "Intake sources?" question and the human-bridge interface |
| C | Agent-first publishing: push `.tsugu/` by default; public/default branches MAY contain `.tsugu/` (`public-branch-tsugu: include\|exclude`, default `include`) | Design principle #5, success criterion #7, the settle "no `.tsugu/` in the diff" guarantee, and `init`'s auto-push default |
| D | `init` re-run migrates an older `.tsugu/` to the current schema (`tsugu-schema` version stamp + documented migration steps) | Extends the `init` idempotency rule |

Everything in 004 not named in this table is unchanged.

## Motivation

Three dogfooding observations and one orientation shift:

1. **Command ergonomics.** The single router command surfaces as
   `/tsugu:tsugu init` — the doubled name is noise for a command meant to be run
   daily and wired to schedulers.
2. **Scheduled `prepare` needs a configured source.** The intended usage is:
   run `prepare` once by hand, then wire it to `/schedule`/cron every few hours.
   A scheduled run cannot ask where tasks come from, so the *first interactive*
   run must ask and record the answer.
3. **Cross-machine handoff is the normal case, not the edge case.** The user
   runs `prepare` on a Linux machine and `converge` on a MacBook. That only
   works if `.tsugu/` state is pushed by default — and it reframes the design:
   **the primary goal is agents coordinating through git; humans assist.** 004
   centered the human reviewer (clean PR diffs, `.tsugu/` kept out of public
   branches); 005 flips the default and keeps the human-reviewer posture as an
   opt-out.
4. **Shipped repos drift behind the plugin.** 005 itself changes the
   `policy.md` schema, so already-initialized repos need an upgrade path that
   is not "hand-edit the file."

## A — One command per routine

Replace `commands/tsugu.md` with four thin routers:

```text
plugins/tsugu/commands/
  init.md        →  /tsugu:init
  prepare.md     →  /tsugu:prepare
  converge.md    →  /tsugu:converge
  settle.md      →  /tsugu:settle
```

- Each command file invokes the `tsugu` skill with its routine fixed, and
  passes any extra `$ARGUMENTS` through as free-form context for that routine.
- **No overview command.** The four commands are the whole surface; the skill's
  own trigger description still routes natural-language requests.
- The skill is unchanged structurally: one `SKILL.md`, four routines. Only the
  routing text changes (SKILL.md "Routing" section, README, root `CLAUDE.md`
  "One slash command" → four commands).
- The plugin version in `.claude-plugin/marketplace.json` gets a minor bump.

## B — `prepare` asks where tasks come from (record, no adapter)

004's intake design stands: git is the inbox; external trackers are an optional
human-bridge; Tsugu ships **no adapter**. 005 adds the *configuration moment*
and the *recorded form*.

### The configuration moment

`prepare` distinguishes its **work posture** (external silence — unchanged)
from a one-time **setup question**, which is allowed because the first
`prepare` run is typically interactive:

- On start, after reading `policy.md`: if `## Intake Sources` is still the
  unconfigured default **and** a human can respond (the run is interactive),
  ask once:

  > Git-native intake is the default. Should I also read tasks/context from an
  > external source (a task manager, issue tracker, notes file)? If so, give me
  > the read instruction — a shell command, file path, or MCP tool name.

  Record the answer in `policy.md` under `## Intake Sources` and continue.
- If no human can respond (scheduled/headless run), **never block**: fall back
  to git-native intake, and note in the run note + packet that intake sources
  are unconfigured — `converge` surfaces this as an open question.
- Reconfiguration is not a special mode: the human edits `policy.md`, or runs
  `/tsugu:prepare` interactively and says to change the source.

### The recorded form

Each configured source is a natural-language entry plus **one read
instruction** — no per-system integration logic in the plugin:

```md
## Intake Sources
default: git-native. Each additional source below is read on every prepare run.

- name: my-todos
  read: `cat ~/notes/todo.md`          # shell command, file path, or MCP tool name
  notes: lines starting with "- [ ]" are open tasks; mention repo names to scope.
```

On each run, `prepare` executes the read instruction, interprets the result
with the `notes:` hint, and converts anything new into committed
`.tsugu/intake/<slug>.md` notes (`status: open`,
`## Observed source: human-bridge: <name>`). Downstream is identical to 004 —
the queue read, partition, and routines operate only on git.

**Dedup rule:** derive the slug from a stable identifier in the source (issue
number, todo line hash, title slug). If an intake note with that slug already
exists at the coordination ref — in **any** status — skip it. A `done`/`dropped`
note is the durable record that the item was already processed; re-import would
resurrect finished work.

## C — Agent-first publishing defaults

### Orientation

The end state Tsugu serves is **agents coordinating through git, with humans
assisting** — not agents producing artifacts for human-centric review flows.
`.tsugu/` notes are the agents' shared memory; hiding them from public branches
optimizes for human reviewers at the cost of agent legibility. 005 makes agent
legibility the default and keeps the human-reviewer posture as per-repo opt-out.

### New defaults (global)

1. **`prepare` pushes by default.** The `init` question "may agents
   create/commit/push preparation branches automatically?" defaults to **yes**
   (004 asked neutrally). Pushing is what makes the branch a message: the
   MacBook `converge` and the next scheduled agent both read remote-tracking
   refs. A repo can still answer no; `prepare` then commits locally and stops
   for approval, as in 004.
2. **Public/default branches MAY contain `.tsugu/`.** The 004 guarantee — "the
   public branch's diff vs the default branch introduces no `.tsugu/` changes"
   (design principle #5, success criterion #7) — is demoted from invariant to
   the `exclude` mode of a policy field.

### `public-branch-tsugu: include | exclude`

New `policy.md` field, default **`include`**:

- **`include` (default):** `settle` Accepted still cuts a fresh `public/*`
  branch from the fetched `<remote>/<default>` (the messy→clean history value
  is kept), but applies the work branch's `.tsugu/` paths (`branch.md`,
  `runs/`, `packets/`) **alongside** the accepted code/test/doc/config. The PR
  diff may contain `.tsugu/`; once merged, the default branch accumulates the
  work's evidence as durable shared memory. Trade-off, stated openly: default
  history gets noisier; cold-start and cross-machine agents get richer memory.
- **`exclude` (opt-out):** exactly 004's behavior — apply accepted changes by
  path so the public diff introduces no `.tsugu/` changes. For collaborative
  repos where human reviewers should not see coordination metadata in PRs.

Unchanged in both modes: cut fresh from the fetched default ref, verify
(build/tests) before writing terminal status, PR opening stays human-gated,
intake-note closing, promotion to `context/shared/`, cleanup order.

### Ripple

- `templates/policy.md`: add the field; flip the auto-push wording to the new
  default.
- SKILL.md `settle` + boundary sections, `references/git-recipes.md` (the
  by-path clean-cut recipe becomes the `exclude` arm of a conditional),
  `references/policy-and-intake.md`, `references/notes-and-packet.md` (packet's
  "Suggested public branch" wording).
- 004's design principle #5 and success criterion #7 are superseded as stated
  in the table above.

## D — `init` re-run migrates (`tsugu-schema`)

004's idempotency rule ("repair missing skeleton paths, never overwrite a
curated `policy.md`") cannot express field renames or semantic changes. 005
adds deterministic, version-stamped migration.

### Version stamp

`policy.md` gains a `tsugu-schema: N` field (integer). Schema history:

- **Schema 1** — the 004 layout. Any `.tsugu/` without a `tsugu-schema` field
  is schema 1 by definition.
- **Schema 2** — this spec: `tsugu-schema` itself, `public-branch-tsugu`, and
  the structured `## Intake Sources` entry format.

### `init` re-run decision

1. No `.tsugu/` → fresh init (004 flow), stamped with the current schema.
2. `.tsugu/` present, `tsugu-schema` == current → 004 idempotent repair only.
3. `.tsugu/` present, schema older → apply documented migration steps in order
   (N→N+1 until current), then update the stamp and commit. The commit message
   names the migration range (e.g. `chore(tsugu): migrate .tsugu/ schema 1→2`).

### Migration rules

- Steps live in a new `references/migrations.md`, one section per step:
  *condition → actions → what must not be touched*.
- Migrations **add or restructure schema parts only — never overwrite curated
  content**. Existing intake-source entries, boundary edits, opted-in skills,
  and prefix customizations are preserved verbatim or re-wrapped in the new
  format.
- `init` is human-triggered, so a migration step MAY ask once when a new field
  is behavior-changing (progressive-init rule from 004). Concretely, 1→2 asks
  about `public-branch-tsugu` with default `include`; if the human does not
  decide, write the default and say so in the commit message.
- A migration that cannot be applied mechanically (a curated section
  conflicting with the new structure) **stops and asks** — never force-resolve.
- Push-protected default branches follow the 004 `init` rule: write the
  migration on an `init/*` branch and open a human-approved PR.

### Migration 1→2 (shipped with this spec)

1. Add `tsugu-schema: 2` to `policy.md`.
2. Add `public-branch-tsugu:` (ask once, default `include`).
3. Re-wrap any existing `## Intake Sources` content into the structured entry
   format (B), preserving listed sources; the unconfigured default text is
   replaced by the new default text.
4. Leave the repo's curated auto-push answer untouched (the flipped default
   applies to *fresh* inits only).

## Affected surface

| File | Change |
| --- | --- |
| `commands/tsugu.md` | **removed** |
| `commands/{init,prepare,converge,settle}.md` | **new** thin routers |
| `skills/tsugu/SKILL.md` | routing section; prepare step (intake question + push default); settle (`public-branch-tsugu` arms); boundary section |
| `skills/tsugu/templates/policy.md` | `tsugu-schema`, `public-branch-tsugu`, new Intake Sources format, push default wording |
| `skills/tsugu/references/policy-and-intake.md` | new fields; intake source recorded form + dedup rule |
| `skills/tsugu/references/git-recipes.md` | clean-cut recipe becomes conditional on `public-branch-tsugu` |
| `skills/tsugu/references/notes-and-packet.md` | packet wording for suggested public branch |
| `skills/tsugu/references/migrations.md` | **new** — migration steps, starting with 1→2 |
| `skills/tsugu/README.md` | command surface + new defaults |
| `.claude-plugin/marketplace.json` | tsugu plugin minor version bump |
| root `CLAUDE.md` | tsugu section: four commands, agent-first defaults |

## Success criteria

1. `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`, `/tsugu:settle` each
   run their routine directly; no `/tsugu:tsugu` form remains.
2. A first interactive `prepare` on a repo with unconfigured intake sources
   asks once, records the answer in `policy.md`, and subsequent scheduled runs
   read the source without asking.
3. A scheduled `prepare` with unconfigured sources falls back to git-native,
   never blocks, and surfaces the open question at `converge`.
4. With defaults, `prepare` on machine A pushes branches + `.tsugu/` such that
   `converge` on machine B reconstructs the full state from `git fetch` alone.
5. With `public-branch-tsugu: include`, settled work lands the branch's
   `.tsugu/` evidence on the default branch via the merged PR; with `exclude`,
   the public diff introduces no `.tsugu/` changes (004 behavior).
6. Re-running `/tsugu:init` on a schema-1 repo migrates it to schema 2 without
   losing any curated `policy.md` content; re-running again is a no-op.

## Deferred (unchanged from 004)

Multi-agent arbitration, tracker adapters, external notification, automatic
periodic sync of long-lived branches.
