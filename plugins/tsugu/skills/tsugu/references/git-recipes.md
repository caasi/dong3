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
accepted branch; Tsugu never renames a branch, so slug joins survive everything
that rewrites commits. Examples use full-length CLI options on purpose
(`--remotes`, `--message`, `--set-upstream`, `--force-with-lease`, `--delete`,
`--extended-regexp`, `--prune`, `--ignore-unmatch`); the written recipe should
read the same way the agent runs it.

---

## Read the queue (cold-start safe)

A cold-start agent — no conversation transcript, only a clone — must reconstruct
"what branches exist, why, and what's next" from git + `.tsugu/` alone. There is
**no committed note layer**: the queue *is* the set of work branches. That only
works if reads come from **fresh remote-tracking refs**, not whatever the local
checkout happens to be sitting on.

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
pair a work branch's slug against a decided accepted branch. (A repo that
configures extra work prefixes also surfaces a `## Legacy Work Prefixes` note;
see [Completion tail](#completion-tail) for how the cleanup sweep consults it.)

```bash
# work queue — configured remote + work prefixes (default shown); never raw --remotes
git branch --remotes --format='%(refname:short)' \
  | grep --extended-regexp "^<remote>/(prepare)/"   # pushed mode

# accepted list — same remote, the configured accepted prefixes (for slug pairing)
git branch --remotes --format='%(refname:short)' \
  | grep --extended-regexp "^<remote>/(feature|bugfix|chore|public)/"   # configured accepted prefixes
```

The `public/*` prefix is **retired as a work prefix**; legacy `public/*` branches
now arrive through the **Accepted Prefixes** list (where a migration appends them
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

**6. Partition the queue (single-layer — branches only).** There is **no written
branch state of any kind** — classify each work branch `<work-prefix>/<slug>` by
**two ref-level facts, checked in order** (this is the condensed canonical form of
`SKILL.md`'s partition; the fuller wording lives there):

| Fact | State | Disposition |
| --- | --- | --- |
| tip contained in `<remote>/<default>` (in `exclude` mode: the slug-paired public branch's tip) | **settled** — the work landed | skip; completion-tail / cleanup candidate |
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

# settled? Containment is mode-dependent (`public-branch-tsugu` in policy.md):
#   include (default) → the work branch is what merges
#   exclude           → its slug-paired accepted branch is what lands
case <public-branch-tsugu> in
  exclude) landed_ref="$accepted" ;;   # empty until the accepted branch is cut
  *)       landed_ref="$branch"   ;;
esac

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
full procedure (narrative backstop, retain-the-ref, human-confirmed completion
tail) lives in `references/advanced.md`.

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

## Hand off for merge (include mode — default)

In `include` mode the work branch **is** what merges — its committed WIP knowledge
(the prep commit DAG plus the rewritten `context.md`) lands on the default branch
as durable shared memory. (`knowledge/` lands via the coordination-ref write
above, in **both** modes.) At converge, once the human accepts:

**1. Freshness-rebase onto the fetched default, then verify.** Refresh against
`<remote>/<default>` (see [Freshness](#freshness)) and re-run build/tests so the
branch merges cleanly.

**2. Rewrite `context.md` to the ready-to-merge mainline narrative.** Read the
default branch's current `context.md` from the fetched ref and integrate what this
work changes — the file that lands is **pure desired content**, no state line to
clean up (awaiting-merge lives in the ref namespace, not the file).

**3. Push, then hand off.** Either the human merges the work branch **directly**
(solo flow — its tip then contained in default, settlement immediate), or cut a
**slug-paired accepted branch** named for the human workflow (an accepted-branch
cut):

```bash
git branch <accepted-prefix>/<slug> <work-branch>     # same commits, second name, same slug
git push --set-upstream <remote> <accepted-prefix>/<slug>
# the human opens/approves the PR on the accepted branch
```

The slug is identical, so the partition pairs work branch ↔ accepted branch **by
name** (step 6) and the pending state survives whatever the forge does to commits.

**Update the accepted branch only by `merge`, never rebase.** When post-decision
commits land on the work branch (a work tip with commits the accepted branch
lacks), converge's awaiting-merge section flags the **divergence**; fold them in
by merge or re-decide. Pairs whose accepted tip **shares no history** with the
work branch are flagged as a possible **name collision** to confirm. Both
heuristics — divergence and no-shared-history collision — apply in **`include`
mode only**.

**This section assumes a merge-commit landing** — the work branch's commits reach
default verbatim, so settlement is pure containment. A landing that **rewrites
history** (forced squash, rebase-before-merge, force-push) breaks that derivation;
its full handling lives in `references/advanced.md`.

**Retain the accepted/public branch whenever the work tip won't be contained.**
The case that stays in core is **`exclude` mode**: accepted code lands by path on a
fresh public branch, so the work branch never merges and settlement reads off the
**public branch's** containment instead. That disposition can only be read *while
the slug-paired ref survives*, so for any exclude-mode cut:

- **Disable the forge's auto-delete-head-branch for tsugu accepted/public branches**
  (a common merge setting) so the pairing survives the merge and **preserves the
  disposition evidence** (settled-via-public-tip) until the human's completion tail
  deletes both branches. A recommendation, not a hard gate.
- **Narrative backstop** when the forge deletes the branch anyway: write
  "handed off — may have landed" into the work branch's `context.md`
  **now** (at the converge decision, before the PR opens). The partition still
  classifies the orphaned work branch in-progress, but `prepare`'s **judgment**
  reads that narrative and **leaves the branch for `converge`** rather than
  resuming already-landed work — *narrative informs judgment, never
  classification*.

**Opening/merging the PR is human-gated** — Tsugu prepares and yields; it does not
open the PR or invoke `finishing-a-development-branch` / `review-loop`.

---

## Cut a clean public branch (exclude mode)

For repos that opt out (`public-branch-tsugu: exclude`), the reviewed public
branch must be **cut fresh from the default branch** and carry **only** accepted
code — its diff vs default must introduce **no `.tsugu/` changes** (the guarantee
is "never introduced", not "stripped afterward"). It is named
`<accepted-prefix>/<slug>` (same slug, so pending derives from the same name
pairing), and landing is later confirmed via **this** branch's containment in
default (the by-path application breaks the work branch's own containment).
(`knowledge/` still lands via the coordination-ref write, regardless of mode.)
Because the work branch never merges, **every** exclude-mode landing needs the
*Retain the accepted/public branch* + narrative-backstop handling above, so an
auto-deleted public branch can't make landed work look in-progress.

**1. Cut from the fetched ref** — use the configured `<remote>`, never a hardcoded
`origin`, and never a stale local default:

```bash
git switch --create <accepted-prefix>/<slug> <remote>/<default>
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
git commit --message "tsugu: <accepted-prefix>/<slug> — accepted code"
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
git diff <remote>/<default>..<accepted-prefix>/<slug> -- .tsugu/    # must be empty
```

**4. Verify, then stop.** Build and run tests on the public branch. **Opening the
PR is human-gated** — Tsugu prepares the branch and yields; it does not open the
PR or invoke `finishing-a-development-branch` / `review-loop`.

---

## Completion tail

Once landing is confirmed — by **containment** in merge-commit repos, or, for a
history-rewriting landing, by the human's in-session converge confirmation (see
`references/advanced.md`) — run, in this order:

1. **promote** reusable findings into `.tsugu/knowledge/` (coordination-ref write);
2. **sweep for the item's branches.** Enumerate the work branches as in
   [Read the queue](#read-the-queue-cold-start-safe) step 4. When `policy.md`
   carries a **`## Legacy Work Prefixes`** note (a migration that dropped a work
   prefix records the dropped prefixes there), **also** match branches under those
   legacy prefixes so a settled item's artifact under a dropped prefix stays
   reachable for cleanup. Pruning a prefix from the note once no branches remain
   under it is **optional** — a stale-but-empty note has no sweep effect and may
   remain.
3. **clean up:** `git worktree remove <path>` before
   `git branch --delete --force <branch>` — delete **both** the work branch and
   the accepted branch (the accepted branch too, if the forge didn't already delete
   it), plus any legacy-prefixed artifact the sweep surfaced.

Once both refs are gone the item **leaves the partition entirely** (no refs → not
classified, exactly like any cleaned-up settled item). The durable landed artifact
is **the landed commits on the default branch** — the merge in a normal
include/exclude landing, or the rewritten commit where history was rewritten
(there the work content is present but not containment-linked or slug-keyed). **No
SHA is persisted, and there is no status to flip.** Branch deletion comes last: the
branch is the landing evidence.
**Idempotent** — interrupted before cleanup, the branches remain and a later tidy
re-enters the whole tail.

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

**2. Write `policy.md` (with `tsugu-schema: 4`) + the mainline `context.md` only
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
and the meta paired branch (the bare submodule has no policy of its own). The ordered
two-repo **landing** (at `converge`) lives in `advanced.md` (§ Bare-submodule two-repo landing).
