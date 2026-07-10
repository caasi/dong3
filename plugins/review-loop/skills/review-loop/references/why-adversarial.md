# Why the reviewers are adversaries

Background for `SKILL.md`'s Phase A. The skill carries only what the agent must
execute; the reasoning lives here.

## Credit

The panel's three invariants — **independence**, **adversariality**, and
**synthesis without averaging** — are borrowed, wholesale and deliberately, from
the **`adversarial-panel`** Claude Code skill:

- Repository: <https://github.com/makinux/adversarial-panel>
- Author: makinux · Concept and design essay: Ryousuke Wayama (@wayama_ryousuke),
  *"adversarial-panel:多モデル敵対的レビューという品質保証"*, 2026-07-09
- Licence: **MIT** — Copyright (c) 2026 makinux

So are the named anti-patterns this skill guards against: *ghost panelist*,
*sycophantic convergence*, *facilitator capture*, *confidence theater*, and
*diversity illusion*. `review-loop` re-implements them for a different target and
adds rules of its own; it does not copy that skill's text.

## The problem it solves

An LLM's answer is most dangerous not when it is wrong, but when it is
confidently wrong. Self-critique cannot catch that: the blind spot at generation
time and the blind spot at critique time come from the same weights, and models
demonstrably prefer their own output. A model reviewing its own diff is not a
second opinion — it is an audit with a conflict of interest.

Before this change, `review-loop` had two reviewers but arranged them as a queue:
a Claude subagent reviewed, its fixes were committed, and only then did Codex
read the already-fixed tree. Codex could never dispute Claude's reading of a
finding, because it never saw what Claude saw.

## The two properties that make a panel work

Neither follows from merely having more than one reviewer. Both must be
engineered.

**Decorrelation.** A reviewer catches what the author missed only when their
failure modes differ. Same-family panels share blind spots, so their agreement is
weaker evidence than it looks. Hence the roster is ranked by *heterogeneity*, not
by capability, and the gate verdict says which tier actually ran — a same-family
"clean" is reported as weak evidence, and a `claude-alt` that turns out to equal
the session model degrades to *fresh-context only*.

**Verification advantage.** Refuting a claim is cheaper than producing one. So
critics are pointed at *verifiable* claims and made to refute by reproduction —
"this fails on input X", not "I doubt this". `review-loop` presses this further
than its source can, because its target is a diff rather than a claim: where a
finding is executable, a failing test settles it, and disagreement between
panelists is converted into a test rather than into another round.

## What we changed on purpose

- **Reproduction outranks argument.** The source skill debates claims. We review
  code, which has a runnable ground truth. A prose target gets an analogue — a
  citation the *facilitator* verifies with a command — because "a reader can
  check it" is a capability, not a check.
- **`confidence` authorizes nothing.** It is a self-report by the weights that
  produced the finding. What opens the auto-fix gate is `reproduced`, or `survived` (the
  finding faced an adversary) **together with** high confidence and a concrete
  falsification condition — confidence never opens it alone, and never without the
  condition that says what would retract it. Gating on "not refuted" would admit a
  finding no adversary ever examined; on a single-reviewer run that reduces to a
  model grading its own work and committing it.
- **`refuted` had to split.** An attack its author never answered is
  `refuted-undefended`: a live disagreement for the author, never a verdict the
  facilitator may act on.
- **No forced disagreement.** The source's *"you disagree with at least one
  central claim; find it"* manufactures a refutation when the other panelist is
  right. We ask instead for the claim you tried hardest to break, and whether it
  held. A round that refutes nothing is legitimate; a round that *attacks*
  nothing is the failure.
- **We keep a structural detector the source does not have.** A native Codex
  round that ran zero `command_execution` items never read the tree — that is
  evidence, not phrasing, and it cannot be talked around. Its one exemption is R2
  critique rounds, whose subject is the other panelists' findings rather than the
  tree, so zero commands there says nothing about sandbox health.

## The cost, stated plainly

Cross-critique adds one call per panelist before the first fix. Usage limits are
a first-class outcome, so the real marginal cost is one fewer convergence round
before the limit. That R2 pays for itself — false positives dying before they
become a commit, a test, and a convergence round — is a **hypothesis**. The
review journal records R2's kill rate and rounds consumed so it can be checked
against reality rather than taste.
