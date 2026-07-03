# 013 — Tsugu prepare rebases in-progress `prepare/*` onto default: kill drift before it rots (schema 5 → 6)

## Relationship to 004 / 005 / 006 / 007 / 008 / 011 / 012

This spec **extends** the lineage `004 → 005 → 006 → 007 → 008 → 011 → 012`. Everything those
specs establish stands: git-native intake, derived state (refs + DAG + containment +
recency; no status fields), the no-skill-orchestration rule, the no-force principle, the
storage split (committed `.tsugu/` vs personal global folder), the work-prefix /
accepted-prefix partition, 011's handoff-oriented converge (accept = mode-agnostic rename;
maintenance exception; curation; `prune`), 012's **local-first `prepare`** (`push-prepare-branches`
defaults `no`; work stays local; cross-machine push is the opt-in) and its containment-primary
**taken-over** derivation, and the never-auto-merge / public-coordination-needs-approval boundary.

013 fixes one thing 012 left untouched: **an in-progress `prepare/*` branch never refreshes
against the default branch, so it drifts.** The default advances for days while attention is
absent; the prepare branch sits behind. Two costs surface later:

- **A freshness-rebase forced at converge.** 011's accept is meant to be a clean rename+stop.
  When the branch is stale, the human has to hand-rebase it onto the current default tip first
  — and that rebase can hit a `.tsugu/context.md` conflict (the default branch reset its own
  mainline `context.md` after an unrelated merge). Accept should never require a **manual** human
  freshness-rebase (013 makes the refresh automatic — routine at `prepare`, offered at `converge`).
  **This is the primary, load-bearing cost** — it is what "always ready to hand off against current
  default" means.
- **Merge-level conflicts that rot until someone reads the branch.** When default advances under a
  reference-code branch, the eventual merge conflict is invisible until a human opens the branch at
  converge (or a scheduled run touches it). Rebasing onto the current default **surfaces that conflict
  at rebase time — loud, dated, in front of the next agent** — instead of ambushing the human
  mid-handoff.

**What rebasing does *not* fix — stated honestly.** A `file:line` anchor in `context.md` points at a
source location the branch itself never edited. When default *refactors* that source (the exp-6050
windowing refactor), the rebase touches neither the branch's source nor its `context.md`, so it
**replays clean with no conflict and the anchor rots exactly as silently as before** — and now points
wrong against the branch's *own* post-rebase tree. Anchor validity heals only on the **next active
`context.md` rewrite** (which re-pins from the new base — that rewrite *is* the claim, per Change C),
not on the rebase itself. So 013 does **not** claim to keep anchors valid; it claims **mergeability +
early merge-conflict surfacing**. (By the no-status-field rule there is no recorded rebase marker; a
committer-date much later than a commit's author-date is a *heuristic hint* — not proof — that it was
rebased, since a rebase rewrites committer-date but preserves author-date per Change C.)

The mechanism already **half-exists**: `references/git-recipes.md` `## Freshness` documents a
manual `git fetch` → `git rebase <remote>/<default>` (+ `--force-with-lease` if pushed) as a
*resume-time* action. 013 **promotes it into the `prepare` routine** — an automatic, flag-gated
post-fetch step over the in-progress work branches — and gives it the **human-absent** conflict
posture the manual recipe lacks (its current rule, "stop and ask the human," assumes a human is
present, which a scheduled `prepare` is not).

Captured from field use on the `omni` meta-repo (`prepare/cde-148-user-available-pages` needed a
hand-rebase before handoff and hit a `context.md` conflict; `prepare/exp-6050-custom-greeting`
carried a checkpoint literally titled *"drifted refs fixed"*). Filed as **issue #57**.

**This is a schema change.** A new default that changes behavior on upgrade is schema-gated
(the 012 precedent for `push-prepare-branches`), so 013 bumps **`tsugu-schema: 5 → 6`** and ships
a 5→6 migration that pins the **pre-013** behavior (no rebase) into existing repos. Fresh `init`
stamps 6 and defaults the new flag **`yes`**.

| Line | Change | What it supersedes | Issue |
| --- | --- | --- | --- |
| A | **`prepare` freshness-rebases in-progress work branches.** After fetch, for each **in-progress** `<work-prefix>/*` branch (settled / taken-over / zero-commit excluded), rebase it onto the fetched default tip. Gated by a new `## Freshness` policy flag `rebase-prepare-onto-default` (fresh-init default **`yes`**) | The `## Freshness` recipe existed only as a **manual resume-time** action, never part of the routine; drift accumulated unattended | #57 |
| B | **Deterministic human-absent conflict posture.** `.tsugu/context.md` *content* conflicts auto-resolve by **`merge=union`** (a committed `.tsugu/.gitattributes`; the merge backend is forced via `git rebase --merge`) — lossless, never stops the rebase. **Any real conflict** (a source file, or a structural modify/delete of context.md) → **`git rebase --abort`, skip working the branch this run, surface for `converge`** — no forced resolution, no committed status write | The manual `## Freshness` rule "**Non-trivial conflict → stop and ask the human**" assumes a present human; a scheduled `prepare` has none | #57 |
| C | **Recency-as-claim preserved via author-date.** The claim / staleness read keys off **author-date**, which rebase preserves (rebase rewrites only committer-date). A freshness-rebase therefore **never spuriously bumps** a branch's claim — a stale branch stays stale-looking after refresh | The recency prose said "the commit's author and timestamp *are* the claim" but never pinned author- vs committer-date; a committer-date read would let a blanket rebase fake fresh claims on every branch | #57 |
| D | **Force-with-lease is the delivery mechanism, not a hazard.** Where the branch is pushed (`push-prepare-branches: yes`), push the rebased branch with a **pinned** `--force-with-lease=<branch>:<sha-captured-at-fetch>` (never bare — a bare lease still checks, but its expected value is the *current* remote-tracking ref, so an intervening `git fetch` silently advances that baseline and the check passes even against a concurrent push the local branch never integrated) — a second machine *fetches and inherits the freshened branch*, which is the point. The lease protects a **concurrent claim** (another machine pushed newer work → lease mismatch → skip that branch, respecting its recency). Local-first repos rebase the local branch and push nothing. Safe because the rebase set is **in-progress only** — no accepted / human branch contains it (those are excluded), so there is no branch-as-message to disturb on one machine | 011/012 filed "history rewrite + force-push vs branch-as-message" under the deferred multi-agent case; 013 discharges it for the single-machine reality and reframes cross-machine push as desirable | #57 |
| E | **Converge surfaces behind-default and offers the refresh as its first per-branch decision.** The morning status view shows each candidate's **"behind default by N"** (derived, like the stale marker); when behind, `converge`'s **first** question on that branch — before accept/park/drop — is *"refresh onto current default first? [Y/n]"* (default **Y**; not asked when already current). Human-present: a conflict is resolved or parked **live**. **Interactive, so never a silent upgrade change**, and **available regardless of the prepare-side flag** — insurance even for a flag-`no` repo (the one with no routine refresh). Still **no build / verify / push** — completion stays the human's | 011's accept was a pure rename+stop that "does NOT freshness-rebase"; 013 splits *freshness* (now surfaced as converge's first decision) from *completion* (still gated behind the human / the maintenance exception) | #57 |

Everything in 004–012 not named here is unchanged. 011's **automatic** accept behavior is
untouched (accept still does no rebase on its own, and build/verify/push stay gated). What 013 adds
at converge is a **new interactive offer** (Change E: surface "behind default by N" → Y/n refresh,
default Y) that rides *before* the accept/park/drop disposition — a question the human answers, not a
silent change to accept.

## The principle (the spine)

> **A prepare branch is a live investigation, not an archive. It should track the ground it
> investigates.** The default branch *is* that ground; when it moves, an un-refreshed prepare branch's
> **mergeability** rots in the dark. Rebasing onto the fetched default on every `prepare` keeps the
> branch **mergeable against current reality** — either it replays clean, or the merge conflict
> surfaces at rebase time (loud, dated, in front of the next agent) instead of at converge (discovered
> by the human mid-handoff).

**Why "on every `prepare`" and not "only what the run works."** `prepare` is built to run
**unattended, while the human is away** (§ Scheduling). Its whole value is keeping the **entire** queue
warm against current default *before* the human returns — so that whenever they open `converge`,
**every** branch is already handoff-ready, not just the ones a run happened to touch. Rebasing only
the worked branches would leave the rest to drift until converge, reintroducing the manual-rebase
friction 013 exists to remove. The accepted cost of the wide set is stated openly below (churn +
compounding union interleave on long-idle branches).

Three consequences follow directly:

- **Two layers of freshness — routine + offered.** `prepare` rebases **every in-progress branch,
  routinely** (unattended drift-hygiene: the whole queue stays mergeable, conflicts surface early);
  `converge` **surfaces "behind default by N" and offers the refresh as its first per-branch decision**
  (Change E) — belt-and-suspenders, catching any residual drift since the last run (or a flag-`no`
  repo). The human never *manually* hunts for the rebase; the `context.md` conflict that bit cde-148 is
  pre-resolved by `merge=union` at rebase time.
- **Drift becomes a rebase-time event, not a rot.** A moved base either rebases cleanly (context-only
  divergence auto-unions) or aborts loudly (a real source conflict) and is surfaced for `converge`.
  Either way it stops being a silent merge-time-bomb the next reader steps on.
- **The scope-only branch — 012's first-class outcome — rebases trivially.** A branch that carries
  only `.tsugu/context.md` touches no source, so its only *content* conflict is auto-unioned; it
  refreshes without a stop in the common case (the rare exception is a structural modify/delete of
  context.md). Union may still leave an interleaved region, and a `file:line` anchor into
  default-refactored source stays stale until the next active rewrite re-pins it — so "mergeable
  against default," not "pristine, anchors-valid." Reference-code branches are the ones that can hit a
  real source conflict and abort.

### The tradeoff, stated openly

The refresh **rewrites the branch's commits** (new base → new committer-dates, new SHAs). Two
things that could have been costs are not, and 013 makes each explicit rather than leaving them to
worry:

- **A rewrite would fake a fresh claim** — *if* recency read committer-date. Change C keys recency
  off **author-date**, which rebase preserves, so it does not.
- **A rewrite needs a force-push** to a pushed branch — *and that is the delivery*, not a hazard
  (Change D). The only residual is the genuinely-concurrent cross-machine writer, which
  `--force-with-lease` turns into a safe skip, not a clobber.

What remains a real (small) cost: `merge=union` is line-based, so a context.md conflict region gets
both sides interleaved — lossless but occasionally messy. It **self-heals** on a **worked** branch:
the next time an agent actively works it, the `context.md` rewrite (that rewrite *is* the claim, per
recency-as-claim) cleans the interleave in passing.

**Accepted costs of rebasing the whole in-progress set (the wide-set choice).** Keeping the entire
queue warm for the absent human is not free, and 013 names the costs rather than hiding them:

- **Churn on long-idle branches.** A branch nobody works still gets its SHAs rewritten every run, and
  in a pushed repo generates a force-push each run. This is deliberate — an unattended `prepare` exists
  precisely to keep even the untouched branches mergeable — but it is real traffic. (A future knob
  could cap it, e.g. skip a branch already on the current default tip — which the rebase is anyway a
  no-op for — but no finer throttle is specified here.)
- **Compounding union interleave on an idle branch.** The self-heal above fires only on a *worked*
  branch; a branch nobody reworks accumulates interleave each time default's mainline `context.md`
  conflicts with it. Bounded by how often default rewrites `context.md` (usually rare), but unbounded
  in principle. Converge's refresh + a human's eventual rewrite is the backstop.
- **A clean rebase is not "reversible" in tsugu's usual sense.** 013's "reversible" claims cover the
  *abort* path (restores the pre-rebase tip) and the *lease/divergence skip* (no push) — but a
  *successful* rebase's pre-rebase tip survives only in the **reflog**, not as a ref. This is standard
  git and acceptable (the work is replayed, not lost), but it is not the ref-level reversibility tsugu
  leans on elsewhere.
- **A persistently-conflicted branch stalls under flag-`yes`.** B2 aborts *and skips working* a branch
  whose refresh hits a real source conflict. Pre-013, a scheduled `prepare` kept working that branch on
  its stale base; post-013 it makes **no** automated progress until a human resolves the conflict at
  converge. That is a deliberate trade — unattended force-resolution is worse — but it is a **behavior
  change on conflicted branches**, not a pure improvement, and is named here so it is not a surprise.

**Why fresh-init defaults `yes` despite issue #57's "default conservative" suggestion.** The issue
floated a conservative default; 013 overrides it **for fresh repos** because the whole point of an
unattended `prepare` is to *do this work while the human is away* — a conservative default would leave
the queue cold exactly when the feature is meant to help, and the residual risk is small (local-first
repos push nothing; pushed repos are lease- + divergence-guarded; the costs above are bounded and
reversible-enough). Existing repos are still pinned to `no` on upgrade (no surprise); the human opts a
fresh repo down to `no` if they want the pre-013 posture.

---

## Change A — `prepare` freshness-rebases in-progress work branches (issue #57)

### A1. The routine gains a rebase step

After step 2's fetch and the step-3 partition, `prepare` iterates the **in-progress** work-prefix
branches (the same set it would work) and, when `rebase-prepare-onto-default: yes`, rebases each
onto the **fetched** default tip before working it (a clean rebase → work it; a conflicting one
aborts and is skipped this run — B2):

```bash
git fetch --prune <remote>                 # already step 2
# ... partition (step 3) → the in-progress set ...
git rebase --merge <remote>/<default>      # per in-progress LOCAL <work-prefix>/<slug>; --merge forces the union-capable backend
```

**The rebase set is the in-progress set, minus one exclusion (bare-submodule pairs, see A3).** The
partition already excludes:

- **settled** (tip contained in default) — nothing to refresh, it landed;
- **taken-over** (a non-default/non-work branch contains the tip — an accepted handoff or a human's
  own branch) — a human owns it; tsugu does not rewrite it;
- **zero-commit** (tip == the **current** default tip) — nothing to replay, exempt from the table.

So the set 013 rebases is precisely the branches with **no containing accepted/human branch**. This
is the load-bearing fact behind Change D's safety: rewriting these branches disturbs no
branch-as-message, because none exists over them (see Change D).

> **Pre-existing partition hole 013 surfaces (out of scope, file separately).** The zero-commit
> exemption keys off *`tip == current default tip`*. A **request-by-branch** (`prepare/look-into-X`,
> no own commits) based at an **older** default commit therefore **fails** the exemption and falls
> through to containment → mis-classified **settled** → dropped from the queue *and* listed as a
> `prune` delete candidate — i.e. an aged human ask is silently killed by drift. This is a partition
> defect in the *existing* recipe (git-recipes.md queue classification), not introduced by 013; 013
> only makes it salient (and the old "already current" wording overstated it — corrected above).
> Fixing it (distinguishing an aged empty ask from a genuinely-landed branch, which containment alone
> can't) is left to a follow-up issue.

**Which ref is rebased — the local work branch.** The rebase runs on the **local**
`<work-prefix>/<slug>` **with that branch checked out** (its own `git worktree` per the 004 worktree
model — `git rebase --merge <upstream>` on the checked-out branch, **never** the two-arg
`git rebase <upstream> <branch>` form, which would switch the shared checkout). 012's per-ref
classification already separates a
local `prepare/<slug>` from a possibly-divergent `<remote>/prepare/<slug>` and classifies each by its
own tip, so only a **local in-progress tip** enters the set. A **remote-only** in-progress ref (no
local branch on this machine — possible only under `push-prepare-branches: yes`) is materialized to a
local branch first, then rebased; Change D's push then updates **that branch's own** remote ref. A
machine never rebases a remote ref it has no local checkout of — it materializes it or leaves it to
the machine that owns it.

### A2. It promotes the existing `## Freshness` recipe, it does not invent one

`references/git-recipes.md` `## Freshness` already documents the exact mechanic (`git fetch` →
`git rebase <remote>/<default>`, `--force-with-lease` if pushed). 013 changes its **status**, not
its command:

- from **manual, resume-time, optional** ("Refresh on resume, and optionally periodically") →
  **an automatic, flag-gated step of the `prepare` routine**;
- and it **replaces the conflict rule** for the automatic path (Change B) — the manual recipe's
  "stop and ask the human" cannot apply to a human-absent scheduled run.

The manual recipe line stays for a **human-present** resume (a human at the terminal may still
rebase-and-ask); the **automatic** `prepare` rebase is governed by Change B.

### A3. Recursion — inherited for HAS-submodules, **excluded** for bare-submodule pairs

Per 008's recurse-and-run model, a **HAS-`.tsugu/`** submodule runs this whole `prepare` routine under
its **own** policy — so it rebases its own in-progress branches gated on its **own**
`rebase-prepare-onto-default` flag, at its own schema (never force-migrated). The rebase step rides the
existing descent.

**But a bare-submodule *pair* is excluded from the automatic rebase — this is the one place the
"inherits, no new rule" shortcut is wrong.** A bare submodule's work branch is coupled to a **meta**
`prepare/<slug>` by a gitlink + a recorded submodule SHA in `context.md` (008 / git-recipes). Rebasing
the submodule-side branch rewrites its SHAs, so the meta gitlink and the recorded SHA **dangle** (the
011 handoff's `git submodule update` would land a detached HEAD at an orphaned commit); repairing the
pair needs a **new gitlink-bump commit on the meta branch**, which **bumps the meta branch's
author-date and fakes a fresh claim** — colliding with Change C. The two halves must move **together or
not at all**, which an unattended per-branch rebase cannot guarantee. So 013 **excludes bare-submodule
paired work branches (and their paired meta branches) from the automatic rebase set**; their freshness
is left to **converge**, where the human-present pair handling already exists (Change E can refresh the
pair coherently under human supervision). `prepare` skips them and surfaces them as "behind default" at
converge like any other.

---

## Change B — Deterministic human-absent conflict posture (issue #57)

A scheduled `prepare` has no human to ask, so conflict handling must be **deterministic and
reversible**. Two kinds of conflict, two fixed rules:

### B1. `.tsugu/context.md` → declarative `merge=union` (lossless, never stops the rebase)

`context.md` is **narrative, not code** — it has no syntax to satisfy, so a conflict can be
resolved by **keeping both sides**. Git's built-in `union` merge driver does exactly that:
concatenate both sides of a conflicting hunk, produce no conflict markers, leave zero unmerged
paths. 013 declares it once, committed, so a **content** conflict in context.md never stops the
rebase:

```gitattributes
# .tsugu/.gitattributes  (written by init; paths are relative to this file's directory)
context.md merge=union
```

- **Why union over `-X theirs` / `checkout --theirs`.** Taking the branch's side discards whatever
  the default branch's mainline `context.md` picked up (the cde-148 reset). Union is **lossless** —
  it keeps both narratives; the branch's next active rewrite reconciles them (self-healing, per the
  tradeoff note). It is also **declarative** (one committed attribute, no mid-rebase special-casing)
  where `-X theirs` would be a global strategy option that also auto-resolves *code* conflicts —
  directly breaking B2.
- **Scope: `.tsugu/context.md` only.** The attribute lives in `.tsugu/.gitattributes` and names
  `context.md`, so it applies to the tsugu narrative file and nothing else. It keeps tsugu's
  committed footprint **inside `.tsugu/`** (consistent with 012's "no files added outside `.tsugu/`"),
  rather than a repo-root `.gitattributes`.
- **Requires the merge backend — force it explicitly.** `.gitattributes` merge drivers are consulted
  only by git's **merge** rebase backend; the legacy `apply`/`git am` backend does not consult them and
  does not populate an unmerged index. Rather than depend on the "default since git 2.26" (and on
  `git config --get rebase.backend` — which returns *empty* when unset, and on git < 2.26 unset means
  *apply*), the automatic rebase **forces the backend at the call site: `git rebase --merge
  <remote>/<default>`.** That guarantees the union driver applies regardless of the repo's config or
  git version. There is **no lossy `--theirs` fallback** — taking one side would silently drop
  default's mainline `context.md` (the exact cde-148 loss union exists to prevent), so 013 never does
  it (see B2).
- **Union covers content divergence, not structural conflicts.** `merge=union` resolves any *content*
  divergence of `.tsugu/context.md`; a **structural** conflict on that path (modify/delete,
  rename/delete, file/directory) is not content and union cannot resolve it — that rare residual falls
  through to B2's stop rule, exactly like a code conflict.
- **Repo-wide effect, intentional and flag-independent.** `merge=union` on `.tsugu/context.md` also
  applies to ordinary `git merge` of that path, not just the prepare rebase — and the migration writes
  `.tsugu/.gitattributes` **even into repos pinned `rebase-prepare-onto-default: no`**. This is
  **deliberate**, not an oversight: context.md is narrative and should never block *any* merge or
  rebase, regardless of the flag. So the 5→6 migration is not byte-for-byte behavior-preserving on this
  one point — a conscious, strictly-beneficial improvement, stated here rather than buried.

### B2. Any real conflict → abort, skip the branch, surface for converge

On the required merge backend a `.tsugu/context.md` *content* conflict auto-unions and never stops
(B1). So if the rebase **does** stop, union could not resolve it — it is a real conflict:

- **A source-file conflict, or a structural `.tsugu/context.md` conflict** (modify/delete etc., which
  union does not cover) → **`git rebase --abort`.** The abort restores the pre-rebase tip exactly, so
  the branch is left untouched. **`prepare` then skips working that branch this run** — it does *not*
  proceed to add commits onto the stale base (that would pile fresh work on un-refreshed ground,
  worsening the very drift 013 exists to remove, and produce commits that themselves need
  re-rebasing). The branch surfaces at the next `converge`.
- **No committed status, no narrative write on abort.** The aborted-refresh is **not** written into
  the branch's `context.md`: committing it would rewrite the claim's author-date (breaking Change C's
  claim-neutrality), and a status line would violate the single-layer / no-status-field invariant. The
  fact is **derived** at `converge` (the branch is behind default and did not fast-forward — Change E's
  "behind default by N") and, if a personal converge packet exists, noted there (personal / ephemeral,
  never committed).

This is deterministic and reversible: content context.md → auto-union; any real conflict → abort +
skip + surface. It **supersedes** the manual `## Freshness` "Non-trivial conflict → stop and ask the
human" rule for the **automatic** (human-absent) path — there is no human to ask, so it aborts and
skips rather than blocks.

---

## Change C — Recency-as-claim preserved via author-date (issue #57)

tsugu derives claims and staleness from **commit recency**: the `context.md`-rewrite commit's
author and timestamp *are* the claim; a branch whose last commit is stale is free to pick up
(SKILL.md *Multi-agent*, `git-recipes.md` recency prose). A blanket rebase **rewrites committer-date
to now on every replayed commit** — so a committer-date recency read would make every freshly-rebased
branch look just-claimed, and a three-week-stale branch would masquerade as fresh, defeating
`stale-after` and converge's stale marker.

**`git rebase` preserves author-date and rewrites only committer-date.** So the fix is to pin the
recency read to **author-date**:

- Wherever recency / "last activity" / staleness is read, key off **author-date** —
  `git log -1 --format=%aI <ref>` (strict-ISO author date), `git for-each-ref --sort=-authordate`,
  `%ai`/`%aI`/`%at` — **never** committer-date (`%ci`/`%cI`/`%ct`, `--sort=-committerdate`).
- The **containment** predicates (settled / taken-over) are unaffected — they read `git rev-parse` /
  `git merge-base --is-ancestor`, not dates.
- This is mostly a **prose-precision** change: the recency is currently documented in prose
  ("author and timestamp") and no committer-date command ships today, so 013 makes the existing
  intent explicit and adds author-date to any command that reads last-activity (notably the
  `stale-after` read at `converge`).

With author-date recency, a freshness-rebase is **claim-neutral**: the original `context.md`-rewrite
commit keeps its original author-date, so the branch's claim and staleness are exactly what they were
before the refresh.

---

## Change D — Force-with-lease is the delivery mechanism (issue #57)

For a **local-first** repo (012's default) the rebase touches only the local branch and **pushes
nothing** — zero external effect, fully within tsugu's external-silence posture.

For a **cross-machine opt-in** repo (`push-prepare-branches: yes`), the rebased branch is pushed with
a **pinned** `--force-with-lease` (never a plain `--force`, and never the **bare** `--force-with-lease`):

```bash
pre=$(git rev-parse <branch>)            # LOCAL tip, captured BEFORE any rebase
sha=$(git rev-parse <remote>/<branch> 2>/dev/null || echo "")   # remote baseline AT the step-1 fetch ("" if the branch is new)

# DIVERGENCE GATE — evaluated BEFORE the rebase, for pushed repos only:
if [ "$push_prepare" = yes ] && [ -n "$sha" ] && ! git merge-base --is-ancestor "$sha" "$pre"; then
  : # local & remote DIVERGED before fetch → SKIP this branch entirely (no rebase, no work); surface for converge
else
  git rebase --merge <remote>/<default>  # refresh, then do the run's work (conflict handling: B)
  # ... work ...
  if [ "$push_prepare" = yes ]; then      # cross-machine delivery, only after a clean refresh
    if [ -z "$sha" ]; then git push --set-upstream <remote> <branch>                      # FIRST push (create): no remote ref, no lease
    else                   git push --force-with-lease=<branch>:"$sha" <remote> <branch>  # divergence already excluded above → lease covers only after-fetch pushes
    fi
  fi
fi
```

Three points make this safe and, in fact, the goal:

- **Cross-machine delivery is the point.** A second machine that fetches now inherits the branch
  *already rebased onto current default* — exactly the "other machines want the latest prepare
  branch" intent. The force-push is how the freshened branch reaches them; it is delivery, not a
  hazard.
- **The lease protects an *after-fetch* concurrent claim; a pre-rebase divergence gate protects a
  *pre-fetch* one.** The pinned baseline is the branch's remote tip captured at the step-1 fetch
  (`$sha`). If another machine pushes **after** the fetch, the pinned lease mismatches → push refused →
  this machine skips, respecting the other's recency. But the lease alone is **not sufficient**: the
  refresh rebases the local tip onto `<remote>/<default>`, which does **not** incorporate
  `<remote>/<branch>` — so if the local and remote same-slug refs had **already diverged before the
  fetch**, the rebased local still lacks the remote's commits, the remote still equals `$sha`, and the
  lease would *pass* while the force-push **discards remote work known at fetch**. So a pushed repo runs
  an **ancestor check BEFORE rebasing** (`git merge-base --is-ancestor "$sha" "$pre"` — the pre-rebase
  local must contain the fetched remote tip); on failure it **skips the branch entirely — no rebase, no
  work, no push** — and surfaces the divergence for `converge`. Gating *before* the rebase (not at push
  time) is the conservative posture: a human-absent run never rebases and works a branch it already
  knows it cannot safely deliver. **The bare `--force-with-lease` is doubly unsafe** — it neither pins
  the baseline (its expected value is the *current* remote-tracking ref, so an intervening `git fetch`
  advances it and the check passes even when the local branch does **not** contain the fetched-in
  remote commits — it stops guarding the tip we reasoned about) nor covers pre-fetch divergence.
- **No branch-as-message to disturb (single-machine).** The rebase set is **in-progress only**
  (Change A2): no accepted-prefix or human branch contains these tips, so rewriting them breaks no
  handoff and no coordination ref. 011/012 deferred "history rewrite vs branch-as-message" to the
  multi-agent case; 013 discharges it here — single-machine is unconditionally safe; cross-machine is
  **lease-guarded (after-fetch) + ancestor-guarded (pre-fetch divergence)**, skipping rather than
  clobbering when either check fails.

The auto-push invariant (012 Change D) is unchanged: `prepare` force-pushes **only the
`<work-prefix>/*` branch it is refreshing**, and only under `push-prepare-branches: yes`. It never
force-pushes an accepted or human branch.

---

## Change E — Converge surfaces behind-default and offers the refresh first (issue #57)

`prepare`'s routine rebase (Change A) keeps drift *small*, but it runs on a cadence — between the
last `prepare` and a `converge` session the default can move again, and a branch may have no routine
refresh at all (`rebase-prepare-onto-default: no`, or a request-by-branch a scheduled `prepare` never
touched). So `converge` closes the gap **at the moment of handoff** — not by silently rebasing at
accept, but by making "how far behind default is this branch" a **first-class fact in the status
view** and the refresh its **first per-branch decision**.

### E1. The status view surfaces "behind default by N"

`converge`'s morning status view is read-only and derives each candidate's state from refs / DAG /
recency. 013 adds **two** derived facts per candidate:

- **behind default by N commits** (`git rev-list --count <branch>..<remote>/<default>`), shown like the
  existing *stale* marker; and
- **local/remote work-ref divergence** (pushed repos): local `prepare/<slug>` and
  `<remote>/prepare/<slug>` have diverged (neither contains the other) — the state that made a scheduled
  `prepare` **skip** the branch (Change D's divergence gate) and hand it to converge. Surfacing it here
  is what Change D promised ("surfaces the divergence for `converge`"); without it the human would see
  only "behind by N" and never learn *why* the branch stopped being auto-refreshed.

A branch that is current and undiverged shows nothing extra. These signals make the drift **visible**
before any disposition — the human no longer discovers it mid-handoff.

### E2. The refresh is the first decision on a behind branch (default Y)

When a candidate is behind default, `converge`'s **first** question on it — *before* the
accept / park / drop disposition — is:

> *"`<slug>` is N commits behind default. Refresh onto current default first? **[Y/n]**"*

Default **Y** (a branch being converged almost always wants to be current). The prompt is worded
"refresh first," **not** "before handoff" — because it precedes *all* dispositions, so it is a
**standalone step on the work branch**, not accept-only prep. On **Y**, refresh, then continue to the
disposition; on **n**, proceed with the branch as-is (011 classic).

**UX note — avoid per-branch prompt fatigue on a busy repo.** On a fast-moving default, nearly every
candidate is "behind by N," so a per-branch Y/n becomes an enter-key tax. Converge MAY **batch** the
offer once at the top of the session — *"M of K candidates are behind default. Refresh all before
review? [Y/n], or decide per-branch"* — falling back to the per-branch prompt only for the branches a
conflict stops (those need the human anyway). Batching is a presentation choice; the underlying
per-branch refresh mechanics (work-branch materialization, conflict handling, pushed-repo reconcile)
are unchanged.

**The refresh always operates on the local WORK branch `prepare/<slug>` — never on an accepted name.**
This is load-bearing: minting `<accepted-prefix>/<slug>` before the human has chosen *accept* would
leave an accepted-named branch that was never accepted if they then park/drop — breaking 011's
invariant that the accepted-prefix name *means* a human accepted (and misclassifying the branch as
*taken-over* on the next pass). So cold-start materializes the **work** name:

```bash
# same-machine: the local prepare/<slug> already exists → just refresh it
git rebase --merge <remote>/<default>                      # refresh (conflict handling: E3)
# cold-start converge (machine B, no local prepare/<slug>): materialize the WORK branch, then refresh
git switch --create prepare/<slug> <remote>/prepare/<slug> # local WORK name, NOT the accepted name
git rebase --merge <remote>/<default>
```

The disposition then acts on the refreshed `prepare/<slug>`:

- **accept** → 011's handoff rename `git branch -m prepare/<slug> <accepted-prefix>/<slug>` (now valid
  and identical for both machines — the accepted name is minted **only here, at accept**);
- **park** → leave the refreshed `prepare/<slug>` as-is (a rebased work branch — keep working it later);
  **no accepted name exists**;
- **drop** → delete `prepare/<slug>` (the refresh was wasted but harmless — nothing was published).

**Pushed-repo caveat — reconcile the remote after a refresh, or the branch wedges.** In a
`push-prepare-branches: yes` repo, converge's refresh rewrites the **local** `prepare/<slug>` but
Change E pushes nothing — so the remote still holds the pre-rebase tips, and the local and remote are
now divergent. Left alone (e.g. after **park**), the next scheduled `prepare` hits Change D's
divergence gate, **skips the branch entirely**, and hands it back to converge — a loop that never
heals until the remote catches up. What converge offers depends on **which kind of divergence** E1
surfaced — and the two are **not** the same, so converge must distinguish them by the same ancestor
check Change D uses (does the **pre-refresh** local tip contain the fetched remote tip?):

- **Refresh-created divergence** (pre-refresh local **contained** the fetched remote tip — the branch
  was in sync/ahead, and *this* refresh is what moved it): the rebased local **contains the remote's
  commits, replayed**, so overwriting the remote loses nothing. Converge **prints** (does not auto-run)
  the pinned `git push --force-with-lease=<branch>:<sha> <remote> <branch>` for the human to run —
  011's B3 print-only posture (never an auto-push; the human approves publishing). This is the common
  case (esp. after **park**).
- **Pre-existing divergence** (pre-refresh local did **not** contain the fetched remote tip — remote
  holds commits the local never had; the exact state Change D's gate skipped): a force-push here would
  **discard remote work known at fetch**. Converge therefore **never prints a reconcile force-push**
  for this case — it surfaces it as *"local and remote have diverged; integrate the remote work before
  handoff"* and leaves the reconciliation (merge the two work refs, or explicitly choose a side) to the
  **human**. A blind refresh does not resolve it; only human integration does.

On **accept** (refresh-created case), no separate reconcile push is needed — the human's normal
accepted-branch publish (011's B3, print-only, human-run — accept itself still pushes nothing) already
carries the refreshed history to the remote. On **drop**, no push (the branch is gone). So only **park
after a refresh-created divergence** needs the explicit reconcile-push offer — and it is offered, not
silently skipped; the pre-existing case is handed to the human as an integration decision, never a
clobber.

The refresh is **freshness only** — onto current default, keeping the branch's own narrative
(`merge=union` on `context.md`). It is **not** the maintenance complete-path: converge still does
**no build, no verify, no push, no PR** on a default handoff. 013 splits 011's bundled "the agent does
NOT freshness-rebase, build/test, push, or open a PR" into two: **freshness-rebase** becomes an offered
drift-hygiene step (here + Change A); **build / verify / push / PR** stay exactly where 011 put them —
the human's, or unlocked only by 011's human-marked **maintenance exception** (which already does its
own rebase→verify→ready, now simply sharing the same union / author-date mechanics).

### E3. Human-present conflict handling (the difference from prepare)

Converge is **human-present**, so its conflict posture differs from prepare's human-absent one (B2):

- **`.tsugu/context.md` content conflict** → `merge=union`, auto, lossless — identical to prepare.
- **A real conflict** (a source file, or a structural context.md conflict) → **do not blind-abort.**
  The human is right here: surface it live and let them **resolve it** (the ideal moment — the issue's
  cde-148 pain was a *manual* rebase the human had to think to start; an offered refresh that surfaces
  the conflict *for a present human to resolve* is strictly better), or **park** the item
  (`git rebase --abort`, decide later) as a normal converge disposition. Nothing is forced.

### E4. Gating — an interactive offer, never a silent change; independent of the prepare flag

The prepare-side flag (`rebase-prepare-onto-default`) governs only the **human-absent, routine,
history-rewriting, force-pushing** rebase — the risks that motivated a knob. Converge's refresh has
**none** of those risks: it is **human-present** (the human sees the "behind by N", answers Y/n,
resolves conflicts, controls any later push). So it is **not gated by the prepare flag** — it runs as
converge's offered first decision **regardless** of the flag, which is exactly the point: it is the
insurance for a flag-`no` repo (the one with no routine refresh) and a request-by-branch alike.

Because it is an **explicit interactive offer** (surfaced fact + Y/n, default Y), it is **never a
silent behavior change on upgrade** — so the migration's "preserve pre-013 behavior" promise is not
violated: 011's *automatic* accept behavior is unchanged (accept still does no rebase on its own); what
013 adds is a **new interactive question** the human answers, fully within converge's "read-only until
you decide, then decide dispositions" spine.

### E5. Recursion inherits it — and this is where the bare-submodule pair *does* get refreshed

Mirroring A3: a HAS-`.tsugu/` submodule's own `converge` surfaces its own behind-default and offers
its own refresh. The **bare-submodule pair** that A3 **excluded** from the unattended auto-rebase lands
here: converge refreshes the pair **coherently under human supervision** (011's paired-meta handoff
form) — the submodule branch and its meta gitlink/SHA move **together**, and the meta gitlink-bump is a
human-present action, so the author-date "claim" bump A3 worried about is a deliberate handoff act, not
a spurious unattended one. That is exactly why the pair is deferred to converge rather than auto-rebased.

---

## The flag and schema 5 → 6

### The flag

`policy.md` gains a **`## Freshness`** section with one field:

```markdown
## Freshness

rebase-prepare-onto-default: yes
```

`yes` (fresh-init default) → `prepare` runs Change A's rebase step over in-progress work branches.
`no` → `prepare` skips the rebase entirely (pre-013 behavior). It is an **independent** knob, not
folded into `push-prepare-branches`: rebase rewrites history and deserves its own name and its own
off-switch, even though its *push* half only fires where `push-prepare-branches: yes` already opted
into cross-machine external action.

### Schema 5 → 6 and the compat migration

A new default that changes behavior on upgrade is schema-gated (the 012 precedent), so:

- **Fresh `init`** stamps **`tsugu-schema: 6`** and writes `## Freshness` with
  `rebase-prepare-onto-default: yes` (the new default) plus the `.tsugu/.gitattributes`
  (`context.md merge=union`).
- **Existing repos** (`tsugu-schema: 5`, no `## Freshness`): the **5→6 migration writes the explicit
  `rebase-prepare-onto-default: no`** — pinning the **pre-013** behavior (no *unattended* rebase) so
  the upgrade **does not silently start rewriting + force-pushing** their `prepare/*` branches. It also
  adds `.tsugu/.gitattributes` (`context.md merge=union`) — the **one intentional, flag-independent**
  non-preservation (B1: narrative should never block any merge; strictly beneficial). A repo that
  already set the field keeps its value (migrations never overwrite curated content). To turn the
  routine refresh **on**, the human flips the pinned `no` to `yes` — a deliberate, one-line opt-in.
- **Converge's refresh is not schema-gated — and doesn't need to be.** The behind-default surfacing +
  Y/n offer (Change E) is an **interactive** addition, not a silent behavior change, so it applies to
  upgraded repos immediately without violating "preserve pre-013 behavior": 011's *automatic* accept is
  unchanged; the human simply gets a new question. It is independent of `rebase-prepare-onto-default`
  (E4).
- **Absent `## Freshness` reads as `no` — fail-safe, no schema-conditional needed.** `yes` only ever
  comes from an **explicit** field, which **fresh `init` always writes**; the migration always writes
  an explicit value into existing repos. So an *absent* field can only be a pre-migration schema-5 repo
  (correctly pre-013 = `no`) or a hand-edited/interrupted schema-6 repo — and defaulting **either** to
  `no` is the safe read (a stray schema-6-absent must never silently enable the rewrite + force-push the
  migration deliberately pinned off). This is simpler and strictly safer than a schema-conditional
  default. The read lives at the new SKILL.md rebase step.

> **Note on "default `yes`" for upgraded repos.** The **fresh-init** default is `yes`; existing repos
> are pinned to their **pre-013** behavior (no rebase = `no`), exactly the shape 012 used when it
> flipped `push-prepare-branches` (new default `no`, existing repos pinned to the old `yes`).
> "Preserve pre-upgrade behavior" here means `no`, because there *was* no rebase before 013. A repo
> that wants the refresh on its existing prepare branches flips the one line.

The migration rides `references/migrations.md` (a `5→6` step) and the `init` re-run path (stamp
written **last**; on a push-protected default branch it rides an `init/*` branch + human-approved PR,
per 004–012). The only committed structural change is the stamp, the `## Freshness` field, and the new
`.tsugu/.gitattributes`.

---

## State model (unchanged invariant, restated)

No part of 013 sets a **status field**. The rebase set is **derived** (the in-progress partition —
containment + author-date recency); a conflict abort writes **nothing** (no status, no narrative — the
"behind default by N" fact is *derived* at `converge`, not recorded); and the claim/staleness read
stays derived from **author-date** recency. The refresh is **reversible** (a conflict abort restores
the pre-rebase tip and the branch is skipped; a lease mismatch skips). State stays derived from
refs / DAG / containment / recency.
*Narrative informs judgment, never classification.* The prepare discovery model becomes:

```
prepare (human-absent): fetch → partition work prefixes (local + remote) by tip:
  • settled / taken-over / zero-commit        → NOT rebased (excluded from the set)
  • in-progress (LOCAL work branch)           → if rebase-prepare-onto-default: yes (absent → no, fail-safe):
       DIVERGENCE GATE (pushed repos, BEFORE rebase): remote $sha not ancestor of local $pre
                                                → SKIP branch entirely (no rebase/work/push); surface at converge
       else git rebase --merge <remote>/<default>  (forces the merge backend → union driver applies)
         · .tsugu/context.md CONTENT conflict → merge=union (auto, lossless, never stops)
         · any real conflict (code/structural)→ git rebase --abort; SKIP working it this run; surface at converge
                                                 (no committed status write)
       then work it (only on a clean refresh; an aborted one is skipped)
       if pushed (push-prepare-branches: yes), after a clean refresh:
         first push (no remote ref)           → git push --set-upstream (create; no lease)
         else (divergence already excluded)   → git push --force-with-lease=<branch>:$sha <remote> <branch>
  EXCLUDED from the auto-rebase set: bare-submodule PAIRS (coupled gitlink/SHA → leave to converge)
recency / staleness read off AUTHOR-DATE (rebase preserves it) → refresh never fakes a claim.

converge (human-present): status view surfaces per candidate: "behind default by N" + local/remote DIVERGENCE (pushed).
  behind? → FIRST decision (before accept/park/drop): "refresh onto default first? [Y/n]" (default Y; may batch)
     Y → materialize/refresh the WORK branch: git rebase --merge <remote>/<default> on prepare/<slug>
          (cold-start: git switch --create prepare/<slug> <remote>/prepare/<slug> first — WORK name)
          · content context.md → merge=union   · real conflict → surface LIVE; resolve or park
          pushed repo, refresh-CREATED divergence (pre-refresh local ⊇ remote tip) → PRINT reconcile force-with-lease (esp. before park)
          pushed repo, PRE-EXISTING divergence (Change D skip case) → surface "integrate remote first"; NEVER a force-push (would clobber)
     n → proceed as-is (011 classic)
  → then accept (mint <accepted>/<slug> HERE) / park (leave prepare/<slug>) / drop. No build/verify/push.
  NOT gated by rebase-prepare-onto-default; interactive, so never a silent upgrade change.
```

---

## Files touched

| File | Change |
| --- | --- |
| `plugins/tsugu/skills/tsugu/SKILL.md` | prepare routine gains the **rebase step** on the **local, checked-out** in-progress branch (Change A) after the partition, gated on `rebase-prepare-onto-default` (absent → **`no`, fail-safe**; `yes` only from an explicit field); the **human-absent conflict posture** (B: union for context.md content via **forced `git rebase --merge`**, **any real conflict → abort + skip + surface, no status write**); the **pinned + divergence-guarded `--force-with-lease`** delivery, with a first-push (create) carve-out (D); *Multi-agent* / recency prose → **author-date** (C); **bare-submodule pairs excluded from the auto-rebase set** (A3, coupled gitlink/SHA → converge); the **wide-set accepted costs** (churn / interleave / non-reflog-reversibility / conflicted-branch stall) noted; schema `5 → 6` |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | `## Freshness` recipe **promoted** from manual/optional → the automatic flag-gated `prepare` step; conflict rule **replaced for the automatic path** (union content-conflict on `.tsugu/context.md` via **forced `git rebase --merge`**; **any real conflict → `git rebase --abort` + skip working the branch this run + surface; no `--theirs` fallback**); `--force-with-lease` → the **pinned** `=<branch>:<sha>` form **plus a pre-rebase ancestor divergence-guard (skip the branch entirely on divergence) and a first-push (create) carve-out** framed as cross-machine **delivery** + the concurrent-claim skip (warn against bare); the **recency/classification prose → author-date** (`%aI`/`--sort=-authordate`, never `%cI`/`committerdate`); the **accept/handoff recipe** gains the cold-start **materialize-work-branch-then-refresh** ordering (accepted name minted only at accept) — its current "does **not** freshness-rebase" line revised to freshness-refresh-offered / build-verify-push-no; **consolidate `## Freshness` into one who's-present → posture mode table** (manual-resume: ask · unattended prepare: abort+skip · converge: resolve/park live · maintenance: rebase→verify) so a recipe-only reader isn't left guessing which rule applies |
| `plugins/tsugu/skills/tsugu/SKILL.md` (`converge`) | status view surfaces **"behind default by N"** *and* **local/remote divergence** (pushed) per candidate (E1, `git rev-list --count`); the **refresh becomes the first per-branch decision** when behind (E2, Y/n default Y, before accept/park/drop, worded "refresh first"; **may batch** on busy repos); **refresh always on the work branch `prepare/<slug>`** (cold-start materializes the work name, not the accepted name — accepted minted only at accept; park/drop-after semantics spelled out); **pushed-repo reconcile (divergence-origin-gated): PRINT the human-approved force-with-lease push only for refresh-CREATED divergence (esp. before park, else the branch wedges the next `prepare`); PRE-EXISTING divergence is surfaced as "integrate remote first", never a clobbering force-push**; human-present conflict posture (resolve/park live, E3); **not gated by the prepare flag, interactive so never a silent upgrade change** (E4); the **bare-submodule pair is refreshed here (coherently, human-present) since A3 excluded it from auto-rebase** (E5); explicit "still no build/verify/push"; the maintenance exception shares the union / author-date mechanics |
| `plugins/tsugu/skills/tsugu/references/migrations.md` | **new `5 → 6` step** — write explicit `rebase-prepare-onto-default: no` when `## Freshness` absent (preserve pre-013 *unattended* behavior); add `.tsugu/.gitattributes` (`context.md merge=union`) **unconditionally** (the one intentional flag-independent non-preservation); stamp written last; `init/*`-branch + PR path on push-protected default |
| `plugins/tsugu/skills/tsugu/templates/policy.md` | `tsugu-schema: 6`; new **`## Freshness`** section with `rebase-prepare-onto-default: yes` + a comment on the rewrite/force-with-lease/author-date-claim rationale and the `no` off-switch |
| `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` | new **`### ## Freshness`** field subsection (mirrors the per-field docs for `## Push` etc.): what `rebase-prepare-onto-default` gates (prepare-side only), the converge refresh being flag-independent, and the merge-backend requirement |
| `plugins/tsugu/skills/tsugu/templates/gitattributes` (new) | committed as `.tsugu/.gitattributes` by `init`: `context.md merge=union` |
| `plugins/tsugu/skills/tsugu/SKILL.md` (`init`) | `init` writes the `## Freshness` default + the `.tsugu/.gitattributes`; migration adds them to existing repos |
| `CLAUDE.md` (repo root) | update the tsugu paragraph: **schema 5 → 6**, lineage `… → 012 → 013`, and the converge note — accept is a rename+stop that no longer says "does not rebase" flatly (converge now *offers* a freshness-refresh; completion — build/verify/push — still gated). Rides straight to `main` per the docs convention, but enumerated so the second-consumer stays consistent |
| `plugins/tsugu/commands/prepare.md` + `commands/converge.md` | prepare description notes the freshness-rebase of in-progress branches (flag-gated); converge description notes the accept-time insurance refresh |
| `plugins/tsugu/skills/tsugu/README.md` | user-facing: prepare keeps in-progress branches current against default; the flag; the union/author-date/lease guarantees in plain terms |
| `.claude-plugin/marketplace.json` + `plugins/tsugu/.claude-plugin/plugin.json` | bump tsugu `0.7.0 → 0.8.0`; descriptions note the freshness-rebase + schema 6 |
| `tools/tsugu/test-skill-content.sh` | content anchors: the prepare rebase step, `rebase-prepare-onto-default` (fresh default `yes`, absent→`no`), `merge=union` for context.md, **forced `git rebase --merge`**, author-date recency, **pinned + ancestor-guarded** `--force-with-lease=` delivery with a first-push carve-out, real-conflict **abort + skip** posture, **bare-submodule pair excluded from auto-rebase**, converge's **"behind default by N"** + **divergence** surfacing, **Y/n first decision**, **work-branch (not accepted-name) materialization**, **pushed-repo reconcile-push offer**, schema 6; refute a committer-date recency read, a **bare** `--force-with-lease` in the prepare recipe, a `--theirs` context.md fallback, a cold-start `switch --create <accepted-prefix>`, the claim that **rebasing keeps `file:line` anchors valid** (013 explicitly does *not* claim this), the old manual-only "stop and ask the human" as the *automatic*-path rule, and 011's flat "accept does **not** freshness-rebase" as still-current |

**Schema migration:** `tsugu-schema: 5 → 6` with the compat step above. `public-branch-tsugu`, the
011 handoff model, and 012 local-first are unchanged.

## Closes

`#57` (unattended `prepare` rebases in-progress `prepare/*` onto the current default so the whole queue
stays **mergeable** while the human is away, and `converge` surfaces "behind default by N" + divergence
and offers the refresh as its first per-branch decision — the human never *manually* hunts for the
rebase, and merge-level conflicts surface at rebase time in front of the present human. 013 does **not**
claim to keep `file:line` anchors valid — that heals only on the next active `context.md` rewrite.)

**Files a follow-up** for the pre-existing partition hole this surfaced: an aged zero-commit
request-by-branch (based at an older default) mis-classifies as *settled* (see Change A).
