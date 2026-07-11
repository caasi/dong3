# 014 — review-loop: a reviewer roster you choose per environment

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [002](002-review-loop-plugin-design.md), [003](003-review-loop-headless-codex-design.md), [009](009-review-loop-codex-sandbox-fix-design.md), [010](010-review-loop-explicit-ux-design.md)
**Source:** author request, prompted by [makinux/adversarial-panel](https://github.com/makinux/adversarial-panel) (MIT) and its design essay, ["adversarial-panel:多モデル敵対的レビューという品質保証"](https://x.com/wayama_ryousuke/status/2075147624806813800) (Ryousuke Wayama, 2026-07-09). **We take its insight, not its architecture** — see *What we took, and what we did not*.
**Target version:** `review-loop` 0.4.0 → 0.5.0

## What this changes, in one paragraph

`review-loop` assumes its reviewers. `codex` on `PATH` and an authenticated `gh` happen to exist on the author's machines; on anyone else's the loop quietly degrades to Claude alone and still reports "gate clean". This spec adds **`/review-loop:init`**, which discovers what a host can actually field and records the author's choice — so the strategy is picked per environment rather than baked into the skill. It then teaches the loop to use more than one reviewer *properly*: they answer **blind and in parallel**, before any fix, and the verdict says which panel actually ran.

That is the whole change. The tiers, the auto-fix rules, Phase B, the sandbox routing, the embedded-diff form and the `command_execution` detector are untouched. One thing inside the blind round does move: Codex's first pass switches from the targeted native form to the prompt-bearing freeform form, because a blind round needs a prompt (§B.1) — its sandbox routing and detector are unchanged, only which `review` invocation R1 uses.

## Two hypotheses, and they are not equally strong

Both come from the same observation — a second look catches what the first missed — but they claim different mechanisms, and they deserve different confidence.

### Strong: more passes is more thinking

A fresh pass over the same artifact finds real defects, **even by the same weights**. Spending inference on another look is spending space to buy reasoning; a reviewer that has not seen its own earlier reasoning is, in effect, a longer chain of thought with a clean context.

We have direct evidence. In this project's own review history, same-family reviewers — a different Claude model, and in one case *the same model* — found: a false premise the design rested on for three sections; an entire class of regression-test weakness nobody else saw; four weak test anchors; and a missing licence attribution. None of that required a different model family.

**This is the load-bearing hypothesis.** It is why the loop reviews more than once, and why an author with no second CLI is not out of luck.

### Weak: different families catch different holes

`adversarial-panel` argues that reviewers only catch what the generator missed when their **failure modes differ** — that a same-family panel shares blind spots, so its agreement is weaker evidence than it looks. The argument is sound, **and we adopt it as a reason to *offer* a cross-family reviewer — never as a reason to *demote* a same-family one.** A cross-family voice adds something; it does not subtract from what same-family multi-pass already delivers. **The argument is also unmeasured**, here and there.

What our record actually shows is narrower and less flattering to the theory. Cross-family reviewers (`codex`, GitHub Copilot) found a distinct class: **states nobody had run** — what happens after the branch merges, on a host with no local `main`, with a flag missing from one sample command, with an authenticated `gh` and no config. Same-family reviewers all ran the suite where it was already green. That is a difference in *where they looked*, which decorrelation predicts but does not uniquely explain.

**So heterogeneity is a bonus, not a gate.** Nothing in this spec requires a cross-family reviewer, refuses to auto-fix without one, or blocks a clean verdict on its absence. What the loop does instead is **say which panel ran** — as disclosure, not a ranking — so a reader knows whether the cross-family perspective was exercised this run, and `init` makes it easy to add one when the host has it. Same-family passes are never discounted for it; they are the strong hypothesis, and they earn their place.

### What follows from grading them honestly

- The loop **reviews in parallel and blind** whenever it has more than one reviewer. That serves the strong hypothesis and costs nothing.
- The loop **does not require** an adversary before it may act. Reproduction, not disagreement, is what makes a finding actionable — and that was already true in 0.4.0.
- The verdict **names the panel** as disclosure, not a ranking. Same-family review is never reported as a downgrade — it is the strong hypothesis at work; the verdict notes only whether the cross-family decorrelation bonus was exercised this run.
- Cross-critique — showing each reviewer the others' findings and asking them to attack — is **available and recommended**, not mandatory. It is a way to kill false positives cheaply. It is not a licence.

## What we took, and what we did not

`adversarial-panel` is a skill for debating **claims**: several models answer a
question blind, attack each other across rounds, and a facilitator synthesizes
agreements, live disagreements and calibrated confidence. Its author's essay makes an
argument we agree with, and builds a machine we do not need.

**What we took — the insight:**

- An LLM's answer is most dangerous when it is **confidently wrong**, and self-critique
  cannot catch that: the blind spot at generation time and at critique time come from the
  same weights. A model reviewing its own diff is an audit with a conflict of interest.
- Therefore a reviewer must not see the first reviewer's output before forming its own.
  That is the whole of our §B.1.
- **Refute by reproduction, not by assertion.** "This fails on input X", not "I doubt this".
- Its five named failure modes, as a checklist we test ourselves against: *ghost panelist*,
  *sycophantic convergence*, *facilitator capture*, *confidence theater*, *diversity
  illusion*.

**What we did not take — the architecture:**

- Its role split (facilitator + panelists), its Round 0 triage, its Rounds 1–3, and its
  synthesis output format. `review-loop` already has a shape: reviewers, tiers, an author
  who decides, a forge phase.
- Cross-critique as a **mandatory round** (their Round 2 of 4, where agreement without new
  argument is a *failed* round). We make it optional and gate nothing on it: a round that
  refutes nothing is a legitimate outcome, and forcing an attack manufactures a refutation
  when the other reviewer is right.
- Its **required** confidence contract — but not as a gate, because *they do not gate on it
  either*. adversarial-panel demands a confidence **and** a falsification condition on every
  key claim (Round 3, synthesis), inseparably, and treats confidence as a calibration
  instrument that "gates nothing explicitly." We keep **neither as a required field**: we *ask*
  for a falsification condition and make confidence optional (§B.2), because reproduction can
  *check* a falsification condition and cannot check a confidence number — but the one thing that
  is required is not a field at all, it is that the facilitator **reproduces** before acting.
  (Gating auto-fix on `confidence == high` was a mistake in **this spec's own earlier draft**,
  not something adversarial-panel does — we removed it. The mis-attribution is worth stating
  plainly: the gate was ours.)
- Above all, a **permission system built on adversarial survival** — a finding is not
  actionable because it survived an argument. Its target is a claim, and a claim can only
  be argued with. Ours is a diff, and a diff has a runnable ground truth: where a finding is
  executable, a failing test settles what no amount of debate could.

The essay's central mechanism — decorrelated error modes — is the weak hypothesis above.
We adopted it without measuring it, and we say so rather than building a gate on it.

## Part A — `/review-loop:init`

The point of this spec. The roster is a property of the host and of the author's taste; it does not belong in the skill.

### A.1 Three kinds of knowledge

| Kind | Example | Cost | Where it lives |
|------|---------|------|----------------|
| **Presence** | is `codex` on `PATH`? | ~1 ms | re-probed **every run**, never trusted from disk |
| **Invocation** | does native `review` work here, or must the diff be embedded? | seconds — a real subprocess | learned **once by `init`**, stored |
| **Intent** | may this reviewer be used? which Claude model? which forge? | unaskable of the machine | asked by `init`, stored |

`command -v codex` is free, so caching its answer buys nothing and goes stale. But **knowing a CLI exists tells you nothing about how to drive it**: on the author's Ubuntu host `codex` and `bwrap` are both present and native `codex exec review` still cannot read the tree, because `bwrap-userns-restrict` blocks it. No amount of `command -v` reveals that; one real call does.

### A.2 What `init` probes

`command -v` over a candidate list, run inline. **No script.** A shipped script must encode something an agent would get wrong or skip — `copilot.sh`'s GraphQL bot-id dance, `pr-comments.sh`'s pagination, `sandbox-preflight.sh` actually building a sandbox. A `command -v` loop is none of those, and wrapping it calcifies a decision a stronger model will make correctly unaided.

```bash
for cli in codex gemini cursor-agent opencode aider crush amp llm gh; do
  command -v "$cli" >/dev/null 2>&1 && echo "$cli present" || echo "$cli absent"
done
```

`gh` is in the list because Phase B's built-in adapter is offered on its presence. **Presence of `gh` is not authentication** — `SKILL.md` needs "the authenticated `gh` CLI", and a host with an unauthenticated `gh` would otherwise enroll a reviewer that can neither request nor poll. Authentication is a real call, so it belongs to calibration.

Versions are `init`-only. `<cli> --version` spawns a subprocess per CLI and only drift detection needs it; a review must not pay for that.

### A.3 What `init` verifies by trying

**Detecting that `codex` exists is not the same as knowing how to call it.** After the probe, `init` *uses* each enrolled CLI once, on a throwaway fixture, and writes down what actually worked.

For `codex`, the machinery already exists — `sandbox-preflight.sh` and the post-round `command_execution` detector. `init` runs it deliberately rather than rediscovering it mid-review: preflight, then one real `codex exec … review`, then the detector. Record the form that produced a real review (`native` or `embedded`), and the literal command line, verbatim.

For **any other CLI**, there is no prior recipe and `init` must not pretend to one. It works it out, bounded and out loud: a review-like subcommand? a read-only mode? a prompt on stdin? does it return in the foreground, or fork and exit — the ghost-panelist manufacturer? Four rules keep this from becoming an unbounded excursion:

- **Bounded.** Two attempts per CLI, then stop. A CLI whose invocation cannot be established is **detected but not enrolled**, with the reason shown. Never enroll a reviewer you have not successfully called.
- **Read-only, throwaway target.** A temporary fixture under `$TMPDIR`, never the user's working tree. Calibrating an unenrolled third-party CLI on real changes ships the author's code to a service they have not agreed to enroll.
- **Consented.** `init` says what it is about to run, before it runs it. For a forge CLI that includes one authenticated call (`gh auth status`).
- **Transcribed, not summarized.** Store the command line that worked. "codex works" is not a recipe; `codex exec --json --sandbox read-only review -` is.

**`embedded` is not a degradation.** The diff goes in the prompt, no sandbox is involved. A host that routes there is configured, not broken, and the loop never narrates the preflight verdict on a normal run. If native is blocked and fixable, `init` may point once at `references/codex-sandbox-host-fixes.md` — and stop. Restoring the native path is an AppArmor/sysctl change affecting every `bwrap` caller on the machine: **separate work the author owns**, never a precondition, and the skill never asks for `sudo`.

### A.4 What `init` asks

A reviewer plays one of two **roles**, split by cost. `init` asks for both, and makes the cost trade-off explicit rather than burying it. **Neither role adds a sub-command** — both run under the ordinary `/review-loop`; the roles differ only in *when* a reviewer is spent (§B.7).

- **The routine panel** — the reviewers that run on **every** review, blind and in parallel. `init` offers, and the author composes freely from, what this host can field: the **session's own model** (a fresh-context pass — the strong hypothesis, free on any host), **one or more *other* Claude models** (e.g. Sonnet alongside an Opus session), and **`codex`** (a different family, actually called). A realistic answer is several at once — *Opus + Sonnet + gpt-5.5* — not a single pick. Same-family members are first-class here, not a fallback: they are the extended-chain-of-thought lever, and this project's history shows them finding real defects.
- **The direction guard** — an **expensive, heavyweight** reviewer (a strong model like **Fable**) the author does *not* want on every round. `init` asks which model, if any, plays it. It is not a separate command and not a separate job invoked by hand: the ordinary loop **proposes** spending it when the escalation rule fires (§B.7) — before a design artifact is finalized, or when the routine panel has gone clean without a runnable check behind it. Too costly for every round; exactly right at those inflection points. (This is the role Fable played for spec 014 itself.)
- **Offered, default off:** any other detected coding CLI, as a routine-panel member. Each brings its own auth, sandbox and timeout semantics and none has a `review` subcommand, so the diff must be embedded. Highest ghost-panelist risk.
- **Never discovered, only declared:** an OpenAI-compatible endpoint. If the author wants one they name it; where the name is an alias in the `chat-subagent` registry the entry is marked `via: chat-subagent` and **the url and `api_key_env` stay in that plugin's files**. A local 7B model enrolled as a reviewer is noise, not insight — this stays opt-in, per endpoint.
- **Forge reviewer:** GitHub Copilot is the one **built-in** adapter and **needs no enrollment** — a GitHub PR with an authenticated `gh` and `jq` reaches it exactly as before. Enrollment is how you add a *declared* reviewer on another forge, or opt out of Copilot. Other forges have review agents; this skill names none and implements none, because an adapter nobody here can run would poll forever or report a clean pass that never happened.

`init` is **idempotent**. Re-running re-probes, re-verifies an invocation only when the CLI's version changed or its recipe failed at run time, prints a diff of what changed, and preserves explicit opt-outs (`enabled: false` is a decision, not an absence).

### A.5 Where the config lives

Machine-scoped, uncommitted, and **outside the plugin directory** — `plugins/review-loop/` is the install boundary, so anything written there is lost on the next update. Follow the resolution order `chat-subagent` already established in this repo:

1. `<project-root>/.claude/review-loop.local.md` — per-project overrides
2. `~/.claude/review-loop.local.md` — global defaults

Each reviewer carries a `role`: `routine` (every review) or `direction` (spent only when the escalation rule fires, §B.7). A realistic roster has several routine members and at most one direction guard:

```markdown
---
review-loop-config: 1
panel:
  # routine — run on every review, blind and in parallel
  - id: opus                     # the session's own model, fresh context
    kind: claude-model
    model: opus
    role: routine
    enabled: true
  - id: sonnet                   # a different Claude model (same family)
    kind: claude-model
    model: sonnet
    role: routine
    enabled: true
  - id: codex                    # a different family, actually called
    kind: cli
    role: routine
    enabled: true
    invocation:
      form: embedded
      command: "codex exec -m gpt-5.5 --json --sandbox read-only -"
      why: "preflight=broken; a native review ran 0 command_execution items"
      verified_with: "codex-cli 0.139.0"
  # direction — expensive; the ordinary loop proposes it at an escalation point (§B.7),
  # never a separate sub-command, never every round
  - id: fable
    kind: claude-model
    model: fable
    role: direction
    enabled: true
  - id: deepseek                 # user-declared; init never discovers endpoints
    kind: endpoint
    role: routine
    via: chat-subagent
    alias: deepseek
    enabled: false
---

## Notes
Free-form: why a panelist is disabled, host quirks, the literal command line `init` verified.
```

**No secrets, ever.** Endpoints carry a name, never a url and never an `api_key_env`.

### A.6 Reconciliation at loop start, surfaced not followed

The probe runs; the config is compared to it. Three cases, each said out loud **once**:

- **Enrolled but absent** — note it, and reflect it in the panel the verdict names. Never a silent skip: a reviewer the author asked for and did not get is not the same as one they never wanted.
- **Present but unenrolled** — `codex` installed after `init` ran. Note it once, point at `/review-loop:init`. Do **not** auto-enroll; enrollment is the author's decision.
- **Recipe drift** — the CLI's version differs from `verified_with`, or the preflight contradicts the recorded `form`. The recipe is a **learned default, not gospel**: preflight and the detector still run and still win. Follow this run's evidence; suggest re-running `init`. **A recipe never suppresses a detector.**

And one that is not about presence: if a routine Claude reviewer's model equals the model the session is already running, that reviewer is the session's own weights with a fresh context. That is genuinely worth having — the strong hypothesis says so — and the verdict names it accurately (a fresh pass, not a distinct model) without treating it as lesser (§B.3).

### A.7 With no config, nothing changes

`SKILL.md` advertises itself as self-contained and portable. With no config the loop fields the same roster it always did — Claude subagent, `codex` if present, Copilot for GitHub PR targets — and mentions once that `/review-loop:init` can enroll more. **`init` is never a precondition and never blocks.**

## Part B — using more than one reviewer properly

Three changes. None of them alters the Tiers rules, the auto-fix behaviour, Phase B, or the merge policy.

### B.1 Blind and parallel, before any fix

Today: the Claude subagent reviews, its fixes are committed, and only then does Codex read the **already-fixed tree**. Codex can never dispute Claude's reading of a finding, because it never saw what Claude saw.

New: every live reviewer reviews the **same unfixed diff**, in parallel, and **no reviewer sees another's findings**. Fixes are applied after all have reported.

This is the one idea worth taking from `adversarial-panel`, and it costs nothing: the reviews were going to happen anyway. A reviewer that has already seen another's findings is not a second opinion, it is an editor.

Two consequences worth stating:

- **Post the findings as they land**, marked *not yet actionable*. The independence rule binds reviewers, not the author. Making the author wait through parallel silence buys nothing.
- **Codex's R1 must carry a prompt.** A target flag takes none (`review --uncommitted -` errors rc=2), and the prompt is where the finding record is requested. So R1 uses the **freeform** native form, `codex exec --json --sandbox read-only review -`, and names the range `<base>...<head-sha>` in prose. Freeform infers its own diff, which is dangerous in a blind round — so the prompt asks the review to state the range and file list it actually reviewed, and the facilitator checks that against `git diff --name-only "$base"..."$head"`. Mismatch → re-run once with the diff embedded, which cannot be inferred wrong. The targeted `review --base` form keeps its home in B3, where no prompt is needed.

### B.2 Findings are asked for a falsification condition — reproduction is what is required

Reviewers are **asked** to state, with each finding, **what would show it is wrong**: a concrete, checkable condition — "not a bug if `cfg` is non-null at every call site", "not a defect if line 152 does not already contain the word". A generic condition — "if evidence emerges to the contrary" — carries no information; treat it as absent.

But **the absence of a falsification condition gates nothing** — it is not a required field on the finding record, and no finding is refused, downgraded, or auto-fixed on the strength of having one. The load-bearing rule is one step up and already ours: **the facilitator reproduces a finding before acting on it.** The falsification condition is just the thing reproduction *checks*, and a reviewer who names it up front saves the facilitator from reverse-engineering what they meant. Where the reviewer leaves it out, the facilitator reproduces anyway. This is a request, not a contract — codifying it as *required* would be new machinery the roster split does not need.

A reviewer may also give a confidence. It informs the author and nothing else. Confidence is a self-report by the same weights that produced the finding; it authorizes no action on its own, and the facilitator **never imputes either field** — neither a confidence nor a falsification condition — onto another reviewer's finding.

Prose targets have no failing test, so reproduction there is a **citation the facilitator verifies with a command** — a quotation, its location, and a `grep`. "A reader can check it" is a capability, not a check.

### B.3 The verdict names the panel that actually ran

"Local gate clean" is not one verdict. **Name the panel that ran** — this is disclosure, not a ranking, and same-family review is never reported as a downgrade. Every member is a real contribution: multiple passes, same family or not, are the strong hypothesis at work, and this project's history shows same-family reviewers finding a false premise the design rested on, a whole class of test weakness, and four weak anchors. What the verdict adds is one honest note about **what was and was not exercised this run**:

- **A cross-family reviewer ran** (a coding CLI alongside Claude) → the decorrelation bonus was exercised: agreement across families is less likely to share a blind spot.
- **The panel was all one family** (Claude models only, however many) → say so plainly, as a fact, not a demerit. The multi-pass value is real and delivered; what a cross-family voice *would* have added — the decorrelation bonus — simply was not exercised this run. That is a note for the reader, not a verdict of "weaker".
- **Only the session's own model ran** (no other reviewer enrolled or reachable) → still a genuine second pass with a fresh context; note that no second reviewer participated, so the author can add one via `/review-loop:init` if they want.

Report what **actually ran, verified**: the CLIs that returned findings, and the models that actually *differed* from each other and from the session. Each Claude subagent's brief asks it to state its model id on the first line; that is a self-report and a weak check, and better than asserting composition from a config field. **Where a check is weak, report the verdict it supports and no stronger** — but never let a weak check *downgrade* a same-family pass. A user-declared endpoint does not count as a cross-family voice for the note above, whatever the config says.

### B.4 Cross-critique: recommended, never required

With two or more reviewers, showing each the others' findings and asking them to attack is cheap and it works: in this project's own review it killed two overclaims and one false positive before either became a commit. Ask for the claim they **tried hardest to break**, and whether it held — never "you disagree with at least one central claim; find it", which manufactures a refutation when the other reviewer is right.

But it **gates nothing**. A finding is actionable when it is reproduced, not when it survives an argument. Disagreement about executable code is settled by a test, not by another round.

### B.5 A review that is not a review

A status line, an empty result, or an error dump is **not a contribution**. If it enters the record, the loop reasons about thin air.

- **Codex, native path:** the existing structural detector, unchanged — a native round that ran zero `command_execution` items never read the tree.
- **Every other reviewer:** the return must be a substantive review, or an explicit "no remaining problems". Re-run once; on a second failure **drop the reviewer, continue, and disclose** which panel actually ran.
- **External CLIs run in the foreground** with a generous timeout. A wrapper that backgrounds the call and returns early manufactures ghosts.

### B.6 The facilitator is also a reviewer, and must not act like one

The facilitator frames, dispatches, validates and fixes — and it is also the Claude subagent's model. It may not put its own arguments in another reviewer's mouth.

- Findings are **attributed** in the round output; a reviewer's wording is preserved **verbatim**.
- The facilitator's own observations go in a labelled section that gates nothing.
- **Merged duplicates keep both texts and both attributions.** "These two are the same issue, I'll keep one phrasing" is laundering. Two reviewers slicing one problem differently are not agreeing.
- Tiering (T1/T2/T3) stays the facilitator's judgement — scope-of-fix is not something a reviewer can assess for a repo it does not own.

### B.7 When adversarial review is the point, and when looping is enough

The routine panel runs every review. The **direction guard** — the expensive, cross-family or heavyweight reviewer — is spent only when the work needs decorrelation, and one axis decides that: **does the finding have a runnable ground truth?**

- **It does** — a test, a `grep`, `fxrank`, a type check can settle it. Then **just keep looping.** Reproduction is the judge, and the reviewer's model family is irrelevant: a stale restatement, a broken `grep`, an unbalanced fence, a missing anchor all get caught by another pass with clean context. This is the strong hypothesis, and same-family multi-pass converges here without any adversary. Bringing in a different family buys little, because the check already decides.
- **It does not** — the correctness is a *judgement*: a design, a premise, an API shape, a security argument, whether an abstraction earns its place. No test closes this, so all you can get is another judgement — and a same-family judgement inherits the generator's priors, blind where it is blind. **This is where the direction guard earns its cost.**

The axis decides whether escalation is even on the table; it does not decide by itself that the spend is worth it. **All three of the following presuppose that no check settles the finding** — a green check takes the finding off the table before any of them apply. Within that region, when one holds, the loop **proposes** (never auto-runs, never a new command) spending the direction guard, and the author says yes or no:

1. **No runnable ground truth** — the artifact is design/prose/premise, not something a check adjudicates. (A spec like this one is almost always here.) This is the axis itself; the other two are reasons the spend is worth it *within* it.
2. **High or irreversible cost of being wrong, with no check to settle it** — shared code with many consumers, a merge gate, an outward-facing change, or a spec the downstream all depends on. When judgement is all you have *and* a wrong judgement is expensive, the asymmetry justifies spending the unmeasured decorrelation bonus. (A passing check that does not cover the risk is not ground truth for that risk — the finding is still in this region.)
3. **Converged without proof** — the routine panel has gone clean, but "clean" rests on judgement, not a green check. Same-family agreement with nothing runnable behind it is the diversity-illusion danger zone: they may be blind *together*. Here convergence is not a done signal — it is precisely the signal to let a decorrelated reviewer try to break it.

Conversely: when "clean" is backed by a passing check, **stop — do not escalate.** The ground truth has already ruled, and a different family adds noise, not signal. The default is to loop; adversarial review is the exception the triggers name, not the routine.

- **It does not require an adversary.** No gate turns on disagreement. The weak hypothesis is not strong enough to build a permission system on, and reproduction was already the thing that made a finding actionable.
- **It does not change the Tiers rules**, the auto-fix behaviour, Phase B's steps, the sandbox routing, the embedded-diff form, the `command_execution` detector, exit-code triage, or the never-merge rule.
- **It does not invent a status ladder.** A finding is raised, reproduced, or not reproduced. That is enough.
- **It does not name a forge reviewer we cannot run.** The slot is generic; one adapter ships.
- **It does not ship a new script.** The presence probe is prose the agent runs.
- **It does not add a sub-command.** The direction guard runs under the ordinary `/review-loop`, proposed at an escalation point — there is no `/review-loop:direction`.
- **`init` is not a precondition.** The zero-config loop keeps working.

## Testing

`SKILL.md` and the command docs are prose — a system prompt, where **wording is behavior and a runnable sample is an instruction**. Guard them with content anchors in `tools/review-loop/test-skill-content.sh`, which has exactly two helpers, `need` and `refute`, and **no git**.

**An anchor's strength is that it quotes the rule, not that its phrase is new.** `need 'blind'` is weak: delete the blind-review rule and two "blind spot" metaphors keep it green. `need "no panelist sees another's findings"` is strong, because the phrase *is* the rule. Three ways to get this wrong, all observed:

| Weak because it matches… | Example | What to anchor on instead |
|---|---|---|
| a common word | `blind`, `survived` | the imperative clause |
| a section heading | `After convergence` | a sentence from the body |
| a summary of the rule | the frontmatter `description` | text that only the rule contains |

**No script can check this.** The property is "does an edit exist that removes the rule and keeps the regex matching", and finding that edit is a search. So it is checked by the reviewers: **for each anchor, construct the minimal edit to `SKILL.md` that deletes the rule while leaving the regex matching. If such an edit exists, the anchor is weak.** Every weak anchor this project has found was found that way, by a reviewer, reproduced on a scratch copy — never by a helper.

The trade, stated plainly: nothing mechanical now rejects an anchor that was vacuous the day it was written. `need 'confidence'` against a file that already contains the word will pass. The mitigation is the same one this spec demands everywhere else — **run the grep before claiming the anchor is meaningful**, and let a reviewer try to defeat it.

**Manual verification:**
- `/review-loop:init` on a host with only `codex` → enrolls `codex` as a routine reviewer, asks which Claude models fill the routine panel and whether any model plays the direction guard, offers nothing else, writes `~/.claude/review-loop.local.md`.
- Re-running `init` → a no-op diff; an `enabled: false` opt-out survives.
- Delete the config → the loop fields the same roster as 0.4.0 and hints at `init` once.
- Enrolled `codex` removed from `PATH` → the loop says so, and grades the verdict.
- Two reviewers → they review the same unfixed diff, neither sees the other, and the verdict names both.
- Claude-only → the verdict says *fresh-context only*, and does not pretend otherwise.

## Acceptance criteria

- [ ] `/review-loop:init` exists, is idempotent, re-probes every run, and preserves explicit opt-outs.
- [ ] `init` probes coding-CLI presence with `command -v` — no new script, no network, no credential read. It then **verifies invocation by calling** each enrolled CLI once, on a throwaway fixture, bounded to two attempts, storing the literal command line. A CLI whose invocation cannot be established is **detected but not enrolled**, with the reason shown.
- [ ] Presence of `gh` is not authentication; the built-in Copilot adapter needs **no enrollment**.
- [ ] `init` never asks for `sudo` and never changes the host.
- [ ] With no config, the loop behaves exactly as 0.4.0 and hints at `init` once.
- [ ] Enrolled-but-absent, present-but-unenrolled, and recipe drift are each surfaced once, never silently followed. A stored recipe never suppresses the preflight or the detector.
- [ ] With more than one reviewer, all review the **same unfixed diff**, in parallel, and none sees another's findings. Fixes land after all have reported.
- [ ] Codex's first round uses the prompt-bearing freeform form, names `<base>...<head-sha>`, and the facilitator checks the echoed file list against `git diff --name-only`.
- [ ] Reviewers are asked for a falsification condition, but its absence gates nothing — it is not a required field. The required rule is that the facilitator reproduces a finding before acting on it. Confidence, when given, authorizes nothing; the facilitator never imputes either field.
- [ ] The verdict names the reviewers that actually ran as disclosure, **never as a downgrade of same-family review**; it notes only whether a cross-family reviewer was exercised this run.
- [ ] `init` asks for the roster as two **roles** — a **routine panel** (several reviewers, e.g. Opus + Sonnet + gpt-5.5, every review) and an optional **direction guard** (an expensive model like Fable). Both run under the ordinary `/review-loop`; the direction guard adds **no sub-command** and is spent only when the §B.7 escalation rule fires.
- [ ] The escalation rule (§B.7) turns on **runnable ground truth**: when a check can settle the finding, keep looping; when it cannot (design/premise), or the cost of being wrong is high, or the panel converged without a green check, the loop **proposes** the direction guard — never auto-runs it, never adds a command. When "clean" is backed by a passing check, it does not escalate.
- [ ] Cross-critique is documented as recommended and gates nothing.
- [ ] A non-substantive reviewer return is re-run once, then dropped with disclosure. The `command_execution` detector is unchanged.
- [ ] The Tiers rules, auto-fix behaviour, Phase B steps, sandbox routing, embedded-diff form, exit-code triage and never-merge rule are unchanged.
- [ ] `tools/review-loop/test-skill-content.sh` has exactly two helpers and no git. Every new anchor quotes the rule it guards, and each is shown to fail when that rule is deleted.
- [ ] `review-loop` is `0.5.0` in `.claude-plugin/marketplace.json`. Neither `plugins/review-loop/.claude-plugin/plugin.json` nor `SKILL.md`'s frontmatter carries a `version` field (versioning lives only in `marketplace.json`). The **short manifest description** must be **identical** between `plugin.json` and the `marketplace.json` entry; `SKILL.md`'s frontmatter `description` is separate, longer trigger text and need only be *substantively consistent* with them, not identical.
- [ ] `references/why-adversarial.md` credits `makinux/adversarial-panel` (MIT), separates the insight we took from the architecture we did not, and names the claim we adopted without measuring.
