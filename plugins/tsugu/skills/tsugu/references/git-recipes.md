# git-recipes

These are **documented recipes** — guidance an agent follows with its own
judgment, not scripts to run blindly. Tsugu ships no scripts; every operation
below is plain git (or `gh`) that the agent runs inline, reading the situation
and adapting. Where a recipe says "reconsider" or "stop and ask", that is a
deliberate decision point for the agent's judgment, not a branch to automate
away.

Throughout, `<remote>` and `<default>` are **resolved**, never hardcoded — see
[Read the queue](#read-the-queue-cold-start-safe) for how. Likewise the branch
prefixes written below — the **work** prefixes `prepare/`, `investigate/`,
`review/` (policy's `## Branch Prefixes`) and the **handoff** prefixes `feat/`,
`fix/` (policy's `## Handoff Prefixes`, plus legacy `public/`) — are
**placeholders for the prefixes configured in `policy.md`** (the defaults are
shown); resolve them from the fetched policy when creating or matching branches,
since `init` may have customized them, and discovery filters by the configured
set. The `<slug>` after a prefix is the **join key** — one work item shares one
slug across its work branch, intake note, packet, run notes, and handoff branch;
Tsugu never renames a branch, so slug joins survive everything that rewrites
commits. Examples use full-length CLI options on purpose (`--remotes`,
`--message`, `--set-upstream`, `--force-with-lease`, `--delete`,
`--extended-regexp`, `--prune`); the written recipe should read the same way the
agent runs it.

---

## Read the queue (cold-start safe)

A cold-start agent — no conversation transcript, only a clone — must reconstruct
"what branches exist, why, and what's next" from git + `.tsugu/` alone. That
only works if reads come from **fresh remote-tracking refs**, not whatever the
local checkout happens to be sitting on.

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

**4. Enumerate work branches — and, separately, handoff branches.** Filter to
**`<remote>/`** (the configured remote only — a multi-remote repo must not pull
`upstream/prepare/foo` into an `origin` queue) **plus** the **work** prefixes
**declared in `policy.md`'s `## Branch Prefixes`** (defaults: `prepare`,
`investigate`, `review`) — derive the filter from the fetched policy, don't
hardcode, since `init` may have customized them. **Also enumerate the configured
`## Handoff Prefixes`** (defaults: `feat`, `fix`, plus legacy `public`) into a
**separate handoff list** — these are not queue items but are needed in step 7 to
pair a work branch's slug against a decided handoff branch.

```bash
# work queue — configured remote + work prefixes (defaults shown); never raw --remotes
git branch --remotes --format='%(refname:short)' \
  | grep --extended-regexp "^<remote>/(prepare|investigate|review)/"   # pushed mode

# handoff list — same remote, the configured handoff prefixes (for slug pairing)
git branch --remotes --format='%(refname:short)' \
  | grep --extended-regexp "^<remote>/(feat|fix|public)/"              # configured handoff prefixes
```

The `public/*` prefix is **retired as a work prefix**; legacy `public/*` branches
now arrive through the **Handoff Prefixes** list (where a migration appends them
— see `references/migrations.md`), so they read as decided/landed outputs, never
work candidates.

**No-push mode is local.** When `policy.md` forbids auto-pushing preparation
branches, work stays on **local** branches, so remote-only enumeration would miss
it. In that mode also enumerate local branches — `git branch
--format='%(refname:short)'` — and read their `context.md` from the local ref
(`git show <branch>:.tsugu/context.md`, with the same schema-1 `branch.md`
fallback as step 5). No-push mode is single-machine by nature:
the human and the next run share the same clone, so local discovery carries the
work forward; cross-machine/agent handoff requires the pushed mode.

Each kept line is **already a full remote-qualified ref** (e.g.
`origin/prepare/foo`). Use it **verbatim** in every command below — never
re-prefix `<remote>/`, which would double-prefix into `origin/origin/prepare/foo`.

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

**6. Discover intake notes.** Intake lives on the **coordination ref** (resolve
`<coordination-ref>` from `policy.md`; default = `<default>`). List the tree,
keep only `*.md`, and read each:

```bash
git ls-tree -r --name-only <remote>/<coordination-ref> -- .tsugu/intake/
# for each *.md path:
git show <remote>/<coordination-ref>:<path>
```

Treat a note as a queue item **only if it carries a `status:` field**. This skips
seed files (`.gitkeep`, a `README`) that exist only to make git track the empty
`intake/` directory.

**7. Partition the queue.** There is **no written branch state** — classify each
work branch `<work-prefix>/<slug>` by **two ref-level facts, checked in order**
(this is the condensed canonical form of `SKILL.md`'s C4 table; the fuller
wording lives there):

| Fact | State | Disposition |
| --- | --- | --- |
| tip contained in `<remote>/<default>` (in `exclude` mode: the slug-paired public branch's tip) — or its intake note records a valid `landed:` | **settled** | skip; completion-tail / cleanup candidate |
| a branch with the **same slug** exists under a configured Handoff Prefix | **decided, awaiting merge** | skip as a candidate; shown in converge's awaiting-merge section |
| neither | **in progress** | candidate: read `context.md`, judge from the narrative |

The exact checks:

```bash
# settled? (containment) — include mode: the work branch itself is what merges
git merge-base --is-ancestor <branch-ref> <remote>/<default> && echo settled
# exclude mode: containment rides on the slug-paired public branch instead
git merge-base --is-ancestor <remote>/<handoff-prefix>/<slug> <remote>/<default> && echo settled
# pending? (slug pairing — names, not commits)
slug="${branch##*/}"   # basename: drop the remote and work prefix (one segment each)
git branch --remotes --format='%(refname:short)' \
  | grep --extended-regexp "^<remote>/(feat|fix|public)/${slug}$" && echo pending   # configured handoff prefixes
```

Pairing is by **name, not commits** — ref names are write-once identity, so the
pending state survives anything the forge does to commits (PR-branch rebases,
squashes, force-pushes). Then, as prose rules (from C4):

- **Zero-commit branches are exempt from the whole table** — never classified by
  containment, never by a stale same-slug record. A branch whose tip still equals
  the default tip has no work to misread: with a `claimed` intake note (slug join)
  it is **interrupted work** to resume; without one it is a **request-by-branch**
  (a human pushed `prepare/look-into-X` as the ask) — a new, unclaimed candidate.
  Neither is ever a cleanup target.
- **Slugs are never reused for new work.** A fresh ask whose slug collides with a
  `done`/`dropped` note or a lingering handoff branch is surfaced at **converge**
  as a naming conflict, not classified.
- **Claims are derived from commits** — the `context.md` rewrite commit's author
  and timestamp *are* the claim. A work branch with recent commits is taken; one
  whose last commit is stale is free to pick up. Under one shared git identity
  (one human, two machines) authorship cannot distinguish agents and the rule
  **degrades to pure recency** (acceptable for a courtesy yield, no lock).
- **Zero-commit claim recency** comes from the coordination-ref commit that
  flipped that branch's intake note to `claimed`.
- **A `landed:` SHA is validated on read:** it must resolve and be contained in
  `<remote>/<default>`; otherwise it is **not** silent settlement but a
  **reconciliation case** to surface at converge.

Plus any `intake/` note that is `claimed`/open with no linked work branch =
unbranched work to consider.

---

## Coordination-ref writes

The coordination ref (`coordination-ref` in `policy.md`, **default: the default
branch**) holds the mutable shared inbox (`intake/`) and promoted
`knowledge/`. A commit that touches **only `.tsugu/`** on this ref is
**private-space** — it is coordination memory, not public coordination, and needs
**no approval**.

> **Resolving `coordination-ref`:** the literal value `default` is a **sentinel**
> meaning "the default branch" — resolve it to `<default>` wherever the recipes
> interpolate `<coordination-ref>` (so reads/writes target `<remote>/<default>`,
> never a nonexistent `origin/default`). Any other value is a literal branch name
> (e.g. `tsugu/coord`).

**Write protocol** — do this **from a dedicated checkout/worktree of the
coordination ref**, never from a `prepare/*` worktree (pushing that branch's `HEAD`
to the coordination ref would replay your private code commits onto it — possibly
straight onto the default branch). Commit only the `.tsugu/` change, rebase onto
the latest `<remote>/<coordination-ref>`, then push there **explicitly** (bare
`git pull` / `git push` use the current branch's upstream, which may not be the
configured `<remote>` or ref):

```bash
git -C <coord-worktree> add .tsugu/ && git -C <coord-worktree> commit \
  --message "tsugu: claim intake/<slug> → prepare/<slug>"
git -C <coord-worktree> fetch <remote> && git -C <coord-worktree> rebase <remote>/<coordination-ref>
git -C <coord-worktree> push <remote> HEAD:<coordination-ref>
```

**On conflict, exercise judgment — do not blind-overwrite.** If the rebase
conflicts over a *contended* intake note, re-read that note's **current lifecycle
state** (`open → claimed → done | dropped`) and **reconsider** before reapplying.
Never clobber a `claimed` or `done` another agent just wrote. The ref is
append-mostly, so conflicts are rare; when one happens over a note someone else
moved, that is exactly the signal to re-evaluate, not to force-resolve.

**If the default branch is push-protected**, the agent cannot push `.tsugu/`
coordination data to it. Point `coordination-ref` at a dedicated branch instead.
**Prefer an orphan branch** (e.g. `tsugu/coord`) that holds **only** `intake/`
and `knowledge/` — an orphan has no code history to drift, whereas a plain
`git branch tsugu/coord <remote>/<default>` would inherit a full copy of default
(code, `policy.md`, `templates/`) that goes stale. Keep `policy.md` and
`templates/` on the default branch so the coordination ref stays **discoverable**
(no circularity — you always know where to find policy).

Bootstrap once **in a dedicated worktree** — never switch the user's active
checkout to the orphan (`git switch --orphan` there would blank the working tree,
or fail outright against local modifications). Git can't track empty directories,
so seed each with a real file:

```bash
git worktree add --detach <coord-worktree>          # isolated; doesn't touch the active checkout
git -C <coord-worktree> switch --orphan <coordination-ref>   # the configured ref (e.g. tsugu/coord), not a literal
( cd <coord-worktree>
  mkdir -p .tsugu/intake .tsugu/knowledge
  touch .tsugu/intake/.gitkeep .tsugu/knowledge/.gitkeep )
git -C <coord-worktree> add .tsugu
git -C <coord-worktree> commit --message "tsugu: bootstrap coordination ref (intake/ + knowledge/)"
git -C <coord-worktree> push --set-upstream <remote> <coordination-ref>
```

Thereafter the normal commit → `fetch` + `rebase <remote>/<coordination-ref>` →
`push <remote> HEAD:<coordination-ref>` protocol applies (never a bare `git pull`
— see the warning above). All queue reads resolve against
`<remote>/<coordination-ref>`; always read `policy.md` / `templates/` from
`<remote>/<default>`, never from the coord branch.

---

## Hand off for merge (include mode — default)

In `include` mode the work branch **is** what merges — its `.tsugu/` evidence
(`runs/`, `packets/`, the rewritten `context.md`) lands on the default branch as
durable shared memory. At converge, once the human accepts:

**1. Freshness-rebase onto the fetched default, then verify.** Refresh against
`<remote>/<default>` (see [Freshness](#freshness)) and re-run build/tests so the
branch merges cleanly.

**2. Rewrite `context.md` to the ready-to-merge mainline narrative.** Read the
default branch's current `context.md` from the fetched ref and integrate what this
work changes — the file that lands is **pure desired content**, no state line to
clean up (awaiting-merge lives in the ref namespace, not the file).

**3. Push, then hand off.** Either the human merges the work branch **directly**
(solo flow — its tip then contained in default, settlement immediate), or cut a
**slug-paired handoff branch** named for the human workflow:

```bash
git branch <handoff-prefix>/<slug> <work-branch>     # same commits, second name, same slug
git push --set-upstream <remote> <handoff-prefix>/<slug>
# the human opens/approves the PR on the handoff branch
```

The slug is identical, so the partition pairs work branch ↔ handoff branch **by
name** (step 7) and the pending state survives whatever the forge does to commits.

**Update the handoff branch only by `merge`, never rebase.** When post-decision
commits land on the work branch (a work tip with commits the handoff lacks),
converge's awaiting-merge section flags the **divergence**; fold them in by merge
or re-decide. Pairs whose handoff tip **shares no history** with the work branch
are flagged as a possible **name collision** to confirm. Both heuristics —
divergence and no-shared-history collision — apply in **`include` mode only**.

**Opening/merging the PR is human-gated** — Tsugu prepares and yields; it does not
open the PR or invoke `finishing-a-development-branch` / `review-loop`.

---

## Cut a clean public branch (exclude mode)

For repos that opt out (`public-branch-tsugu: exclude`), the reviewed public
branch must be **cut fresh from the default branch** and carry **only** accepted
code — its diff vs default must introduce **no `.tsugu/` changes** (the guarantee
is "never introduced", not "stripped afterward"). It is named
`<handoff-prefix>/<slug>` (same slug, so pending derives from the same name
pairing), and landing is later confirmed via **this** branch's containment in
default (the by-path application breaks the work branch's own containment).

**1. Cut from the fetched ref** — use the configured `<remote>`, never a hardcoded
`origin`, and never a stale local default:

```bash
git switch --create <handoff-prefix>/<slug> <remote>/<default>
```

**2. Apply only accepted paths via a path-scoped diff.** Generate the diff between
default and the work branch for the accepted code paths, and apply it to the
index:

```bash
# three-dot: diff from the MERGE BASE, so upstream changes to accepted paths are
# not reverted (a two-dot `..` diff would undo default-branch work that landed
# after the work branch diverged). Rebasing the work branch onto <remote>/<default>
# first is the robust alternative.
git diff --binary <remote>/<default>...<work-branch> -- <code paths> | git apply --index --binary
git commit --message "tsugu: <handoff-prefix>/<slug> — accepted code"
```

`git apply --index` only **stages** the patch — it does **not** advance the branch,
so you must commit before any sanity-check or handoff, else the branch carries no
code and the diff check below compares an unchanged branch. `--binary` is required
so binary assets transfer (a plain `git diff` emits only a "Binary files differ"
marker that `git apply` cannot consume). The diff faithfully reproduces **adds,
modifies, deletions, and renames**. Do **not** use `git checkout <work-branch> --
<paths>`: a checkout copies files that exist on the source ref, so it **cannot
reproduce a deletion** — a file the work branch deleted would silently survive on
the public branch.

**3. Never include `.tsugu/`.** Scope `<code paths>` to code/test/doc/config only.
Sanity-check that no Tsugu metadata leaked in:

```bash
git diff <remote>/<default>..<handoff-prefix>/<slug> -- .tsugu/    # must be empty
```

**4. Verify, then stop.** Build and run tests on the public branch. **Opening the
PR is human-gated** — Tsugu prepares the branch and yields; it does not open the
PR or invoke `finishing-a-development-branch` / `review-loop`.

---

## Completion tail

Once landing is confirmed — containment, or the human's converge confirmation
recording `landed: <sha>` where a squash was forced — run, in this order:
1. promote reusable knowledge into `.tsugu/knowledge/` (coordination-ref write);
2. flip the intake note `claimed → done` (+ `landed:` only when not
   containment-derivable; validate the SHA before writing);
3. only then clean up: `git worktree remove <path>` before
   `git branch --delete --force <branch>` — the handoff branch too, if the
   forge didn't already delete it.
Branch deletion comes last: the branch is the landing evidence. Idempotent —
interrupted before the flip, the note stays claimed with its branch intact and
a later tidy re-enters the whole tail.

---

## Freshness

Persistent branches drift when default moves under them. Refresh on resume (and
optionally periodically) by rebasing onto the **fetched** default ref — never a
stale **local** default:

```bash
git fetch <remote>
git rebase <remote>/<default>        # scratch prepare/* investigate/* branches
```

- **Scratch branches** (`prepare/*`, `investigate/*`): rebase freely. If the
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
durable skeleton, idempotently.

**1. Create the `.tsugu/` tree** and seed every directory with a real file (git
can't track empty directories). `knowledge/`'s internal layout is unprescribed —
seed the dir itself, nothing more:

```bash
mkdir -p .tsugu/intake .tsugu/knowledge .tsugu/templates
touch .tsugu/intake/.gitkeep \
      .tsugu/knowledge/.gitkeep \
      .tsugu/templates/.gitkeep
```

**2. Write `policy.md` (with `tsugu-schema: 2`) + templates only if absent.** This
makes re-running `init` an **idempotent repair**: it fills in any missing skeleton
path and is otherwise a no-op. **Never overwrite a curated `policy.md`** — a re-run
must not clobber rules a human already tuned. Re-running on an **older schema**
applies `references/migrations.md` in order (N→N+1 until current) and stamps the
new `tsugu-schema` **last**.

**3. Land the metadata on the default branch.** `policy.md` and `templates/` must
reach `<default>` so policy stays resolvable. If the default branch is
**push-protected**, write them on an `init/*` branch and open a
**human-approved PR**:

```bash
git switch --create init/tsugu-bootstrap <remote>/<default>
git add .tsugu
git commit --message "chore(tsugu): bootstrap .tsugu policy + templates"
git push --set-upstream <remote> init/tsugu-bootstrap
# then open the PR for human approval (human-gated)
```

Do **not** run `prepare` in that repo until the metadata PR is merged — `prepare`
needs `policy.md` / `coordination-ref` resolvable from `<remote>/<default>`.
