# git-recipes

These are **documented recipes** — guidance an agent follows with its own
judgment, not scripts to run blindly. Tsugu ships no scripts; every operation
below is plain git (or `gh`) that the agent runs inline, reading the situation
and adapting. Where a recipe says "reconsider" or "stop and ask", that is a
deliberate decision point for the agent's judgment, not a branch to automate
away.

Throughout, `<remote>` and `<default>` are **resolved**, never hardcoded — see
[Read the queue](#read-the-queue-cold-start-safe) for how. Likewise the branch
prefixes written below — the **work** prefix `prepare/` (policy's
`## Branch Prefixes`) and the **accepted** prefixes `feature/`, `bugfix/`,
`chore/` (policy's `## Accepted Prefixes`, plus legacy `public/`) — are
**placeholders for the prefixes configured in `policy.md`** (the defaults are
shown); resolve them from the fetched policy when creating or matching branches,
since `init` may have customized them, and discovery filters by the configured
set. The `<slug>` after a prefix is the **join key** — one work item shares one
slug across its work branch, its `context.md`, its personal packet, and its
accepted branch; Tsugu never renames the **slug** (handoff renames only the
**prefix**, `prepare/<slug>` → `<accepted-prefix>/<slug>`), so slug joins survive
everything that rewrites commits. Examples use full-length CLI options on purpose
(`--remotes`, `--message`, `--set-upstream`, `--force-with-lease`, `--delete`,
`--extended-regexp`, `--prune`, `--ignore-unmatch`); the written recipe should
read the same way the agent runs it.

---

## Read the queue (cold-start safe)

A cold-start agent — no conversation transcript, only a clone — must reconstruct
"what branches exist, why, and what's next" from git + `.tsugu/` alone. There is
**no committed note layer**: the queue *is* the set of work branches. The queue is
the **union of local *and* remote** work-prefix refs (a slug present in either is
one item, unioned by slug). Reads must come from **fresh refs** — `git fetch
--prune` first for the remote side, and the local refs as they stand — not from
whatever single branch the checkout happens to be sitting on.

**1. Fetch first.** Before reading anything, refresh the remote-tracking refs —
**with `--prune`**, so branches deleted upstream stop appearing in the queue:

```bash
git fetch --prune <remote>
```

Fetching first means every `<remote>/…` ref the rest of this recipe reads is
fresh, never a stale checkout, and multi-remote repos stay unambiguous.

**2. Resolve `<remote>`.** Bootstrap the circular dependency (policy lives behind
the remote, but you need a remote to read policy):

- Begin with `origin`, or the `remote:` field in the **local** checkout's
  `.tsugu/policy.md` if present.
- Fetch, then establish the remote's advertised HEAD **first** so a provisional
  default exists even when `<remote>/HEAD` was unset: `git remote set-head
  <remote> --auto`. Read the fetched policy using that provisional default —
  take the **bare branch name** (`git symbolic-ref --short
  refs/remotes/<remote>/HEAD | sed "s@^<remote>/@@"`, as in step 3; never the full
  `refs/remotes/...` ref). If set-head still yields no HEAD, use the **same
  non-assumptive fallback as step 3** — the checked-out branch's upstream, else
  ask the human to set `default-branch:` — rather than assuming `main` —
  `<default>` is resolved properly in step 3, but the policy read can't wait for
  it: `git show <remote>/<provisional-default>:.tsugu/policy.md`. If it names a
  **different** `remote:` (or a `default-branch:`), adopt those, re-fetch if the
  remote changed, and re-resolve below. The fetched policy wins over the bootstrap
  guess.

**3. Resolve `<default>`.** In priority order:

- An explicit `default-branch:` field in `policy.md`, if set; otherwise
- `<remote>/HEAD` — take the **bare branch name**, not the full ref
  (`refs/remotes/<remote>/HEAD` → strip the `<remote>/` prefix, else later
  `<remote>/<default>` expands to the invalid `origin/refs/remotes/origin/main`):

  ```bash
  git symbolic-ref --short refs/remotes/<remote>/HEAD | sed "s@^<remote>/@@"
  ```

  If that fails because `<remote>/HEAD` is unset, point it at the remote's
  advertised default once, then re-read:

  ```bash
  git remote set-head <remote> --auto
  ```

  If the remote still advertises no HEAD (some self-hosted remotes), do **not**
  blindly assume `main` — fall back to the checked-out branch's upstream
  (`git rev-parse --abbrev-ref --symbolic-full-name @{upstream}`, stripped to the
  branch name) or, failing that, ask the human to set `default-branch:` in policy.

**4. Enumerate work branches — and, separately, accepted branches.** Filter to
**`<remote>/`** (the configured remote only — a multi-remote repo must not pull
`upstream/prepare/foo` into an `origin` queue) **plus** the **work** prefixes
**declared in `policy.md`'s `## Branch Prefixes`** (default: `prepare`) — derive
the filter from the fetched policy, don't hardcode, since `init` may have
customized them. **Also enumerate the configured `## Accepted Prefixes`**
(defaults: `feature`, `bugfix`, `chore`, plus legacy `public`) into a
**separate accepted list** — these are not queue items but are needed in step 6 to
pair a work branch's slug against a decided accepted branch. **The accepted list
spans LOCAL *and* remote refs** — as does the work queue itself (012 unions
local + remote work prefixes; local is the default): at `converge`, the just-renamed
`<accepted-prefix>/<slug>` exists **locally**
before the human pushes it (B3), and it must pair immediately so a same-machine
scheduled `prepare` does not re-pick the still-present remote `prepare/<slug>` in
the handoff-pending window (SKILL.md B1a). (The cross-*machine* pre-push window —
another machine has neither the local accepted branch nor knows of it — is the
deferred multi-agent concurrency case.) (A repo that
configures extra work prefixes also surfaces a `## Legacy Work Prefixes` note;
see [Prune sweep](#prune-sweep) for how the settled cleanup sweep consults it.)

```bash
# work queue — LOCAL + remote, configured work prefixes (default shown); union by slug.
# Discovery reads remote work refs REGARDLESS of the push default — only PUSHING is gated
# (a leftover or opt-in-pushed remote prepare/* must still be seen; it is what takeover/prune target).
git branch --format='%(refname:short)' \
  | grep --extended-regexp "^(prepare)/"            # local-first (default)
git branch --remotes --format='%(refname:short)' \
  | grep --extended-regexp "^<remote>/(prepare)/"   # cross-machine opt-in mode (pushed)
# union the two by slug; a slug present in either is one queue item (classify each ref by its own tip — see step 6)

# accepted list — LOCAL + remote, configured accepted prefixes (for slug pairing).
# Local is required so a just-renamed (not-yet-pushed) accepted branch pairs at converge (B1a).
git branch --format='%(refname:short)' \
  | grep --extended-regexp "^(feature|bugfix|chore|public)/"            # local accepted
git branch --remotes --format='%(refname:short)' \
  | grep --extended-regexp "^<remote>/(feature|bugfix|chore|public)/"   # remote accepted
# union the two by slug; a slug present in either marks the work branch "decided"
```

The `public/*` prefix is **retired as a work prefix**; legacy `public/*` branches
now arrive through the **Accepted Prefixes** list (where a migration appends them
— see `references/migrations.md`), so they read as decided/landed outputs, never
work candidates.

**Local-first (default).** Under the default `push-prepare-branches: no`, work
stays on **local** branches — so the local enumeration above is the queue's primary
source. Read each local item's `context.md` from the local ref
(`git show <branch>:.tsugu/context.md`, with the same schema-1 `branch.md`
fallback as step 5). Local-first is single-machine by nature: the human and the
next run share the same clone, so local discovery carries the work forward.

**Cross-machine opt-in mode (pushed).** When `policy.md` sets
`push-prepare-branches: yes`, the work branch is also **pushed** so a *second
machine's* agent can inherit it (the branch *is* the message, cross-machine). The
remote refs then carry the queue across clones. **Discovery enumerates remote work
refs either way** — only *pushing* is gated by the opt-in; reading always includes
remote work refs, because a leftover or opt-in-pushed remote `prepare/*` must still
be seen (it is exactly what the takeover / `prune` cleanup targets).

Each kept line is **either a local ref** (`prepare/foo`) **or a full remote-qualified
ref** (`origin/prepare/foo`) — the queue is the union of both (local-first by default;
remote read too). Use each **verbatim** in every command below — never re-prefix
`<remote>/` onto a remote-qualified line, which would double-prefix into
`origin/origin/prepare/foo`.

**4b. Detect a human takeover by containment.** A `prepare/<slug>` is **taken
over** when its tip is **contained** by a **branch** that is neither the default
(nor its aliases) nor a work-prefix ref — a human carried the work onto their own
branch (`isaac/fix-thing`), which 011's slug-name pairing alone could not see (#52).
This **generalizes** slug-pairing (a tsugu accepted branch contains the tip too, so
containment catches it); slug-name pairing **stays** as the complementary catch for
the squashed/rewritten take. The check must be **precise** — a loose filter
false-positives, and the cleanup (Change C) is destructive on a wrong hit, so the
fetch-first + branch-scope + alias/work-ref exclusion below are **load-bearing**:

```bash
# `git fetch --prune <remote>` already ran in step 1 — so remote-tracking refs are FRESH
git for-each-ref --contains "<prepare/slug-tip>" refs/heads refs/remotes/<remote> \
     --format='%(refname:short)'    # scope to BRANCHES only — never tags / other namespaces
# Normalize the <remote>/ prefix off remote-tracking names (so origin/isaac/fix == isaac/fix),
# then EXCLUDE — match the NORMALIZED forms (origin/<default> → <default>, origin/HEAD → HEAD):
#   • the default and its aliases:  <default>  AND  HEAD
#       (origin/<default> and origin/HEAD both normalize to these; containment there is
#        the SETTLED row of step 6, not a takeover — excluding only <remote>/HEAD would
#        leave the normalized bare HEAD to slip through and false-positive)
#   • work-prefix refs:  <work-prefix>/*   (local <work-prefix>/* AND normalized origin/<work-prefix>/*
#       both reduce to this; a pushed work branch's OWN ref must NOT count as a foreign takeover ref)
# Anything LEFT ⇒ a NON-WORK, NON-DEFAULT branch carries this work ⇒ taken over (→ Change C).
```

Normalize **before** matching — drop the `<remote>/` prefix off remote-tracking
names exactly as step 3/4 do (never re-prefix; an unnormalized `<remote>/prepare/foo`
or `origin/origin/...` would slip past the work-ref exclusion). The signal is **not
proof of intent** — a branch built *on top of* the prepare tip (a sibling item, a
scratch experiment) also satisfies containment — so a non-empty result is **surfaced
for human confirmation, never auto-deleted** (see [Prune sweep](#prune-sweep) and
Change C). **Git-native, script-free:** this is one native `git for-each-ref
--contains` plus inline `sed`/`grep` filtering — a documented recipe, **not a shipped
script** (tsugu ships no scripts).

**Classification is per-ref (per-tip), not per-slug.** The local + remote
union-by-slug is a **display** merge only; classify **each ref by its own tip**. When
the local `prepare/<slug>` and a stale `<remote>/prepare/<slug>` **diverge**, a stale
remote tip contained by a human branch is *taken over*, but a **newer local**
in-progress tip that nothing contains stays workable — never mark the local
in-progress ref taken-over from the remote tip's containment.

**5. Read branch context without a checkout.** No `git switch`, no dirty tree —
read the committed note straight from the verbatim ref:

```bash
git show <branch-ref>:.tsugu/context.md
```

**Schema-1 compat:** fall back to `.tsugu/branch.md` when `context.md` is absent
(a schema-1 branch). Read the legacy `status:` once and fold it into the
narrative on next touch; treat a legacy `status: settled` as **skip** (a cleanup
candidate), and surface a legacy `status: converged` at **converge** for its
pending decision to be re-anchored.

**6. Partition the queue (single-layer — branches only).** There is **no written
branch state of any kind** — classify each work branch `<work-prefix>/<slug>` by
**two ref-level facts, checked in order** (this is the condensed canonical form of
`SKILL.md`'s partition; the fuller wording lives there):

| Fact | State | Disposition |
| --- | --- | --- |
| tip contained in `<remote>/<default>` | **settled** — the work landed | skip; `prune` cleanup candidate |
| a branch with the **same slug** exists under a configured Accepted Prefix | **decided, awaiting merge** | skip as a candidate; shown in converge's awaiting-merge section |
| neither | **in progress** | candidate: read `context.md`, judge from the narrative |

The exact checks:

```bash
branch=<remote>/<work-prefix>/<slug>   # each enumerated work-branch ref, e.g. origin/prepare/foo
slug="${branch##*/}"                   # basename: drop the remote and work prefix

# Resolve this item's slug-paired accepted ref (if any) from $accepted_refs — the
# configured `## Accepted Prefix` branches enumerated in "Read the queue" step 4
# (not hardcoded feature/bugfix/chore/public). Match the final path component
# *literally* — a slug may contain `.`/`+`, which a regex would mis-glob — and take
# the first match:
accepted=""
while IFS= read -r ref; do
  [ "${ref##*/}" = "$slug" ] && { accepted="$ref"; break; }
done <<<"$accepted_refs"

# settled? Pure containment, MODE-AGNOSTIC (011 accept is a rename, not a by-path cut):
# a work branch is settled when its own tip is contained in default (a direct/solo merge);
# once handed off it is RENAMED to its accepted branch, which the accepted list tracks
# separately — same in include and exclude (no by-path exclude landing any more).
landed_ref="$branch"

# Classify by the FIRST matching table row, in order. Settlement is pure
# containment — no persisted SHA, no note. The finer rules below — zero-commit
# exemption and claim recency — are prose, applied on top of this snippet.
if   [ "$(git rev-parse "$branch")" = "$(git rev-parse <remote>/<default>)" ]
then echo exempt         # zero-commit: tip == default tip — interrupted / request-by-branch, not classified by the table
elif [ -n "$landed_ref" ] && git merge-base --is-ancestor "$landed_ref" <remote>/<default> 2>/dev/null
then echo settled
elif [ -n "$accepted" ]
then echo pending        # a slug-paired accepted branch exists — decided, awaiting merge
else echo in-progress    # neither — a candidate; read context.md and judge from the narrative
fi
```

Pairing is by **name, not commits** — ref names are write-once identity, so the
pending state survives anything the forge does to commits (PR-branch rebases,
squashes, force-pushes). Then, as prose rules:

- **Zero-commit branches are exempt from the whole table** — never classified by
  containment, never by a stale same-slug record. A branch whose tip still equals
  the default tip has no work to misread: it is either **interrupted work** to
  resume or a **request-by-branch** (a human pushed `prepare/look-into-X` as the
  ask) — a new, unworked candidate. Neither is ever a cleanup target. A
  zero-commit branch carries **no recency** until someone commits to it; the first
  commit establishes recency, as for any branch.
- **Slugs are never reused for new work.** A fresh ask whose slug collides with a
  lingering accepted branch is surfaced at **converge** as a naming conflict, not
  classified.
- **Claims are derived from commits** — the `context.md` rewrite commit's author
  and timestamp *are* the claim. A work branch with recent commits is taken; one
  whose last commit is stale is free to pick up. Under one shared git identity
  (one human, two machines) authorship cannot distinguish agents and the rule
  **degrades to pure recency** (acceptable for a courtesy yield, no lock).

A landing that **rewrites history** (forced squash, rebase-before-merge,
force-push) is the one case not derivable from containment — it stays **pending**
on the slug-paired accepted branch and re-surfaces until the human confirms; the
full procedure (narrative backstop, retain-the-ref, human-confirmed prune via the
*possibly-landed* bucket) lives in `references/advanced.md`.

---

## Coordination-ref writes (for `knowledge/` promotion)

The coordination ref (`coordination-ref` in `policy.md`, **default: the default
branch**) holds the promoted `knowledge/` — the team's shared brain, which lands
**regardless of `public-branch-tsugu` mode**. A commit that touches **only
`.tsugu/`** on this ref is **private-space** — it is coordination memory, not
public coordination, and needs **no approval**.

> **Resolving `coordination-ref`:** the literal value `default` is a **sentinel**
> meaning "the default branch" — resolve it to `<default>` wherever the recipes
> interpolate `<coordination-ref>` (so reads/writes target `<remote>/<default>`,
> never a nonexistent `origin/default`). Any other value is a literal branch name
> (e.g. `tsugu/coord`).

**Write protocol** — do this **from a dedicated checkout/worktree of the
coordination ref**, never from a `prepare/*` worktree (pushing that branch's `HEAD`
to the coordination ref would replay your private code commits onto it — possibly
straight onto the default branch). Commit only the `.tsugu/knowledge/` change,
rebase onto the latest `<remote>/<coordination-ref>`, then push there
**explicitly** (bare `git pull` / `git push` use the current branch's upstream,
which may not be the configured `<remote>` or ref):

```bash
git -C <coord-worktree> add .tsugu/knowledge/ && git -C <coord-worktree> commit \
  --message "tsugu: promote knowledge/<topic>"
git -C <coord-worktree> fetch <remote> && git -C <coord-worktree> rebase <remote>/<coordination-ref>
git -C <coord-worktree> push <remote> HEAD:<coordination-ref>
```

**On conflict, exercise judgment — do not blind-overwrite.** If the rebase
conflicts over a `knowledge/` file another agent just promoted, re-read that
file's **current content** and **reconsider** before reapplying — merge the two
findings rather than clobbering one. `knowledge/` is a free-form wiki, so most
edits are additive and conflicts are rare; when one happens over a finding
someone else wrote, that is exactly the signal to integrate, not to force-resolve.

**If the default branch is push-protected**, the agent cannot push `.tsugu/`
coordination data to it. Point `coordination-ref` at a dedicated branch instead.
**Prefer an orphan branch** (e.g. `tsugu/coord`) that holds **only**
`knowledge/` — an orphan has no code history to drift, whereas a plain
`git branch tsugu/coord <remote>/<default>` would inherit a full copy of default
(code, `policy.md`) that goes stale. Keep `policy.md` on the default branch so the
coordination ref stays **discoverable** (no circularity — you always know where to
find policy).

Bootstrap once **in a dedicated worktree** — never switch the user's active
checkout to the orphan (`git switch --orphan` there would blank the working tree,
or fail outright against local modifications). Git can't track empty directories,
so seed `knowledge/` with a real file:

```bash
git worktree add --detach <coord-worktree>          # isolated; doesn't touch the active checkout
git -C <coord-worktree> switch --orphan <coordination-ref>   # the configured ref (e.g. tsugu/coord), not a literal
( cd <coord-worktree>
  mkdir -p .tsugu/knowledge
  touch .tsugu/knowledge/.gitkeep )
git -C <coord-worktree> add .tsugu
git -C <coord-worktree> commit --message "tsugu: bootstrap coordination ref (knowledge/)"
git -C <coord-worktree> push --set-upstream <remote> <coordination-ref>
```

Thereafter the normal commit → `fetch` + `rebase <remote>/<coordination-ref>` →
`push <remote> HEAD:<coordination-ref>` protocol applies (never a bare `git pull`
— see the warning above). All `knowledge/` reads resolve against
`<remote>/<coordination-ref>`; always read `policy.md` from `<remote>/<default>`,
never from the coord branch.

---

## Personal-folder bootstrap

Observation **sources** and **opt-in skills** are *one human's* setup, never
committed (see `references/policy-and-intake.md`). They live in a global,
project-keyed folder that **does not transfer across machines** — each machine
seeds its own:

```text
~/.claude/tsugu/<project-key>/
  config.md        # ## Intake Sources + ## Skills (opt-in), with confirmed-negative markers
  packets/<slug>.md  # the converge decision-view — derived, personal, never pushed
```

**Derive `<project-key>` from the repo's absolute common git dir**, not the
checkout path — tsugu routinely creates worktrees (different paths, same repo and
work item), and keying on the cwd would split one repo's sources/skills/packets
across several folders:

```bash
# --git-common-dir alone returns a bare `.git` in the main checkout but an
# absolute path in a linked worktree — normalize to absolute *before* dashifying,
# else the store still splits across worktrees:
common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"   # e.g. /Users/me/proj/.git
common_dir="${common_dir%/.git}"                                        # strip a trailing /.git → /Users/me/proj
project_key="$(printf '%s' "$common_dir" | tr '/' '-')"                 # dashify path separators
# personal folder: ~/.claude/tsugu/<project-key>/
```

The key is per-machine-per-human; it need not be portable, only **one key per
repo per machine**. **Resolve every `read:` pointer in `config.md` with your own
permissioned tools** — read a file, call an MCP tool, or (only where a command is
genuinely needed) issue it as your own gated tool call. Tsugu never directly
executes the pointer string (the no-force principle). A source signal becomes a
`prepare/<slug>` branch directly — there is no committed note first.

---

## Handoff rename (default converge accept — cold-start safe)

The default accept is a **minimal handoff**: rename `prepare/<slug>` →
`<accepted-prefix>/<slug>` and **stop**. The agent does **not** freshness-rebase,
build/test, rewrite `context.md` to a mainline narrative, push, or open a PR — the
human owns everything after the rename. The rename changes only the **prefix**; the
**slug is preserved** (so the slug-join identity survives). It is **mode-agnostic**:
identical under `public-branch-tsugu: include` and `exclude` (the `.tsugu/`
exploration commits ride along on the renamed branch; the human decides whether to
strip `.tsugu/` when *they* open their public PR).

**Before renaming, resolve `<accepted-prefix>` from `policy.md`'s
`## Accepted Prefixes` and check no `<accepted-prefix>/<slug>` already exists**
(local **or** remote) — a collision means the slug is already in handoff/flight;
surface it rather than clobber.

```bash
# Local prepare/<slug> exists (the machine that prepared it) — a MOVE, not a copy:
git branch -m prepare/<slug> <accepted-prefix>/<slug>

# Cold start — only <remote>/prepare/<slug> exists (a second machine that never had
# the local work branch): create the accepted branch from the remote-tracking ref.
git branch <accepted-prefix>/<slug> <remote>/prepare/<slug>
# the *move* completes when the human deletes the remote prepare/<slug> (B3 below)
```

"Rename" is **load-bearing — a move, not a copy**: `prepare/<slug>` does not survive
beside the accepted branch. Locally that is the literal `git branch -m`; on a
cold-start machine the local `prepare/<slug>` never existed, so the move is "local
create from the remote-tracking ref + the human deletes the remote `prepare/<slug>`"
— the same logical move across the create + remote-delete pair.

**Remote reconcile is a prompt, never a silent op.** After the local rename the
remote still has the stale `prepare/<slug>` and lacks `<accepted-prefix>/<slug>`.
The agent **prints these for the human** (resolving `<remote>`) and does **not** run
them — public/remote coordination stays human-approved:

```bash
git push --set-upstream <remote> <accepted-prefix>/<slug>
git push <remote> --delete prepare/<slug>
```

**Close with a prune pointer:** *"handed off; once you've pushed
`<accepted-prefix>/<slug>` and the work lands, run `/tsugu:prune` to sweep the stale
`prepare/<slug>` and the settled branch."* Nothing is prunable at handoff time (the
human hasn't pushed yet and nothing has landed), so the pointer is for *later* — it
asserts no current count.

**Opening/merging the PR is human-gated** — Tsugu prepares and yields; it does not
open the PR or invoke `finishing-a-development-branch` / `review-loop`. Cleanup of
the renamed branch (and, later, the settled ref) is **deferred to `prune`**.

---

## Maintenance complete path (human-marked only — re-scoped from the old default)

This is the **previously-default** freshness-rebase → verify → ready-to-merge recipe,
now **retained but re-scoped** to the maintenance exception. It is unlocked **only
when the human has explicitly marked the task maintenance-type** (a human-authored
task-source designation recorded verbatim in `context.md`, or live at converge); the
agent **never self-classifies** work as mechanical, and **ambiguous provenance
defaults to handoff**. Default accept stays the handoff rename above.

In order:

**1. Rename first, same as the handoff** — `prepare/<slug>` →
`<accepted-prefix>/<slug>` (move, cold-start safe). The complete path is *handoff +
extra prep on the renamed branch*, not a different branch model.

**2. Bring the accepted branch current and verified.** Refresh against
`<remote>/<default>` (see [Freshness](#freshness)) and re-run build/tests so the
branch is ready to merge.

**3. `context.md` may be rewritten** to a ready-to-merge mainline narrative here
(unlike the default handoff, this branch is heading to merge), at the agent's
discretion.

**4. Surface the same remote-reconcile prompt + the prune pointer** as the handoff
above — the maintenance path still hands the public coordination to the human.

**"Ready-to-merge" means accepted-branch readiness** (rebased + verified), **not** a
clean public diff: the `.tsugu/` commits ride the accepted branch in both modes, so
an `exclude`-mode repo's human still strips `.tsugu/` when they open the public PR.
**Tsugu still never auto-merges** — the maintenance exception relaxes "don't finish
the *work*," never the public-coordination boundary. Cleanup is **deferred to
`prune`**.

A landing that **rewrites history** (forced squash, rebase-before-merge, force-push)
breaks containment-derived settlement; its full handling lives in
`references/advanced.md`.

---

## Prune sweep

`prune` is a queue-wide, **human-present** cleanup pass over unused branches across
**local + remote** refs. It is **read-only until per-item human confirmation**:
running it just to look touches no state. Enumerate refs as in
[Read the queue](#read-the-queue-cold-start-safe) (work prefixes + accepted prefixes,
across **local + remote**), then derive each item's disposition from refs / DAG /
containment / recency — never a status field. When `policy.md` carries a
**`## Legacy Work Prefixes`** note, **also** match branches under those legacy
prefixes so a settled item's artifact under a dropped prefix stays reachable for the
sweep (an empty note has no effect and may remain).

**Delete directly on confirm** (low risk):

- **settled** — tip contained in `<remote>/<default>`
  (`git merge-base --is-ancestor <tip> <remote>/<default>` — the human merged with
  history intact). The main post-handoff target; local + remote.
- **leftover worktree** — a worktree directory whose branch is already deleted.

**Surface + confirm each** (`prune` can't prove the disposition — it asks, never
auto-deletes on a guess):

- **possibly-landed (no containment)** — a surviving `<accepted-prefix>/<slug>` whose
  tip is **not** contained in default and whose landing **cannot be confirmed by
  containment**. This is the recommended-but-history-rewriting case: a squash /
  rebase / `.tsugu/`-strip means the commits that landed aren't this ref's commits,
  so containment stays silent **whether or not** the remote counterpart was deleted —
  including the *retained* accepted ref the rewrite/exclude-strip recommendation tells
  the human to keep (disable auto-delete) precisely so it survives to be confirmed
  here. Surface + confirm each; never auto-delete on a guess.
- **taken-over (redundant prepare)** — a `prepare/<slug>` whose tip a **non-default,
  non-work branch** contains (a human carried the work onto their own branch — see the
  containment-takeover read above). Surface + confirm each, like *possibly-landed*; on
  confirmation delete the redundant `prepare/<slug>` **local and remote, both
  human-confirmed**; never auto-delete. Precedence: classify as *settled* when default
  contains the tip, else *taken-over*.
- **dropped** — the `context.md` narrative says "do not resume" (a hint the present
  human confirms); the backstop for branches `drop` recorded but couldn't delete.
- **orphaned accepted** — a pushed accepted branch with no open PR and no recent
  activity; under handoff this is often the human's **live** work branch, so it is
  never auto-eligible.

**Never deletes unfinished work.** **Stale in-progress** branches (older than
`stale-after`, not landed — including **scope-only** branches) are **surfaced
read-only** and marked *"not deletable here — decide at `converge`."* `prune` only
points; resume / park / drop happens in converge's normal candidate flow.

**Remote deletes:** `prune` runs `git push <remote> --delete <branch>` **after
explicit per-item human confirmation** (the confirmation *is* the approval — `prune`
is the human-present approve-delete gate). This differs from converge's B3, which
only *prints* the command; the unifying rule is **no remote delete without explicit
human approval**. Cleanup order is the established one: `git worktree remove`
**before** `git branch --delete`.

---

## Freshness

Persistent branches drift when default moves under them. Refresh on resume (and
optionally periodically) by rebasing onto the **fetched** default ref — never a
stale **local** default:

```bash
git fetch <remote>
git rebase <remote>/<default>        # scratch prepare/* (and any configured work prefixes)
```

- **Scratch branches** (`prepare/*`, and any extra work prefixes configured): rebase freely. If the
  branch was already pushed, the rebase rewrites it, so update the remote with
  lease protection — **never** a plain `--force`:

  ```bash
  git push --force-with-lease
  ```

- **History-bearing / long-lived branches**: **prefer merge** to preserve history
  (`git merge <remote>/<default>`), honoring the repo's history-protection
  convention.

- **Non-trivial conflict → stop and ask the human.** Do not auto-resolve a
  conflict that needs a judgment call about intent.

## Cleanup order

Always remove the worktree **before** deleting the branch. A branch still checked
out by a worktree cannot be safely deleted.

```bash
git worktree remove <path>
git branch --delete --force <branch>
```

Never run `git branch --delete --force` on a branch that a worktree still has
checked out.

---

## init skeleton

`init` runs when a repo has no `.tsugu/`. It writes the fixed metadata and the
durable skeleton, idempotently. Committed `.tsugu/` collapses to **`policy.md` +
`context.md` + `knowledge/`** — no `intake/`, no `runs/`, no `packets/`, no
repo-seeded `templates/`.

**1. Create the `.tsugu/` skeleton.** Only `knowledge/` is a tracked directory,
and git can't track an empty one, so seed it with a real file. `knowledge/`'s
internal layout is unprescribed — seed the dir itself, nothing more:

```bash
mkdir -p .tsugu/knowledge
touch .tsugu/knowledge/.gitkeep
```

Templates are **not** seeded into the repo — `init`/`prepare`/`converge` read
them from `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/` instead.

**2. Write `policy.md` (with `tsugu-schema: 5`) + the mainline `context.md` only
if absent**, rendered from the skill's templates. This makes re-running `init` an
**idempotent repair**: it fills in any missing skeleton path and is otherwise a
no-op. **Never overwrite a curated `policy.md`** — a re-run must not clobber rules
a human already tuned. Observation **sources** and **opt-in skills** are personal
config (the global folder, not `policy.md`) — `init` does not write them into the
repo. Re-running on an **older schema** applies `references/migrations.md` in
order (N→N+1 until current) and stamps the new `tsugu-schema` **last**.

**3. Land the metadata on the default branch.** `policy.md` and the mainline
`context.md` must reach `<default>` so policy stays resolvable. If the default
branch is **push-protected**, write them on an `init/*` branch and open a
**human-approved PR**:

```bash
git switch --create init/tsugu-bootstrap <remote>/<default>
git add .tsugu
git commit --message "chore(tsugu): bootstrap .tsugu policy + context"
git push --set-upstream <remote> init/tsugu-bootstrap
# then open the PR for human approval (human-gated)
```

Do **not** run `prepare` in that repo until the metadata PR is merged — `prepare`
needs `policy.md` / `coordination-ref` resolvable from `<remote>/<default>`.

## Submodule recursion

(Omni-repo.) `prepare` recurses after working the meta-repo's own queue. The branch always lands
at the lowest repo that owns the **code**; `.tsugu/` knowledge lands at the lowest
repo that **has** a `.tsugu/`.

**Descend only if this repo's own `## Recursion` permits** (default: only when
relevant) — that toggle governs whether this repo descends into a submodule subtree
**at all**, independent of any submodule's gate outcome. Once descending, the
per-submodule gate (step 2) decides recurse-vs-meta-drive.

**1 — Enumerate (initialized trees only).**

```bash
git submodule status   # a leading "-" = uninitialized: no working tree to test
```

An uninitialized submodule (leading `-`) is either initialized
(`git submodule update --init <path>`) before gating, or **skipped with a surfaced
note** — never silently treated as bare (it may carry `.tsugu/` once checked out).

**2 — Gate on a readable `.tsugu/policy.md` (three outcomes, not two).**

```bash
if   test -r "<sub>/.tsugu/policy.md"; then echo HAS      # managed: recurse-and-run (step 3)
elif test -e "<sub>/.tsugu";          then echo INVALID   # .tsugu/ exists but no readable policy.md
else                                       echo BARE      # genuinely bare: meta-drive (step 4)
fi
```

`INVALID` (a `.tsugu/` directory without a readable `policy.md`) is **surfaced, not
driven** — never silently collapsed into `BARE`.

**3 — HAS `.tsugu/` → recurse-and-run.** Run the full `prepare` routine inside the
submodule, treating it as its own repo. It already has its own project-key (keyed on
its own git dir) → its own personal-config intake.

```bash
git -C <submodule-path> fetch --prune <remote>
# then run prepare's steps with every git command prefixed `git -C <submodule-path>`
# (optionally dispatch a built-in Task subagent per submodule)
```

The submodule runs at its **own** schema (do **not** force-migrate a schema-3
submodule). Its own `policy.md`, `context.md` scope, default branch, and push rules
apply; its own queue read **continues an existing `prepare/<slug>` rather than
duplicating** it, and its `context.md` scope boundaries are respected emergently
(no central router). Reads its sources only if that submodule's personal config was bootstrapped
on **this** machine (interactive-only); else it degrades to git-native and surfaces
"personal config unconfigured" at the submodule's next same-machine `converge`.

**4 — no `.tsugu/` → meta-drives with a paired meta branch.** The branch still lands
in the submodule (easy handoff), but **meta** `policy.md` governs every tsugu rule
for it. **Resolve the base and rules BEFORE creating any branch** (ask-don't-guess —
never branch on a guess):

```bash
git -C <sub> fetch --prune <remote>
ref=$(git -C <sub> symbolic-ref --quiet "refs/remotes/<remote>/HEAD")   # e.g. refs/remotes/origin/develop
default=${ref#refs/remotes/<remote>/}                                   # prefix-strip — keeps slashes (release/v2)
# Ambiguous (no .../HEAD, multiple remotes) OR a rule not covered by meta policy?
#   interactive -> ASK the human
#   headless    -> DO NOT branch: leave the item unbranched, surface it at next converge
# Only once base + rules are resolved. <work-prefix> = the META-policy work prefix
#  (default prepare/*) — the bare submodule has no policy of its own:
git -C <sub> switch -c <work-prefix>/<slug> "<remote>/$default"
# … reproduce / test / patch / commit inside the submodule …
```

**No clear owner.** When a meta-source ticket maps to no obvious submodule, do **not**
guess one: if it's genuinely meta-level work open a meta `prepare/<slug>`; otherwise
**defer to `converge`** (create no branch). At `converge` the human assigns an owner
and it reclassifies — recurse-and-run target (HAS `.tsugu/`), a bare pair, or meta
work. A deferred item carries no committed state; it resurfaces by re-reading
external intake (the schema-3 weakened-dedup tradeoff), no ledger.

Then carry the findings on a **paired meta branch** (same slug):

```bash
# in the meta-repo working tree (<work-prefix> = the meta-policy work prefix, default prepare/*)
git switch -c <work-prefix>/<slug>
git add <sub>                       # stage the gitlink bump to the prepared submodule tip
# write .tsugu/context.md narrating the work + the submodule branch name + SHA
git add .tsugu/context.md
git commit -m "prepare(<slug>): submodule work in <sub> @ <sha> (paired)"
```

Handoff: checking out the meta `prepare/<slug>` + `git submodule update` lands the
submodule at the prepared commit as **detached HEAD** at the recorded SHA (not on
`prepare/<slug>` — the human runs `git -C <sub> checkout prepare/<slug>` to resume).

**5 — Depth.** Traverse **depth-first**. Arbitrary depth holds for **managed** chains
(each level has its own `.tsugu/`). A **bare** level is driven **only one level deep** — a direct bare child
may be meta-driven, but anything nested beneath a bare child is **surfaced, not
driven** (it would become an N-repo gitlink-chain transaction). Note it and leave it
for the human to restructure (e.g. `init` an intervening level).

Push where policy permits: a **recurse-and-run** submodule uses its **own** `## Push`;
a **bare** pair is governed by the **meta** `## Push` for **both** the submodule branch
and the meta paired branch (the bare submodule has no policy of its own). The cross-repo
**landing** (the human's, at `converge`) is covered in `advanced.md` (§ Bare-submodule handoff).
