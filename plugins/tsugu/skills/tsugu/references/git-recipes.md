# git-recipes

These are **documented recipes** — guidance an agent follows with its own
judgment, not scripts to run blindly. Tsugu ships no scripts; every operation
below is plain git (or `gh`) that the agent runs inline, reading the situation
and adapting. Where a recipe says "reconsider" or "stop and ask", that is a
deliberate decision point for the agent's judgment, not a branch to automate
away.

Throughout, `<remote>` and `<default>` are **resolved**, never hardcoded — see
[Read the queue](#read-the-queue-cold-start-safe) for how. Likewise the branch
prefixes written below — `prepare/`, `investigate/`, `review/`, `public/` — are
**placeholders for the prefixes configured in `policy.md`** (the defaults are
shown); resolve them from the fetched policy when creating or matching branches,
since `init` may have customized them, and discovery filters by the configured
set. Examples use full-length CLI options on purpose (`--remotes`, `--message`,
`--set-upstream`, `--force-with-lease`, `--delete`); the written recipe should
read the same way the agent runs it.

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

**4. Enumerate work branches.** Filter to **`<remote>/`** (the configured remote
only — a multi-remote repo must not pull `upstream/prepare/foo` into an
`origin` queue) **plus** the **work** prefixes **declared in `policy.md`'s Branch
Prefixes** (defaults: `prepare`, `investigate`, `review`) — derive the filter from
the fetched policy, don't hardcode, since `init` may have customized them. Do
**not** include `public/*`: that is a `settle` output, not a queue item.

```bash
# scope to the configured remote + work prefixes (defaults shown); never raw --remotes
git branch --remotes --format='%(refname:short)' \
  | grep -E "^<remote>/(prepare|investigate|review)/"      # pushed mode
```

**No-push mode is local.** When `policy.md` forbids auto-pushing preparation
branches, work stays on **local** branches, so remote-only enumeration would miss
it. In that mode also enumerate local branches — `git branch
--format='%(refname:short)'` — and read their `branch.md` from the local ref
(`git show <branch>:.tsugu/branch.md`). No-push mode is single-machine by nature:
the human and the next run share the same clone, so local discovery carries the
work forward; cross-machine/agent handoff requires the pushed mode.

Each kept line is **already a full remote-qualified ref** (e.g.
`origin/prepare/foo`). Use it **verbatim** in every command below — never
re-prefix `<remote>/`, which would double-prefix into `origin/origin/prepare/foo`.

**5. Read branch context without a checkout.** No `git switch`, no dirty tree —
read the committed note straight from the verbatim ref:

```bash
git show <branch-ref>:.tsugu/branch.md
```

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

**7. Partition the queue.** Combine `branch.md` `status` × `claimed-by` per the
`prepare` partition table in `SKILL.md`:

| status | claimed-by | disposition |
| --- | --- | --- |
| `open` | empty | **pick up** |
| `open` | non-empty, **recent** `claimed-at` | **yield** (taken) |
| `open` | non-empty, **stale** `claimed-at` | **pick up** — reclaim (re-set `claimed-by`/`claimed-at`) |
| `paused` | — | **resume candidate** (rebase onto default first — see Freshness) |
| `converged` | — | skip (awaiting human) |
| `settled` | — | skip (done) |

Plus any `intake/` note with `status: open` and no linked branch = unbranched
work to consider.

---

## Coordination-ref writes

The coordination ref (`coordination-ref` in `policy.md`, **default: the default
branch**) holds the mutable shared inbox (`intake/`) and promoted
`context/shared/`. A commit that touches **only `.tsugu/`** on this ref is
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
and `context/shared/` — an orphan has no code history to drift, whereas a plain
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
  mkdir -p .tsugu/intake .tsugu/context/shared
  touch .tsugu/intake/.gitkeep .tsugu/context/shared/.gitkeep )
git -C <coord-worktree> add .tsugu
git -C <coord-worktree> commit --message "tsugu: bootstrap coordination ref (intake/ + context/shared/)"
git -C <coord-worktree> push --set-upstream <remote> <coordination-ref>
```

Thereafter the normal commit → `fetch` + `rebase <remote>/<coordination-ref>` →
`push <remote> HEAD:<coordination-ref>` protocol applies (never a bare `git pull`
— see the warning above). All queue reads resolve against
`<remote>/<coordination-ref>`; always read `policy.md` / `templates/` from
`<remote>/<default>`, never from the coord branch.

---

## Cut a clean public branch

The reviewed public branch must be **cut fresh from the default branch** and carry
**only** accepted code — its diff vs default must introduce **no `.tsugu/`
changes** (the guarantee is "never introduced", not "stripped afterward").

**1. Cut from the fetched ref** — use the configured `<remote>`, never a hardcoded
`origin`, and never a stale local default:

```bash
git switch --create public/<x> <remote>/<default>
```

**2. Apply only accepted paths via a path-scoped diff.** Generate the diff between
default and the prepare branch for the accepted code paths, and apply it to the
index:

```bash
# three-dot: diff from the MERGE BASE, so upstream changes to accepted paths are
# not reverted (a two-dot `..` diff would undo default-branch work that landed
# after prepare/<x> diverged). Rebasing prepare/<x> onto <remote>/<default> first
# is the robust alternative.
git diff --binary <remote>/<default>...prepare/<x> -- <code paths> | git apply --index --binary
git commit --message "tsugu: public/<x> — accepted code"
```

`git apply --index` only **stages** the patch — it does **not** advance the branch,
so you must commit before any sanity-check or handoff (above), else `public/<x>`
carries no code and the diff check below compares an unchanged branch. `--binary`
is required so binary assets transfer (a plain `git diff` emits only a "Binary files
differ" marker that `git apply` cannot consume). The diff faithfully reproduces
**adds, modifies, deletions, and renames**. Do **not** use `git checkout
prepare/<x> -- <paths>`: a checkout copies files that exist on the source ref, so it
**cannot reproduce a deletion** — a file the prepare branch deleted would silently
survive on the public branch.

**3. Never include `.tsugu/`.** Scope `<code paths>` to code/test/doc/config only.
Sanity-check that no Tsugu metadata leaked in:

```bash
git diff <remote>/<default>..public/<x> -- .tsugu/    # must be empty
```

**4. Verify, then stop.** Build and run tests on `public/<x>`. **Opening the PR is
human-gated** — Tsugu prepares the branch and yields; it does not open the PR or
invoke `finishing-a-development-branch` / `review-loop`.

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
can't track empty directories):

```bash
mkdir -p .tsugu/intake \
         .tsugu/context/shared .tsugu/context/dormant .tsugu/context/archived \
         .tsugu/templates
touch .tsugu/intake/.gitkeep \
      .tsugu/context/shared/.gitkeep \
      .tsugu/context/dormant/.gitkeep \
      .tsugu/context/archived/.gitkeep \
      .tsugu/templates/.gitkeep
```

**2. Write `policy.md` + templates only if absent.** This makes re-running `init`
an **idempotent repair**: it fills in any missing skeleton path and is otherwise a
no-op. **Never overwrite a curated `policy.md`** — a re-run must not clobber rules
a human already tuned.

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
