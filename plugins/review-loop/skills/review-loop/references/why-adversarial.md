# Why the loop reviews more than once — and when a different family is worth it

This note records where the multi-reviewer design came from, what we borrowed, what we
deliberately did not, and how confident we are in each claim. It is rationale, not behaviour;
the behaviour lives in `SKILL.md`.

## Credit

The idea of an adversarial, blind, cross-family review panel comes from
**[makinux/adversarial-panel](https://github.com/makinux/adversarial-panel)** (MIT licence,
Copyright (c) 2026 makinux) and its design essay,
["adversarial-panel:多モデル敵対的レビューという品質保証"](https://x.com/wayama_ryousuke/status/2075147624806813800)
by Ryousuke Wayama (@wayama_ryousuke), 2026-07-09.

**We take its insight, not its architecture.** None of that project's text is copied into this
skill; what follows is our own wording of the ideas we adopted, and a plain statement of the
ones we left behind.

## What we took — the insight

- An LLM's answer is most dangerous when it is **confidently wrong**, and self-critique cannot
  catch that: the blind spot at generation time and at critique time come from the same weights.
  A model reviewing its own diff is an audit with a conflict of interest.
- Therefore a reviewer **must not see another reviewer's findings before forming its own**. That
  is the whole of the blind, parallel first round (`SKILL.md` A1).
- **Refute by reproduction, not by assertion** — "this fails on input X", not "I doubt this".
- Its five named failure modes, kept as a checklist we test *ourselves* against:
  *ghost panelist*, *sycophantic convergence*, *facilitator capture*, *confidence theater*,
  *diversity illusion*.

## What we did not take — the architecture

`adversarial-panel` is a skill for debating **claims**. `review-loop` reviews a **diff**. A claim
can only be argued with; a diff has a runnable ground truth, so where a finding is executable a
failing test settles what no amount of debate could. That difference is why we left behind:

- Its role split (facilitator + panelists), its Round 0 triage, its Rounds 1–3, and its synthesis
  output format. `review-loop` already has a shape: reviewers, tiers, an author who decides, a
  forge phase.
- Its **mandatory** cross-critique, and the prompt that pushes a reviewer to disagree. Forcing an
  attack manufactures a refutation when the other reviewer is right, so here cross-critique is
  recommended and **gates nothing**.
- Its confidence contract as anything load-bearing. adversarial-panel requires a confidence *and*
  a falsification condition on every key claim and — importantly — **gates on neither**. We keep
  neither as a required field: we ask for a falsification condition (reproduction can check it)
  and make confidence optional. Note plainly: gating auto-fix on `confidence == high` was a
  mistake in *this project's own earlier draft*, not something adversarial-panel does — the gate
  was ours, and it is gone.
- Above all, a **permission system built on adversarial survival**. A finding is not actionable
  because it survived an argument; it is actionable because it was **reproduced**.

## Two hypotheses, graded by how sure we are

Both come from the same observation — a second look catches what the first missed — but they
claim different mechanisms and deserve different confidence.

**Strong: more passes is more thinking.** A fresh pass over the same artifact finds real defects
*even by the same weights* — a reviewer that has not seen its own earlier reasoning is a longer
chain of thought with a clean context. We have direct evidence: in this project's own review
history, same-family reviewers (a different Claude model, and in one case the same model) found a
false premise the design rested on for three sections, a whole class of regression-test weakness
nobody else saw, four weak test anchors, and a missing licence attribution. This is the
load-bearing reason the loop reviews more than once, and it works on a host with no second CLI.

**Weak: different families catch different holes.** Plausible, adopted, and **not measured**,
here or in the source essay. What our record actually shows is narrower: cross-family reviewers
found *states nobody had run* — a difference in where they looked, which decorrelation predicts
but does not uniquely explain. So we adopt the argument only as a reason to **offer** a
cross-family reviewer, never as a reason to **demote** a same-family one.

## Therefore

**Heterogeneity is a bonus, not a gate.** Nothing in the loop requires a cross-family reviewer,
refuses to act without one, or blocks a clean verdict on its absence. The verdict simply **names
which reviewers actually ran** — disclosure, not a ranking — so a reader knows whether the
cross-family perspective was exercised this run, never to discount a same-family pass. And what
makes any finding actionable is the same as it always was: it was reproduced.
