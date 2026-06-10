# policy-and-intake

`.tsugu/policy.md` records the per-repo rules a cold-start agent reads before any
unattended preparation. It lives on the **default branch always** (so the
coordination ref it points to stays discoverable — no circularity). This document
gives the one-line semantics of every field, then explains the intake
human-bridge.

## `policy.md` fields

### Private / Public boundary

The whole point of the file: where the agent may act freely vs where it must ask.

- **`## Private Git Space (agent may do freely)`** — actions the agent performs
  without approval: create/commit/push `prepare·investigate·review` branches,
  worktrees, write `.tsugu/*`, run tests, try reversible patches, dispatch its own
  built-in review subagents. All of this is git-local and reversible.
- **`## Public Coordination (ask first)`** — actions requiring human approval:
  open MR/PR, tracker comment / status change, assign reviewers, Slack, public
  commitments, moving findings into human-facing docs, irreversible cleanup.

The boundary in one line:

```text
Git branch / pushed branch / .tsugu notes  →  agent may do freely
MR / PR / tracker / Slack / reviewer assignment  →  human approval required
```

### `## Branch Prefixes`

The branch namespaces Tsugu uses. Default `prepare/*  investigate/*  review/*
public/*`. The first three are **work** prefixes (queue items); `public/*` is a
**settle output** (cut fresh, never enumerated into the queue).

### `remote:`

The authoritative remote for `git fetch` and branch enumeration. Default
`origin`. Stated explicitly for **multi-remote safety** — so `<remote>/…` refs are
unambiguous regardless of which remote the local checkout tracks.

### `default-branch:`

Optional override for `<default>`. If blank, `<default>` is resolved from
`<remote>/HEAD` (`git symbolic-ref refs/remotes/<remote>/HEAD`). Set it only when
`<remote>/HEAD` is unreliable or the repo's default is non-obvious.

### `coordination-ref:`

The ref where the mutable inbox (`intake/`) and promoted `context/shared/` are
written. **Default: `default`** (the repo's default branch). Point it at a
dedicated branch (e.g. `tsugu/coord`) when the default branch is **push-protected**
— the agent needs a writable home for `.tsugu/` coordination data, but in a
human-collaborative repo the task **code** only ever reaches default through a
human-merged PR, not an agent push. That right varies per environment, which is
why it is a per-repo policy field.

### `## Intake Sources`

The human-bridge sources (if any) the repo observes. **Default: none** —
git-native only. List sources (e.g. `gh issues`, CI) here only if this repo needs
to bridge a human-world signal into git. See the human-bridge section below.

### `## Skill use`

States the shipped invariant: **Tsugu invokes no user-installed skill by
default** — it uses native git plus its own built-in capabilities (Task subagents,
Codex-as-a-tool, Claude's own reasoning). Humans trigger workflow skills
(planning, debugging, review-loop, …) by keyword. This text reflects the shipped
behavior and is the same in every repo.

### `## Skills Tsugu may use (this repo, opt-in)`

The **per-repo opt-in** — and the *only* place a skill name may appear. **Default:
none.** A repo owner MAY list specific user-installed skills (e.g.
`systematic-debugging`) that Tsugu may use during **human-absent `prepare`** in
**this repo**. This is repo-local config: the shipped `SKILL.md` never names a
skill, so the plugin stays universal while a repo extends it locally.

### `## Recursion`

Whether to recurse into submodules / child repos. Default: **only when relevant to
the current goal / intake / branch.** Keeps an omni-repo traversal scoped instead
of descending into every nested repo unconditionally.

## Intake: the optional human-bridge

**Git is the inbox.** A pure-Tsugu workflow communicates through git alone: an
agent fetches, sees new/changed branches and newly committed `.tsugu/intake/`
notes, and that *is* the work queue. No external tracker is required, and the
default loop runs with zero external integrations.

Tracker observation — Jira, GitHub/GitLab issues, CI, CVE feeds, Slack — is
**OPTIONAL** and is **not the spine.** It is a thin shim whose only job is to
convert a **human-world signal** into the git-native substrate: a committed
`.tsugu/intake/<slug>.md` note (and optionally a seed branch). The note records
where the signal came from in its `## Observed source` line (e.g.
`human-bridge: gh issue #128`).

Once that conversion happens, **every downstream step is identical** — the queue
read, the partition, the `prepare`/`converge`/`settle` routines all operate on the
committed note and branches, never on the tracker. A pure-Tsugu user **skips this
layer entirely**: they (or the agent) author intake notes directly, and git is the
only inbox. Tsugu ships no adapter for any tracker; `## Intake Sources` is an
interface stub, not built integration.
