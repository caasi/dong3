# 016 — review-loop observation log

Status: design, for review. Implements nothing yet.
Issue: caasi/dong3#56.
Supersedes the proposal in that issue, which is withdrawn (see § 1).

## 1. What this is, and what it is not

`review-loop` runs until K consecutive dry rounds. A dry round is one where every live reviewer
returns `converged: true`. Issue #56 proposed to log the round count as a signal of how capable
the driving model is.

**That proposal is withdrawn.** The round count mixes artifact difficulty, the K policy, roster
composition and author decisions. It also falls when a reviewer drops out mid-run, so a degraded
run scores better. And a review loop is a repair mechanism, so its convergence is the quantity
that hides a capability change, not the one that shows it. Anthropic's own postmortem records
evaluations that missed a real degradation "in part because Claude often recovers well from
isolated mistakes".

**This design records observations and computes nothing.** It changes no loop behaviour. K keeps
sole authority over termination. Nothing is displayed to the author during a run.

The purpose is to find out, over 18 months, whether a confidence instrument for this loop is
possible at all. The answer may be no. § 8 states in advance what would show that.

## 2. Why a log now, rather than a design later

The loop produces state that exists only while it runs. Each reviewer's per-round verdict, the
facilitator's K signal, and the routing decision for the Codex path are never written anywhere.
When the run ends they are gone. No later analysis can reconstruct them.

Everything else can wait, because it is derivable from git.

## 3. The organising rule

> **Record only what cannot be reconstructed from git later.**

Derived measurements must be recomputed, never stored, because the tools that derive them improve.

This rule decides every field below. It also protects the corpus from the tools' current defects.

**Worked example — `fxrank`.** An effect profile of the changed code would be a useful covariate:
a dry round on pure, effect-free code plausibly means more than a dry round on effect-heavy code,
because more of that artifact was constrained before review. But `fxrank` has open P1 defects that
would be baked into any stored reading: cross-language comparability is inverted (#74), the
confidence channel is effectively binary (#77), qualified pure calls are over-smeared (#76), test
code leaks into production ranking (#53), and name heuristics misclassify pure predicates (#52).
So the effect profile is **not logged**. The commit range is logged, and the profile is computed
later by whichever version of `fxrank` is current.

**Precondition.** Derivability requires the recorded commits to stay reachable. This repository's
conventions support that: local branches are not pruned eagerly, and squash merges into primary
branches are avoided. If that changes, the derivable half of this design is lost.

## 4. Schema

One JSON object per line. Two record kinds, distinguished by `kind`.

### 4.1 Round record

```json
{
  "schema": 1,
  "kind": "round",
  "run": "<opaque run id, stable within one loop>",
  "repo": "<salted hash of the repository path>",
  "base": "<base commit sha>",
  "head": "<head commit sha at this round>",
  "round": 3,
  "date": "2026-07-20",
  "target_kind": "code | spec | plan | doc | mixed",
  "enrolled": ["claude", "codex"],
  "live": ["claude"],
  "dropped": {"codex": "usage-limit | absent | failed | non-review"},
  "verdicts": {"claude": true, "codex": null},
  "suspected_drift": ["claude"],
  "fix_round": true,
  "k_signal": 2,
  "k_running": 2,
  "findings_resolved": {"t1": 3, "t2": 1, "t3": 0},
  "checks": {"ran": true, "failed": false, "kind": ["test", "typecheck"],
             "provenance": "pre-existing | written-this-session | mixed"},
  "codex_path": "native | embedded-diff | n/a",
  "guard": {"proposed": false, "accepted": null, "verdict": null}
}
```

### 4.2 Outcome record

Written by a scheduled retrospective scan, not by the loop. See § 6.

```json
{
  "schema": 1,
  "kind": "outcome",
  "repo": "<same salted hash>",
  "head": "<head commit sha of the run this refers to>",
  "date": "2026-08-14",
  "escaped": true,
  "fix_commit": "<sha of the fix that proved it>",
  "days_elapsed": 25,
  "merges_since": 18,
  "blamed_lines": 7,
  "test_verified": true
}
```

A record with `escaped: false` is **censored survival data**, not a clean verdict. It states only
that no escaped defect was attributed after `days_elapsed` days and `merges_since` merges. Its
weight must grow with both. A fresh run always reads `escaped: false` and means nothing.

## 5. Field rationale — why each cannot be reconstructed

| Field | Why it is unrecoverable |
|---|---|
| `verdicts` | Each reviewer states `{converged, still_open, reason}` per round (§ A3). Only the loop sees it. |
| `enrolled` / `live` / `dropped` | § A3 treats an unavailable reviewer as "done". A dry round on a degraded set is a different event from one on a full set, and afterwards the two are indistinguishable. |
| `k_signal` / `k_running` | K is the facilitator's judgement of whether each resolved finding had a runnable check. It is the loop's existing confidence signal and it is never written down. |
| `codex_path` | Native `review` **silently false-cleans** on a broken sandbox host against unpushed commits (§ Codex mechanics, and SKILL.md's note on local-only commits on `main`). Without this flag, false-clean dry rounds are indistinguishable from real ones and the corpus is permanently contaminated. |
| `suspected_drift` | Advisory, collected per round, discarded after. |
| `guard` | The direction guard is proposed, accepted or declined per episode. A clean audit discharges a K ≥ 2 hold. |
| `findings_resolved` | Post-cross-critique, deduplicated, tier-classified counts. The classification is facilitator judgement made at the time. |
| `checks.provenance` | Whether a test pre-existed is derivable; whether it *ran during this round* is not. |
| `base` / `head` / `repo` | The join key. It is what makes everything in § 3's derivable column derivable. Without it the log cannot be linked to any outcome, and version 1's whole purpose fails silently. |

### Explicitly not recorded

- **`still_open` and `reason` from the verdict object.** Only the boolean is taken. Those fields
  carry finding text.
- **Any path, diff, or finding text.**
- **The repository path in plain form.** A salted hash, because this file may sit beside
  configuration that is symlinked into a repository that gets pushed.
- **Any derived measurement**: effect profile, diff size, file counts, test presence.
- **Any computed probability.** See § 7.

## 6. Storage and collection

**Path:** `~/.claude/review-loop.stats.jsonl`, a sibling of the existing
`~/.claude/review-loop.local.md`. Never `${CLAUDE_PLUGIN_ROOT}`, which the marketplace replaces on
update. Never inside a repository under review.

**Enforcement, not documentation:** the writer refuses to write if the resolved path is inside a
git work tree, and creates the file with mode 0600.

**Never commit.** The user's `~/.claude/` contains files symlinked into a dotfiles repository that
is pushed. This file must be excluded there.

**Writer:** a helper script beside `copilot.sh` and `pr-comments.sh`, called with explicit
arguments at each round boundary. Not an instruction in SKILL.md prose — a prompt instruction is
skipped nondeterministically, and most often by exactly the weak model the log would document.

**Outcome records** come from a scheduled retrospective scan over git history, not from the author
and not from the loop:

> a `fix:` commit that adds or changes a real test, and modifies pre-existing lines whose blame
> points to a commit merged in a different, earlier pull request.

The author is not asked to remember anything. Escape latency is bimodal — median 4 days and 8
intervening merges, with a cluster at 10 to 27 days and 18 to 30 merges — so a question asked at
merge time is close to uninformative.

**Outstanding verification.** The scan has not been validated by checking out the parent commit and
running the added test to confirm it fails. That check is cheap for a Rust or OCaml target. Until it
is done, `test_verified` must be written as `false` and outcome records carry no weight.

## 7. No inference in version 1

Nothing computes a posterior during a run, and nothing is displayed to the author.

The reason is not that a displayed number would gain unearned authority, though it would. The
reason is that **displaying it contaminates the collection.** It would change what the author
attends to and how they report. A corpus gathered while a number was on screen cannot afterwards
be used to test that number.

An offline command may read the log and print a posterior. It must print every parameter it used
beside the number, and label itself experimental. Disputes then happen against a fixed corpus.

### The model, stated as a hypothesis under test

Latent variable `D` = at least one defect remains. Each observation is a sensor with a likelihood
under `D` and under `not D`. The panel event for a live-set is modelled directly, so no
independence between reviewers is assumed.

**All likelihood values are chosen, not estimated.** None may be written into this design. When
they are eventually set, they must be derived from a stated posterior budget — decide first what
the posterior may reach on dry rounds alone, then solve for the largest per-round likelihood ratio
consistent with that — and the prior must be anchored on the one empirical number available: at
least 23 percent of merged pull requests in four repositories carried a defect a test later proved.

### Known failure modes, recorded so they are not rediscovered as surprises

1. **Weak evidence compounds.** Weakness limits the rate, not the destination. A likelihood ratio
   of 1.2 per dry round reaches a posterior of 0.97 from a prior of 0.5 in 20 rounds. "Weak,
   therefore safe" is false.
2. **The misspecification is directional.** Every sensor errs toward "clean": a reviewer reports
   converged more readily when a defect is subtle, when its context is exhausted, and after the
   loop has repaired the visible problems. Random errors partly cancel across observations.
   Directional errors accumulate.
3. **The sensor is not conditionally independent of the artifact.** The reviewer, the fixer and
   often the test author are the same model family. No reviewer-correlation term repairs this.
4. **`rho` is not identifiable from round structure.** A miss count is bounded above by the round
   count by construction, so any correlation between them is partly definitional. The loop cannot
   calibrate itself from its own rounds. This is why outcome records come from outside the loop.

## 8. Pre-registered failure conditions

Fixed now, before any likelihood value is chosen, because they are what make this a design rather
than an open-ended activity.

| Test | Fails if | Needs |
|---|---|---|
| **T3 — non-informativeness** | the exit posterior correlates with the round count above 0.9; the number is then a restatement of K | ~50 runs, no labels |
| **T4 — parameter dominance** | varying any chosen likelihood ratio by a factor of 3 moves the exit posterior by more than 0.2 for most runs; the number then reports the parameters, not the evidence | parameters only |
| **T1 — discrimination** | the exit posterior separates later-leaking runs from clean ones at an area under the ROC curve of 0.6 or below | ~40 outcome labels |
| **T2 — confident and wrong** | among runs whose posterior exceeded 0.9, the observed escape rate is above 0.2; the directional misspecification in § 7 has then occurred and the instrument is harmful | ~40 outcome labels |

**Interim gate at about 50 logged runs:** run T3 and T4. Either alone stops the project.

**Verdict horizon: 150 to 200 logged runs, or 18 months, whichever comes first.**

**A further failure condition, written down now because it is the easiest to explain away later:**
if at 18 months the corpus is still too small to run T1, that is itself a failure verdict. It means
the instrument needs more data than this workflow produces.

At roughly one escaped defect per 4.4 merged pull requests, 40 labels need about 175 merged pull
requests. Four repositories took the project's lifetime to accumulate 128.

## 9. What a later specification may and may not claim

**May claim:** that the log records observations and computes nothing during a run; that the model
is a hypothesis with pre-registered falsification tests; that an offline experimental command may
compute a posterior if it prints its parameters; that K keeps sole authority.

**Must not claim:** that any posterior is calibrated; that any likelihood was estimated; that the
number measures `P(clean)`; that a dry round is evidence of cleanliness of known strength; that
slow movement is by itself evidence of honesty; that repeated passes are shown to be necessary or
insufficient; that cross-family decorrelation was measured.

## 10. Open questions

1. Should `run` be derivable from `repo` plus `base` plus start time, rather than opaque, so a
   resumed loop can append to the same run?
2. `target_kind` is facilitator judgement. Is a coarse split of code against prose enough, given
   § A3 already distinguishes them only by whether a runnable check exists?
3. The salted hash of the repository path needs a salt that survives across machines but is not in
   the dotfiles repository. Where does it live?
4. Should the writer refuse to run when `git` reports a dirty tree, so `head` is unambiguous?
