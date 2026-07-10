# 014 — review-loop: reviewer roster (`/review-loop:init`) + adversarial panel protocol

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [002](002-review-loop-plugin-design.md), [003](003-review-loop-headless-codex-design.md), [009](009-review-loop-codex-sandbox-fix-design.md), [010](010-review-loop-explicit-ux-design.md)
**Source:** author request, prompted by [makinux/adversarial-panel](https://github.com/makinux/adversarial-panel) (MIT) and its design essay, ["adversarial-panel:多モデル敵対的レビューという品質保証"](https://x.com/wayama_ryousuke/status/2075147624806813800) (Ryousuke Wayama, 2026-07-09)
**Target version:** `review-loop` 0.4.0 → 0.5.0 (behavior change)

## Motivation

`review-loop` already runs more than one reviewer, which is most of the way to
the right idea. It gets two things wrong about *how* they run, and one thing
wrong about *who* they are.

**Self-review is a conflict of interest.** An LLM's answer is most dangerous
when it is confidently wrong, and a model asked to critique its own output
draws its critique from the same weights that produced the blind spot. The
`adversarial-panel` skill names the two properties that make multi-reviewer
setups actually work, neither of which follows from merely having more than
one reviewer:

- **Decorrelation** — a reviewer only catches what the generator missed when
  their failure modes differ. Same-family panels share blind spots, so
  confident convergence is weaker evidence than it looks.
- **Verification advantage** — refuting a claim is cheaper than producing one.
  Point reviewers at *verifiable* claims and make them refute by reproduction
  ("fails on input X"), not by assertion ("this looks wrong").

Against that standard, the current loop has four gaps:

1. **Reviewers are serial gates, not adversaries.** 0.4.0 §A1 has Claude review,
   apply fixes, and commit; 0.4.0 §A2 then has Codex review the *already-fixed* tree.
   Codex never sees the pre-fix diff, so it can never dispute Claude's reading
   of a finding or its choice of fix — it is anchored on Claude's output. The
   two reviewers also never critique *each other's findings*, which is where a
   heterogeneous panel earns its cost: cross-critique kills false positives
   before they turn into commits.
2. **Facilitator capture is unguarded.** Claude is simultaneously a panelist
   (the 0.4.0 §A1 subagent) and the facilitator (it tiers findings, relays Codex's
   review, drafts approaches, applies fixes). Nothing prevents it from quietly
   downgrading a Codex finding it disagrees with, or presenting its own opinion
   as the panel's. Attribution exists only in the review journal, not in the
   round output the author reads.
3. **The panel is same-family by default.** The 0.4.0 §A1 subagent is Claude
   reviewing Claude's own diff, decorrelated by fresh context but not by
   weights. The `Task` dispatch does not set a `model`, so the free
   heterogeneity upgrade (review under a different Claude model) is unused. And
   "local gate clean" is reported identically whether Codex participated or
   not, even though those two verdicts carry very different evidential weight.
4. **Convergence prompts invite agreement.** 0.4.0 §A2 resumes with `"I applied these
   fixes: <summary>. Are your earlier points resolved?"` — a leading question
   that asks Codex to accept *Claude's own summary of Claude's own fixes* as
   evidence. Sycophantic convergence (agreement without a new argument) is the
   expected failure.

**And the roster is assumed, not discovered.** `codex` and an authenticated
`gh` happen to exist on the author's machines. On someone else's, the loop
silently degrades to Claude-only — which is exactly the same-family weak-evidence
case above, reported as if it were a clean gate. The loop should know which
reviewers this host can actually field, and say so.

Two parts, in dependency order. Part A gives the loop a roster and a way to
learn what this host can actually do. Part B makes the reviewers on that roster
adversaries rather than a queue.

Where review-loop is **already ahead of** `adversarial-panel`, we keep what we
have and say so: the 0.4.0 §A2 post-round `command_execution` detector is a
*structural* validation gate (a native round that ran zero commands never read
the tree), strictly stronger than the panel's text-marker check for the same
failure — and the "never a silent clean" rule is exactly the panel's
"disclose the tier that actually ran".

## The governing principle: the skill encodes no environment

`review-loop` 0.4.0 is written around one person's machines. `codex` is assumed
on `PATH`; GitHub Copilot is hardcoded as *the* remote reviewer, with `gh` and
GraphQL baked into Phase B; the Codex invocation is a fixed recipe that happens
to suit the author's sandbox. Every one of those is a fact about a host, not
about reviewing.

Three rules follow, and they constrain everything below:

1. **Nothing is assumed present.** Reviewers, forges, models: all *enrolled*,
   never presumed. A host with no `codex` and no forge is a first-class case.
2. **Nothing is assumed callable.** Knowing a CLI exists does not tell you how to
   drive it correctly. `init` **verifies by trying** (§A.3) and records what
   actually worked, rather than shipping a recipe that works on one laptop.
3. **Nothing ships that we cannot exercise.** Other forges have their own review
   agents; we neither name nor implement them, because an adapter no one here can
   run is a ghost reviewer at the forge level — the §B.7 anti-pattern, one layer
   up. We ship the **slot**, plus the one adapter (GitHub Copilot) whose scripts
   already exist and are tested. Anyone with access to another forge's reviewer
   declares it and supplies its commands (§A.4).

## The second principle: never trust a model where a check can run

A model's capability drifts — new versions, changed defaults, a provider's quota,
a sandbox policy shipped by an OS update. None of it is under this skill's
control. So wherever a claim can be **checked by running something**, the skill
runs it and believes the result; wherever it cannot, the claim goes to the author.
Model judgement is never the last word on a question a command could settle.

This spec has already violated its own principle three times, in the same way:

- Round 0 proposed `need 'confidence'` as a regression anchor. `SKILL.md:152`
  already contains "treat a bare `confidence is low` as a non-review". The anchor
  passes against the *unmodified* file.
- Round 1 then proposed `need 'invocation'` (`SKILL.md:119` — "a `review`
  invocation") and `refute '^## Phase B — GitHub Copilot'` (the real heading is
  `### Phase B`, so the regex never matched and the refute always passed).

Three vacuous anchors, each asserted by a model that had not run `grep` against
the file it was making a claim about. The fix is not to correct three regexes. It
is to **make the harness prove novelty**: an anchor guarding a new behavior must
*fail* against the pre-change `SKILL.md`, and the harness can check that itself
(§ Testing, `need_new`). A test that cannot fail is not a test.

The same rule decides several open design questions below, and it decides them
against the more flattering answer:

- A reviewer's `confidence` is a self-report and authorizes nothing (§B.4).
- A prose finding's citation is auto-fixable only when *both* the quote's existence
  **and** the fix are mechanically checkable (§B.5). "I quoted a passage and I
  say it contradicts" is model judgement wearing evidence's clothes.
- `init` verifies a CLI by calling it, not by recognizing its name (§A.3).
- The gate reports the panel that ran, verified — the model that actually differed,
  the CLI that actually returned findings (§B.9).

Where no check exists — *is this contradiction real? is this abstraction right?* —
the answer is surfaced to the author. That is not a limitation to be engineered
away. It is the line between what the loop may do alone and what it may not.

### Its corollary: materialize critical knowledge only

"Run a check instead of trusting a model" is not "wrap everything in a script". The
two rules pull in opposite directions and the tension is the point.

**A shipped script earns its keep by encoding something the agent would get wrong, or
would find tedious enough to skip.** `copilot.sh` earns it: the GraphQL bot-id dance
and the first-review 422 are knowledge nobody rediscovers pleasantly. `pr-comments.sh`
earns it: silent single-page truncation. `sandbox-preflight.sh` earns it: it actually
builds a sandbox. The `command_execution` jq predicate earns being written down,
because it has been mis-transcribed (`.item.type`, not `.type`) and its *rationale* was
wrong in this spec's own first draft.

A `command -v` loop earns nothing. Wrapping it buys a maintenance burden, a test, and
a JSON schema whose only consumer is an agent that could have read the plain output.
Worse, it **calcifies** — the models reading this skill get more capable every year,
and a script is a decision frozen at the moment it was written. Prose the agent
executes adapts; a script the agent calls does not.

So: **materialize the knowledge that is critical and easily lost. Leave the rest as
prose.** When unsure, ask what a stronger model six months from now would need told —
not what today's model finds convenient.

**Notation.** `0.4.0 §A1` / `0.4.0 §A2` name steps of the *current* `SKILL.md`
Phase A. The *new* pipeline's steps are `A0`–`A4` in §B.2's diagram, and its
rounds are `R1` (blind) / `R2` (cross-critique) / `R3` (final positions, ≥3
panelists only). An unqualified `§A.n` is a section of this spec.

## Part A — Reviewer roster and `/review-loop:init`

### A.1 Scope: probe presence cheaply, verify invocation once, ask for the rest

Three kinds of knowledge, three homes. Conflating them is what makes a config
either useless or a stale cache.

| Kind | Example | Cost | Where it lives |
|------|---------|------|----------------|
| **Presence** | is `codex` on `PATH`? | ~1 ms | probed **every run**; never trusted from disk |
| **Invocation** | does native `review` work here, or must the diff be embedded? is `-m` needed? | seconds — a real subprocess | learned **once by `init`**, stored as a recipe (§A.3) |
| **Intent** | may this reviewer be used, at which tier? which forge reviewer? which Claude model? | unaskable of the machine | asked by `init`, stored |

`command -v codex` is free, so caching its answer buys nothing and goes stale the
day another CLI is installed. But **knowing a CLI exists tells you nothing about
how to drive it**: on this author's Ubuntu host `codex` is present, `bwrap` is
present, and native `codex exec review` still cannot read the tree, because
`bwrap-userns-restrict` blocks it — the loop must embed the diff in the prompt
instead. No amount of `command -v` reveals that. It costs one real call to find
out, which is exactly the kind of thing worth doing once and remembering.

So the config records **intent + a verified invocation recipe**, and nothing that
a millisecond of `command -v` can re-derive.

The runtime contract follows directly (§A.6): the config says *"you may use X at
tier N, and here is how X is actually called on this host"*; the run says *"X is
here right now"*. When they disagree, the loop **surfaces the drift and points at
`/review-loop:init`** — it never silently follows a stale config.

### A.2 What `init` probes

**No script.** The probe is `command -v` over a candidate list, run inline:

```bash
for cli in codex gemini cursor-agent opencode aider crush amp llm gh; do
  command -v "$cli" >/dev/null 2>&1 && echo "$cli present" || echo "$cli absent"
done
```

An earlier draft shipped this as `scripts/panel-detect.sh`, emitting JSON. It should
not exist. A shipped script earns its keep by encoding something an agent would get
wrong or find tedious — `copilot.sh`'s GraphQL bot-id dance and its first-review 422,
`pr-comments.sh`'s pagination, `sandbox-preflight.sh` actually building a sandbox. A
`command -v` loop is none of those. Wrapping it buys a maintenance burden, a test, and
a JSON schema whose only consumer is an agent that could have read the plain output —
and it calcifies a decision that a more capable model will make correctly without
help. **Prefer prose the agent executes over a script the agent calls, wherever the
script would only be transcribing what the agent already knows.**

**Versions are `init`-only.** `<cli> --version` spawns a real subprocess — some coding
CLIs take hundreds of milliseconds — and only `init` needs the result (it feeds
`verified_with` drift detection, §A.6). The loop's start-up reconciliation asks
presence and nothing else.

Two groups, because they feed different enrollments:

- **Panelist CLIs** — `codex`, `gemini`, `cursor-agent`, `opencode`, `aider`,
  `crush`, `amp`, `llm`.
- **Forge CLIs** — `gh`, and any other forge client a user later declares. Their
  presence is what lets `init` *offer* a forge reviewer (§A.4). Omitting `gh` here
  while triggering Copilot enrollment on it would force the skill to re-derive
  presence outside its one specified probe.

It reads no config file, touches no network, and inspects no credentials.
**Presence of `gh` is not authentication** — the current skill needs
"the authenticated `gh` CLI" (`SKILL.md:20`), and a host with an unauthenticated
`gh` would otherwise enroll a forge reviewer that can neither request nor poll.
Authentication is a real call, so it belongs to calibration (§A.3), not here.

This answers *presence*. It deliberately does **not** answer *invocation* — that
needs a real call, a judgement about what came back, and possibly a retry under a
different form (§A.3). Both halves are agent work; neither is script work.

### A.3 What `init` verifies by trying

**Detecting that `codex` exists is not the same as knowing how to call it.** After
the presence probe, `init` *uses* each enrolled CLI once, on a throwaway target,
and writes down what actually worked. This is the one expensive thing `init` does,
and it is expensive exactly once.

For **`codex`**, the skill already knows the shape of the question and mostly
knows how to answer it — `sandbox-preflight.sh` plus the 0.4.0 §A2 post-round detector
exist for this. `init` runs that machinery deliberately instead of rediscovering
it mid-review:

1. Run `sandbox-preflight.sh` → `usable | broken | unknown`.
2. Issue one real `codex exec --json --sandbox read-only review --base <base>`
   against a trivial diff and apply the existing `command_execution` detector: a
   native round that ran zero commands never read the tree.
3. Record the form that produced a real review — `native` or `embedded` — plus
   anything the call revealed it needs: a `-m <model>` pin when the account's
   default model is unavailable, a longer timeout, `--skip-git-repo-check`.
4. **Record the form that worked and move on.** If native did not work, `init` writes
   `form: embedded` and says so once, in one line. It may add one more line — *"the
   native path can be restored; see `references/codex-sandbox-host-fixes.md`"* — and
   then it stops.

**Fixing the host is separate work, not part of this skill.** Codex's
`--sandbox read-only` uses `bwrap`, which needs unprivileged user namespaces; Ubuntu
23.10+ ships `kernel.apparmor_restrict_unprivileged_userns=1` and blocks it. Restoring
that is an AppArmor/sysctl policy change — `sudo`, system-wide, affecting every
`bwrap` caller on the machine. **A review skill does not own that decision and never
performs it as part of a review.** `init` may *suggest* it, and the author may go do
it — with an agent's help if they like — as its own task, in its own session. The
distinction that matters: **suggesting is not owning.** review-loop never gates on it,
never blocks for it, never re-raises it, and treats its absence as a configuration
rather than a defect.

**`embedded` is a supported path, not a degradation.** The diff goes in the prompt, no
sandbox is involved, and the §B.7 guarantee is inherent rather than detected. What
native buys is *ambient context* — Codex can read the code around the diff — which is
a quality gain, not a correctness gate. A host that routes to embedded is not broken
from the loop's point of view; it is configured. The loop therefore **never narrates
the preflight verdict on a normal run**. It speaks only when the verdict *changes
something the author must decide*: a recipe that stopped working (§A.6), or a native
round that turned out to be a false clean. Announcing "sandbox broken" before every
review is noise about a condition that has a recorded answer.

For **any other CLI**, the skill has no prior recipe, and must not pretend to.
`init` works it out, bounded and out loud: does it have a review-like subcommand
(`--help`)? a read-only mode? does it take a prompt on stdin? does it return in
the foreground, or fork and exit (the ghost-panelist manufacturer, §B.7)? The
resulting recipe goes in the same **structured `invocation:` block** every enrolled
CLI gets (§A.5) — *not* the free-form `## Notes` body, which the loop would have to
parse a command out of prose to use. `## Notes` is for humans; `invocation.command`
is what runs.

**The scratch target, defined.** Calibration needs a diff, and where it comes from
is a decision with a leak in it:

- **The target is a fixture, not the user's work.** `init` writes a two-line
  temporary file under `$TMPDIR`, commits nothing, and produces a diff of it with
  `git diff --no-index`. For `codex`, whose native form needs a repo, `init` uses a
  throwaway `git init` in `$TMPDIR` with one commit.
- **Never the current repo's real diff.** Calibrating an unenrolled third-party CLI
  against the user's actual changes ships their code to a service they have not yet
  agreed to enroll. The consent (§ below) is for the calibration call, not for the
  working tree.
- **It leaves nothing behind.** No branch, no commit, no file in the repo.

**Forge reviewers calibrate too.** `gh` on `PATH` proves nothing; `gh auth status`
proves it can talk to GitHub. Calibration is the one phase permitted to make that
call, and it does so with the author present. An unauthenticated `gh` means the
forge reviewer is **detected but not enrolled**, with the reason shown — never
enrolled-and-broken, discovered mid-review when a poll hangs.

Four rules keep this from becoming an unbounded agent excursion:

- **Bounded.** Two attempts per CLI, then stop and report. A CLI whose invocation
  cannot be established is **detected but not enrolled**, with the reason shown.
  Never enroll a reviewer you have not successfully called.
- **Read-only and throwaway.** Calibration reviews a scratch diff — a temporary
  commit on a scratch branch, or a `git diff` of a fixture file, in *this* repo.
  It never runs a CLI in a mode that can write to the tree, and it leaves no
  branch, commit, or file behind.
- **Consented.** Calibration runs subprocesses and, for a forge CLI, one
  authenticated call. `init` says what it is about to run before it runs it.
- **Transcribed, not summarized.** Store the command line that worked, **verbatim,
  for every enrolled CLI including `codex`** — in the `invocation.command` field
  (§A.5). "codex works" is not a recipe; `codex exec --json --sandbox read-only -`
  is. A built-in adapter is not exempt: the built-in is a *default to try*, and
  what gets stored is what actually returned a review on this host.

The recipe is a **learned default, not gospel**. The loop still runs its own
preflight at start (§A.6): a kernel or AppArmor update can invalidate a `usable`
verdict overnight, and a stale recipe that silently false-cleans is precisely the
failure mode 009 was written to kill.

### A.4 What `init` asks

`init` shows what it found, proposes an enrollment, and takes the rest from the
author. It never enrolls anything silently, and it asks nothing about a
candidate that is absent.

- **Enrolled by default:** `codex` (tier 1, cross-family CLI); a Claude subagent
  at a **different model from the session** (tier 2) — `init` asks which model.
- **Offered, default off:** any other detected coding CLI (tier 1 — the
  strongest decorrelation available, but each brings its own auth, sandbox and
  timeout semantics, and none has a `review` subcommand, so the diff must be
  embedded in the prompt; this is the highest ghost-panelist risk).
- **Never discovered, only declared:** an OpenAI-compatible endpoint as a
  panelist. If the author wants one, they say so and name it; `init` records the
  name. Where that name is an alias in the `chat-subagent` registry, the entry
  is marked `via: chat-subagent` and **the url and `api_key_env` stay in that
  plugin's files** — review-loop stores neither. A local 7B model enrolled as a
  reviewer produces **noise, not decorrelation**; the diversity illusion runs in
  this direction too, so this stays opt-in and per-endpoint.

#### Forge reviewers are a slot, not a hardcoded Copilot

Today Phase B *is* GitHub Copilot: `gh`, a GraphQL `requestReviews` mutation, and
a `generated no comments.` stop signal, written straight into the skill. That is
an adapter masquerading as an architecture. Generalize it:

- A **forge reviewer** is a reviewer that lives on the code-hosting platform,
  reachable only once the change is a pull/merge request. It has three operations:
  **request**, **poll for comments**, and **recognize a clean pass**.
- `init` offers to enroll one **when the corresponding CLI is present** — `gh` on
  `PATH` prompts *"GitHub PRs can request a Copilot review. Enroll it?"* Presence
  of the forge CLI is the trigger; enrollment is still the user's answer.
- **One adapter ships: GitHub Copilot**, because `scripts/copilot.sh` and
  `scripts/pr-comments.sh` already implement its three operations — `request` /
  `rerequest`, `fetch`, and `clean-pass` — and have been **exercised in real use**
  across many PRs. Not "tested": `tools/review-loop/` contains only
  `test-sandbox-preflight.sh` and `test-skill-content.sh`, and nothing anywhere
  tests these two scripts. The word matters, because "tested" was doing load-bearing
  work in the argument for why this adapter ships and others do not. What actually
  justifies it is that we can run it and watch it fail.
- **Other forges have review agents. This spec names none of them and implements
  none of them.** We cannot exercise what we have no access to, and an adapter
  written from documentation is a ghost reviewer at the forge level — it would
  poll forever, or report a clean pass that never happened. A user with access
  declares the reviewer and supplies its three commands; the skill drives them.
  Until someone does that, the slot sits empty and Phase B is skipped.

```yaml
forge:
  - id: copilot
    host: github
    adapter: builtin              # scripts/copilot.sh + scripts/pr-comments.sh
    enabled: true
  # A user-declared forge reviewer supplies its own commands; nothing is
  # assumed about the platform:
  # - id: <name>
  #   host: <forge>
  #   adapter: commands
  #   request:   "<command that asks the reviewer to review PR/MR $ID>"
  #   poll:      "<command that prints its comments as text>"
  #   clean_when: "<regex that matches only a clean pass>"
  #   enabled: false
```

`clean_when` is load-bearing and must be supplied by whoever declares the
reviewer: an absent or over-broad stop signal turns Phase B into an infinite
poll, or worse, a false clean. If a declared reviewer has no unambiguous clean
signal, the loop **polls, surfaces its comments, and hands the stop decision to
the author** rather than inventing one.

**How `clean_when` is evaluated, pinned — because an unpinned regex is the false
clean it exists to prevent.** The builtin adapter's contract is concrete
(`pr-comments.sh clean-pass`: POSIX ERE, matched against the **newest** Copilot
review's body). A declared reviewer inherits exactly that contract and must meet
its precondition:

- The `poll` command **must** emit reviews newest-first, one JSON object per line,
  each with a `body` field. That is the adapter interface, not a suggestion.
- `clean_when` is a POSIX ERE, applied with `grep -Eq` to the **`body` of the
  newest item only** — never to the whole poll dump. Matching the dump means the
  first historical round in which the bot ever said "no comments" false-cleans the
  loop forever.
- A `poll` command that cannot satisfy the interface is declared wrong. The loop
  says so at enrollment and falls back to surface-and-ask.

`init` is **idempotent and re-runnable**. Re-running re-probes the CLI list,
re-verifies invocation recipes only when a CLI's version changed or its recipe
failed at run time, prints a diff of what changed, preserves existing opt-outs
(an explicit `enabled: false` is a decision, not an absence), user-declared
endpoints and forge reviewers, and migrates the schema stamp.

### A.5 Where the config lives, and its shape

Machine-scoped, uncommitted, and **outside the plugin directory** — `plugins/review-loop/`
is the install boundary (dong3 `CLAUDE.md`), so anything written there is lost
on the next plugin update.

Follow the resolution order `chat-subagent` already established in this repo, so
there is one house convention rather than two:

1. `<project-root>/.claude/review-loop.local.md` — per-project overrides
2. `~/.claude/review-loop.local.md` — global defaults

Merge by `id`; the project entry wins. The `.local.md` suffix marks it
uncommitted; `init` offers to add `.claude/*.local.md` to `.gitignore` if absent.

```markdown
---
review-loop-config: 1          # schema stamp; init migrates older values
panel:
  - id: codex
    kind: cli
    tier: 1                     # cross-family CLI
    enabled: true
    invocation:                 # learned by trying, once (§A.3) — never assumed
      form: embedded            # native | embedded
      command: "codex exec -m gpt-5.5 --json --sandbox read-only -"
      why: "preflight=broken; a native review ran 0 command_execution items"
      verified_with: "codex-cli 0.139.0"
  - id: claude-alt
    kind: claude-model
    tier: 2                     # different Claude model — same family, weak decorrelation
    model: fable
    enabled: true
  - id: deepseek                # user-declared; init never discovers endpoints
    kind: endpoint              # no `tier:` — it is derived from kind, not declared
    trust: user-asserted        # never counts as heterogeneous evidence (§B.9)
    via: chat-subagent          # name resolved from the chat-subagent registry
    alias: deepseek
    enabled: false

forge:                          # see §A.4 — a slot, empty until a reviewer is enrolled
  - id: copilot
    host: github
    adapter: builtin            # scripts/copilot.sh + scripts/pr-comments.sh
    enabled: true
    verified_with: "gh auth status ok"   # presence is not authentication (§A.2)
---

## Notes
Free-form. Why a panelist is disabled, host quirks, and the literal command line
that `init` verified for any CLI without a built-in recipe.
```

`panel` is a list, not a map: **more than one `kind: claude-model` entry is
legal** (`claude-alt`, `claude-alt-2`, …), which is what §B.10's method-divergent
degradation mode needs. Entries merge project-over-global by `id`.

**`invocation` is a learned recipe, not a permission.** It answers *how* to call
an enrolled CLI on this host — the one thing `command -v` cannot tell you and a
real call can (§A.3). `invocation.command` is the literal line that returned a
review; `form` and `why` explain it to a human. It is re-verified when the CLI's
version changes or when the recipe fails at run time; it is never silently trusted
past a failure (§A.6).

**`tier` is derived from `kind`, and a config file may not raise it.** An earlier
draft let an endpoint be written `tier: 1` and thereby buy the heterogeneous
verdict §A.4 warns against; an over-correction then declared `tier` inert, which is
also wrong — §B.9 really does key on "a tier-1 **CLI** panelist". The rule that
survives both objections:

| `kind` | `tier` | Can reach §B.9's heterogeneous verdict? |
|--------|--------|------------------------------------------|
| `cli` | 1 | yes — a different model family, actually called |
| `claude-model` | 2 | no — same family; tier 2 is the *panel* tier, not evidence of decorrelation |
| `endpoint` | — | no. `trust: user-asserted` by construction (§A.4) |

`tier` is therefore **derived, not declared**: writing `tier: 1` on an endpoint is
a lie the loop ignores. The field stays in the file because a human reading it
wants to see the claimed heterogeneity at a glance; it decides nothing that `kind`
and `trust` do not already decide. §A.5's `deepseek` example carries no `tier` for
exactly this reason.

There is still no `sandbox:` block. The sandbox *verdict* is not a stored fact —
it is a **consequence** recorded inside `codex`'s `invocation.form`, and the loop
re-runs its own preflight every start regardless (§A.6).

**No secrets, ever.** Endpoint entries carry a name, never a url and never an
`api_key_env` — those stay in the `chat-subagent` registry, which already
forbids raw keys. A user-declared `forge` reviewer's commands are command lines,
not credentials; if one would need a token inline, it is declared wrong.

### A.6 Runtime contract: liveness check and drift

At loop start the skill runs the §A.2 presence probe and reconciles it against the
config. Two cases, both **surfaced once, never silent**:

- **Enrolled but absent** (`codex` enrolled, not on `PATH`). Degrade, note it,
  and mark the gate's evidential tier accordingly (§B.9). The existing "Codex
  failed → surface + degrade" path already handles the mid-run variant.
- **Present but unenrolled** (`codex` installed after `init` ran). This is the
  genuinely harmful drift — a stale config would silently deny the loop its only
  tier-1 panelist. Note once: *"`codex` is on `PATH` but not enrolled — run
  `/review-loop:init` to add it."* Do not auto-enroll: enrollment is the user's
  decision (§A.1).
- **Recipe drift** — the CLI's version differs from `invocation.verified_with`, or
  the loop's own preflight now contradicts `invocation.form` (a kernel or AppArmor
  update can flip `broken` → `usable` overnight, and the reverse). The stored
  recipe is a **learned default, not gospel**: the preflight and the post-round
  detector still run and still win. Follow the evidence for this run, then say
  *"`codex`'s recorded invocation no longer matches this host — re-run
  `/review-loop:init` to re-verify."* A recipe that silently false-cleans is the
  exact failure spec 009 exists to prevent, so the recipe never suppresses a
  detector.

A user-declared endpoint panelist has no cheap liveness probe, by design (§A.2).
It is simply invoked; if it fails twice it is dropped and disclosed (§B.7).

**One more reconciliation, and it is not about presence.** If `claude-alt.model`
equals the model the session is *already* running, the tier-2 panelist is the
session's own weights with a fresh context — decorrelation by context only, not
by weights. §B.9 must then report the panel as **"fresh-context only"**, not as
tier 2. Verifying that the `model` parameter was *set* is not the same as
verifying it *differs*, and the difference is the entire reason tier 2 exists.

### A.7 The zero-config path stays

`SKILL.md` today advertises itself as self-contained and portable. With no config
file the loop fields the **same roster** it does today — Claude subagent + Codex
if present + Copilot for PR targets — and mentions once that `/review-loop:init`
can enroll more reviewers. `init` is never a precondition and never blocks.

**The roster is what `init` changes; the protocol is not.** A zero-config host
with `codex` present has two live panelists, so it runs the Part B protocol
(blind round 1, cross-critique) exactly like a configured host. Part B is gated
on **panelist liveness, never on the presence of a config file** — 0.5.0 changes
how any ≥2-reviewer run behaves, with or without `init`.

**Zero config means the Claude panelist runs on the session's own model.** There
is no `claude-alt.model` to dispatch under, and the skill must not invent one: a
model name it guesses may not be dispatchable, and §B.9's verdict tier would then
rest on a guess. So the subagent runs on the session model, and the gate reports
**fresh-context only** — the weakest tier, honestly earned. That is the concrete
incentive to run `init`: one answer upgrades the panel from fresh-context to
tier 2, and the loop says so when it hints at `init`.

### A.8 Files (Part A)

- `plugins/review-loop/commands/init.md` — **new.** `/review-loop:init`,
  mirroring `plugins/tsugu/commands/init.md`'s shape (namespaced command, one
  frontmatter `description`, invariants restated).
- `plugins/review-loop/skills/review-loop/SKILL.md` — new "Reviewer roster"
  section replacing *Reviewer roster & priority*; the §A.6 reconciliation step at
  loop start; the *Requirements* section reworded so Codex is an **enrolled
  capability**, not an assumed one; **Phase B generalized from "GitHub Copilot" to
  "the enrolled forge reviewer, if any"** (§B.11).
- `plugins/review-loop/skills/review-loop/README.md` — document `init`, the
  config path, that it is optional, and that Copilot is one adapter rather than
  the only possible remote reviewer.
- **No new shipped script.** The presence probe is prose the agent runs (§A.2); the
  only new dev tooling is the detector fixture suite (§ Testing).

## Part B — Adversarial panel protocol

### B.1 Invariants (borrowed wholesale; they are the point)

- **Independence.** Round-1 findings are produced blind, against the *same
  unfixed diff*. A reviewer that has seen another's findings anchors on them.
- **Adversariality.** Agreement without a new argument is a failed round.
- **Adjudication, not averaging.** Disagreements are resolved on evidence
  strength and recorded; they are never split down the middle.

And one that is ours, because our target has something a debate does not — a
runnable ground truth:

- **Reproduction outranks argument.** review-loop reviews a *diff*, not a claim.
  Where a finding is executable, a failing test settles it. Disagreement between
  panelists about executable code is converted into a test, never into another
  round.

### B.2 Restructured Phase A

Current: `A0 author pass → A1 Claude review → fix → A2 Codex review (fixed tree) → A3 converge`.

Proposed:

```
A0  author pass (unchanged)
A1  Round 1 — blind, parallel, same unfixed diff
      ├─ Claude subagent   (Task, model from config: claude-alt)
      ├─ codex exec review (if enrolled + live)
      └─ … any other enrolled + live panelist
    validation gate: is each return a substantive review? (§B.7)
A2  Round 2 — cross-critique, parallel (only when ≥ 2 live panelists)
      each panelist receives the OTHER panelists' finding lists verbatim:
      attack specific findings; then restate your own, dropping any you now
      believe are wrong.
A3  Adjudicate → tier (T1/T2/T3) → resolve T2/T3 with the author → fix
      (per the existing Tiers rules; auto-fix gated by §B.4)
A4  Converge — re-review the new diff (§B.6) until clean or usage limit
```

**Round 3 is folded into Round 2** (the source skill sanctions this merge for
the cheap 2-panelist case: "critique, then restate your final position"). With
≥ 3 live panelists, a separate Round 3 — each panelist answering the critiques
of *its own* findings — becomes worthwhile; the skill runs it only then.

**Cross-critique runs on Round 1 only.** Convergence rounds (A4) are
verification against the code, not debate; they need no second adversary.

#### B.2.1 How each panelist is actually invoked

This is the part that does not follow from the source skill, because `codex exec
review` is not a chat interface.

- **R1, Codex, native path — use the *freeform* native form, not the targeted
  one.** An earlier draft of this spec asserted "the native form cannot carry a
  prompt". That is **false**, and the error mattered. What cannot carry a prompt is
  the *target-flag* form (`review --base` / `--uncommitted`; SKILL.md:119 —
  "`review --uncommitted -` errors rc=2"). SKILL.md:129–137 documents a second
  native form that **does** take one:
  ```bash
  printf '%s\n' "<focus prompt>" | codex exec --json --sandbox read-only review -
  ```
  It is native, it reads the tree, it captures `thread_id`, and Codex infers the
  diff itself. So R1's prompt names the base in prose *and* requests the §B.3
  record format, and **Codex's findings arrive with `confidence` and
  `falsification` in R1, on every host**.

  **The trade-off, stated plainly:** freeform gives up the explicit `--base` flag,
  so the target is named in prose and Codex infers it. SKILL.md's current guidance
  ("use the targeted form by default; reach for freeform only when custom focus is
  worth giving up the explicit target flag") therefore **changes** — the record
  format *is* that custom focus, and it is worth it, because a finding with no
  falsification condition can never be auto-fixed (§B.4).

  **And the trade-off has a cost the first draft of this paragraph missed: an
  inferred diff may not be the same diff.** R1 is the *blind* round; its whole
  value rests on every panelist reviewing the **same unfixed diff** (§B.1,
  independence). A freeform Codex infers its target, and an inference is not a
  guarantee. Do not trust it — check it:

  - The R1 prompt names the exact range, `<base>..<head-sha>`, not "this branch".
  - The prompt requires the review to **state the commit range and the file list it
    actually reviewed**, as its first line.
  - The facilitator compares that against `git diff --name-only <base>...<head>`. A
    mismatch means the panelist reviewed something else: **re-run once with the
    diff embedded** (which cannot be inferred wrong), then treat a second mismatch
    as a §B.7 panelist failure — drop, continue, disclose.

  Losing the explicit flag costs precision that prose plus a check can restore.
  Losing the record format costs the panel's only tier-1 reviewer its auto-fix
  eligibility. Losing the *shared* diff would cost the independence invariant, and
  that one is not for sale — hence the check.
- **R1, Codex, embedded-diff path:** unchanged. It carries a prompt too, so the
  record format is requested the same way. Both paths now behave alike.
- **R1, Claude subagent:** a `Task` dispatch. The brief must **stand alone** —
  the subagent sees none of this conversation. It carries: the exact diff
  snapshot (or how to obtain it), the tier definitions, the §B.3 record format,
  the falsification-condition instruction, and "your final message is the review
  record; no preamble". Two implementers writing this brief differently is
  precisely how the "comparable format across panelists" property §B.3 assumes
  gets lost, so the brief is specified once in `SKILL.md`, not improvised.
- **R2, Codex:** `codex exec --json --sandbox read-only resume "$thread_id" -`.
  The trailing `-` reads the *prompt* from stdin and is valid on `resume`
  (only `review`'s target flags conflict with a prompt). The prompt carries the
  other panelists' findings verbatim and asks Codex to attack them, then to
  restate its own surviving findings. On the embedded-diff path, R2 is a fresh
  embedded call carrying the complete current diff plus the other findings (per
  the existing sticky-embedded rule).
- **R2, `claude-alt` — a fresh dispatch, and say so.** `Task` subagents are
  one-shot; there is no instance to resume. R2's Claude side is a **new subagent**
  whose standalone brief carries: the same diff, *its own* R1 findings quoted back
  to it, the other panelists' findings, and the instruction to attack the others
  and restate its own. Be honest about what this is: a fresh instance defending
  text it did not itself produce is a weaker epistemic act than a panelist
  answering for its own argument. It is what the tool allows. The brief is
  specified once in `SKILL.md`, not improvised per run.
- **R2, other `kind: cli` panelists:** no resume protocol is assumed. Their R2 is a
  fresh call using the stored `invocation.command`, with the diff and the other
  findings in the prompt — the embedded shape, generalized.
- **`kind: endpoint` panelists, R1 and R2.** The loop resolves `alias` against the
  `chat-subagent` registry **at run time** — the loop reading that registry is
  sanctioned coupling; only `init` is forbidden to go looking (open question 5).
  It then posts an OpenAI-compatible chat completion whose prompt is the diff plus
  the §B.3 record format (R1), or the diff plus the other panelists' findings (R2).
  Findings are read from the response text. There is no resume; every round is a
  fresh completion carrying the full current diff. An endpoint that returns
  anything but a substantive review twice is dropped per §B.7.

**Every R1 form now carries a prompt, so the §B.3 record arrives in R1 on every
host.** An earlier draft built a whole "fields arrive at different rounds on
different hosts" edge case on the false premise above. It is gone: freeform native
and embedded both take a prompt, and the targeted form is no longer used for R1.
A panelist that dies before R2 therefore leaves findings that are *field-complete
but uncritiqued* — `proposed`, ineligible for auto-fix on status alone (§B.2.2),
which is the correct and intended outcome.

**Consequence — the detector needs one exemption, so §B.13's "untouched" is
wrong as first written.** SKILL.md's post-round detector treats *all* native
rounds, `resume` explicitly included, as non-reviews when they run zero
`command_execution` items.

**The reason for the exemption is not that a critique round reads no files.** An
earlier draft said exactly that, and this spec's own R2 refuted it: the
cross-critique round run against this document executed **five** `command_execution`
items, because the panelist was asked to *refute by reproduction* and reproduction
means opening the file at the cited line. A good R2 reads the tree constantly.

The real reason is narrower and does not depend on behavior. The detector's
inference is "zero commands ⇒ this round never read the tree ⇒ the sandbox silently
false-cleaned a **review**". That inference is sound only when the round's job *is*
to review the tree. **An R2 critique round's subject is the findings, not the
tree** — so a zero-command R2 carries no information about sandbox health, and
convicting it of a false clean is a category error. A panelist that refutes an
argument purely from what is already in its session has done its job.

**R2 critique rounds are therefore exempt from the `command_execution` detector.**
Empirically the detector would rarely misfire — a reproduction-driven R2 runs
commands — so the exemption is a safety net for the legitimate zero-command case,
not a workaround for the common one. Left unexempted, such a round would be routed
to the embedded-diff form and, via the sticky-embedded rule, permanently demote a
`usable` host for the rest of the loop. Every other native round (initial `review`,
A4 `resume` verification, fresh native fallback) reviews the tree, keeps the
detector unchanged, and keeps its guarantee.

#### B.2.2 When a panelist dies mid-panel

Doubling the pre-fix Codex calls means the usage limit can now land *between*
R1 and R2, which today's rules do not cover. Disposition, for a limit or a
double-failure (§B.7) of any panelist after its R1 findings are already recorded:

- The dead panelist's **R1 findings stay in the record**, at `status: proposed` —
  they were never critiqued and never restated, so they cannot be `survived`.
- They are **surfaced to the author**, and they cannot be auto-fixed **while they
  remain at `proposed`**. They are not exiled from §B.4: if the facilitator
  reproduces one (a failing test, or a verified citation), it becomes `reproduced`
  and is auto-fixable like any other. Reproduction outranks argument (§B.1), and
  it does not care who raised the finding or whether that reviewer is still alive.
- The surviving panelists still cross-critique what exists, but a successful attack
  on a dead panelist's finding yields **`refuted-undefended`**, never `refuted`
  (§B.3). The dead cannot answer, so the attack is one-sided evidence: it becomes a
  live disagreement for the author, not a verdict the facilitator may act on.
- **§B.9 reports the panel that ran per round**, e.g. "R1 heterogeneous, R2 and
  convergence same-family (Codex hit its usage limit after R1)". Reporting the
  whole run as heterogeneous because R1 was is exactly the overclaim §B.9 exists
  to prevent.

#### B.2.3 What A4 converges against

Four decisions an implementer would otherwise guess:

1. **Thread.** A4 resumes the **same `thread_id` as R1 and R2** — R2 used
   `resume`, so it did not fork a session. If no `thread_id` was captured, the
   existing `--last` / fresh-review fallbacks apply unchanged.
2. **Baseline.** Convergence verifies the **post-R2 restated list** (findings
   each panelist still stood behind), not the raw R1 list. A finding its own
   author dropped in R2 is not resurrected.
3. **The `claude-alt` panelist cannot resume** — `Task` subagents are one-shot.
   Its convergence round is a **fresh dispatch** whose brief restates its own
   surviving findings and the new diff. Say so, or an implementer will hunt for
   a resume API that does not exist.
4. **Blocking.** Today "only an available, not-yet-clean Codex blocks". With N
   panelists: **every live panelist blocks**, and a panelist dropped under §B.7
   stops blocking the moment it is disclosed as dropped. A panelist that went
   clean and then died does not un-clean the gate.

#### B.2.4 What the author sees, and when

Two UX consequences of inserting a round, both found by walking a simulated run
rather than by reading the protocol.

**Show R1 before R2 runs.** Blind-parallel plus cross-critique roughly doubles the
silence before the author sees anything: 0.4.0 printed a tier list the moment A1
returned. So the loop **posts the R1 findings as soon as they land**, clearly
marked `proposed — not yet critiqued, none actionable`. The independence invariant
constrains *panelists*, not the author: they cannot see each other's findings, but
showing them to the human anchors nobody. Do not make the author wait through two
rounds of silence to learn the loop is working.

**Do not print the full record for findings the author never has to judge.** Five
fields × seventeen findings is a wall, and a wall is where real T3 decisions go to
die. So: an **auto-fixed finding gets one line** (claim, location, commit hash); a
**`refuted` finding gets one line** plus who refuted it and why; the **full record —
attribution, tier, confidence, falsification, status — is reserved for findings
that need the author**: T2/T3, live disagreements, and anything that failed the
§B.4 gate. Verbatim reviewer text (§B.8) is preserved in the journal regardless of
what the round output elides.

**`refuted-undefended` prints as a live disagreement, never as a one-liner.** It is
both refuted and unresolved, and the two renderings collide. The tie goes to the
author: a finding whose author never answered the attack is exactly the case where
a one-line "refuted by X" hides the fact that nobody checked. This is a display
rule, not an auto-fix rule — under §B.4 neither `proposed` nor `refuted` nor
`refuted-undefended` was ever eligible, so nothing about eligibility was ever
ambiguous. The ambiguity was only ever about **what the author gets to see**, which
is the part that decides whether they can catch the facilitator.

**Cost — and it is a real one, not a rounding error.** Before the first fix,
Codex is called twice (R1 + R2) instead of once. Usage limits are a first-class
outcome in this skill, so the true marginal cost of R2 is not "one more call" but
**one fewer convergence round before the limit** — on a limit-bound day, R2 can
turn a converging run into a degraded Claude-only tail. The claim that R2 pays
for itself (false positives dying before they become a commit, a test, and a
convergence round) is a **hypothesis, not a measurement**. §B.8's journal capture
must therefore record R2's kill rate and rounds consumed, so open question 1 has
data rather than taste to revisit on.

### B.3 The finding record

**Scope: §B.3 and §B.4 govern the local panel's findings only.** A forge reviewer
is not a panelist (§B.11): it never enters R1 or R2, so its comments can never
reach `survived`, and Copilot cannot be asked for a `confidence` or a
falsification condition. Phase B therefore keeps 0.4.0's rule unchanged —
`SKILL.md:53`, T1 auto-fixed, T2/T3 to the author. Applying the panel gate to
Copilot's comments would silently revoke an auto-fix that works today, for no
gain: the gate's purpose is to make a reviewer face an adversary, and there is no
adversary to face after the local gate has already closed.

Every finding **from a local panelist** carries:

| Field | Rule |
|-------|------|
| `reviewer` | panelist id. Codex's text is quoted **verbatim**, never paraphrased into Claude's voice. |
| `claim` | one sentence: what is wrong. |
| `location` | `file:line`. |
| `tier` | T1 / T2 / T3 — **cost and scope of the fix**, unchanged from today. |
| `confidence` | high / medium / low — **whether the finding is true**. Orthogonal to tier; today the loop has no field for it. |
| `falsification` | a concrete, checkable condition under which this finding is *not* a bug — e.g. "not a bug if `cfg` is non-null at every call site". |
| `status` | see the ladder below |

**The status ladder.** `refuted` had to be split: a finding whose author answered
the attack and lost is settled; a finding whose author was never asked is not.

| Status | Means | Auto-fix? | Shown as |
|--------|-------|-----------|----------|
| `proposed` | raised, not yet critiqued by anyone | never | R1 list |
| `survived` | attacked in R2, and the attack failed | eligible (§B.4) | tier list |
| `refuted` | attacked in R2, and its author **conceded or lost** | never | one line, with who and why |
| `refuted-undefended` | attacked, but its author never answered — it was dropped mid-panel (§B.2.2), or R2 was merged so no defense round existed | never | **live disagreement**, surfaced to the author |
| `reproduced` | a failing test (code) or a mechanically checkable citation (prose) — §B.5 | eligible (§B.4) | tier list |
| `unreproduced` | a correctness finding nobody attempted to reproduce | never; withholds "gate clean" (§B.5) | tier list |

`refuted-undefended` is the state that did not exist and had to. Without it, a
one-sided attack on a dead panelist's finding looks identical to a settled
refutation, and the facilitator — the party motivated to converge — gets to
adjudicate on evidence only one side supplied. It is never silently dropped and
never auto-fixed; it goes to the author as a disagreement the panel could not
resolve.

**A generic falsification condition is a missing one.** "If evidence emerges to
the contrary" is calibration theater and is treated as absent (§B.4). A
confidence number without a falsification condition means nothing: it does not
say what observation would retract it.

`tier` and `confidence` being different axes is the whole point — a T1 typo
finding can be simply wrong, and today T1 findings are auto-fixed.

**Who assigns `confidence`, and why it cannot be trusted alone.** The reviewer
that raised the finding assigns it, because nobody else can. That is a
self-assessment by the same weights that produced the finding — the very
self-preference conflict of interest this spec's Motivation names. A confidently
wrong model reports `high` and writes a plausible-sounding falsification string;
checking that the field is *present* is not checking that anyone *evaluated* it.

Therefore **`confidence` never authorizes anything on its own** (§B.4). Its job
is to inform the author and to be *attacked* in R2. What authorizes an automatic
fix is a finding having **survived an adversary** or having been **reproduced**.

**The facilitator never imputes these fields.** A Codex finding from a native R1
arrives with no `confidence` and no `falsification` (§B.2.1). Claude filling them
in would be Claude judging whether Codex's finding is true and dressing the
judgement as Codex's — facilitator capture (§B.8), and a violation of the verbatim
rule. Codex attaches its own fields in R2, the round that carries a prompt. Until
then the fields are simply absent, and absence blocks auto-fix rather than
inviting a guess.

### B.4 The auto-fix gate

Auto-fix a finding without asking the author only when:

```
tier == T1  ∧  ( status == reproduced
               ∨ (status == survived ∧ confidence == high ∧ falsification present) )
```

Two properties, both load-bearing:

- **`survived`, not `!= refuted`.** A finding that no adversary ever examined
  sits at `proposed`, which is trivially "not refuted". Gating on `proposed`
  would let a single same-family reviewer grade its own finding `high` and
  auto-commit it — the pre-014 failure mode with extra paperwork. `survived`
  means the finding was put in front of another panelist and was not refuted.
- **Reproduction outranks confidence.** A failing test demonstrating the finding
  makes its confidence label moot, and needs no adversary.

**Single-panelist runs (Claude-only) therefore auto-fix on `reproduced` only.**
There is no R2, so nothing can reach `survived`. This is the honest consequence:
a lone same-family reviewer has not earned the right to commit unsupervised.
Everything else is surfaced with its confidence and falsification condition
attached, and handled per the existing *Tiers* rules.

The cost is that a real typo occasionally bounces back for a one-word
confirmation. The benefit is that a false positive can no longer become a silent
commit — the class of harm the loop exists to prevent.

### B.5 Refute by reproduction

The skill already mandates TDD for fixes. That rule is promoted from *how you
fix* to *how a finding earns blocking status*:

- **Executable target.** A correctness finding is `reproduced` once a failing
  test demonstrates it. (Codex's `review` subcommand is read-only by construction
  and cannot run a repro — reproduction is the facilitator's job, before the fix.)
- **`unreproduced` does not silently vanish.** An `unreproduced` correctness
  finding does not block *automatic* convergence, but it **withholds the "gate
  clean" verdict**: the loop reports *"clean except N unreproduced correctness
  findings"* and the author waives them explicitly. Without this, the facilitator
  — the party motivated to converge — could converge past a real Codex finding
  simply by never attempting a reproduction. That would be a new facilitator-capture
  channel opened by the anti-capture spec, and it would quietly weaken today's
  rule that an available, not-yet-clean Codex blocks.
- **Prose target** (specs, plans, docs — a first-class target since 002). There
  is nothing to run, so `reproduced` needs an analogue or the gate strands every
  finding. Without one, §B.4 has a hole exactly where this skill dogfoods itself:
  a Claude-only run against a spec reaches neither `survived` (no adversary) nor
  `reproduced` (no test), so **not one finding is auto-fixable — every typo asks
  the author**. More friction than 0.4.0, none of the added safety.

  **A prose finding reaches `reproduced` only when the facilitator has run the
  check.** Two conditions, both mechanical, both obligations rather than
  capabilities:

  1. **The citation is verified.** The reviewer supplies the quoted text and its
     location; the facilitator confirms the quote occurs there — a `grep`, not a
     reading. A fabricated or mis-located quotation is a known model failure, and
     "a reader *can* check it" is capability, not a check. Nobody's word, including
     a panelist's, promotes a finding to `reproduced`.
  2. **The defect's fix is mechanically checkable.** A typo, a broken cross-
     reference, a stale line number, a regex that does not match the file it claims
     to guard: the fix either holds or does not, and a command says which.

  "Line 152 already contains `confidence`, so this anchor passes against the
  unmodified file" satisfies both — and did, three times, in this spec's own review
  rounds. "This section contradicts §B.4" satisfies neither on its own: the quote
  may exist while the contradiction is a matter of reading. **A citation plus the
  reviewer's interpretation is model judgement wearing evidence's clothes**; it
  goes to the author, where judgement belongs. This is the second principle applied
  where it is least convenient — closing the loophole costs us the easy win.

Cross-critique inherits the same standard: *"this fails on input X"*, not
*"I doubt this"*.

### B.6 Non-leading convergence

Replace the 0.4.0 §A2 resume prompt. Today:

> `I applied these fixes: <summary>. Are your earlier points resolved? Any new concerns?`

This asks a reviewer to accept the author's own summary of the author's own
fixes as evidence, and phrases the question so that "yes" is the cooperative
answer. Instead, hand it the new diff and ask it to check the code:

> The fixes are applied. For each point you raised, verify it **against the
> code** and state resolved or unresolved, with the evidence you used. Do not
> treat the author's description of the fix as evidence. Then state any new
> concerns.

Two sycophancy guards, both from the source skill's observed anti-patterns:

- **Cross-critique (R2)** must demand effort without mandating a verdict. The
  source skill's phrasing — *"you disagree with at least one central claim; find
  it"* — manufactures a disagreement when the other panelist happens to be right,
  and an invented refutation is worse than a missed one: it either inflates live
  disagreements or kills a true finding. Ask instead: *"name the central claim you
  tried hardest to break, and either break it or say why it held."* A round in
  which nothing was refuted is a legitimate outcome; a round in which nothing was
  **attacked** is the failed one.
- **An unexplained full reversal** — a panelist abandoning a finding without a
  reason, or conceding every attack — is a sycophancy flag. Ask that panelist
  for the grounds before accepting the reversal. This ask is **one extra
  panelist call**, and it is the single sanctioned exception to "cross-critique
  is one round" (Non-goals). Budget it: it fires only on a detected reversal,
  never routinely.

**Undefended refutations are disagreements, not verdicts.** In the merged
2-panelist R2 both panelists attack in parallel, so nobody answers the attacks on
their *own* findings (that was the source skill's Round 3, which we folded away).
A finding marked `refuted` on a critique its author never got to answer is
**surfaced as a live disagreement**, not silently dropped — the facilitator
adjudicating one-sided evidence is exactly the capture §B.8 forbids. With ≥ 3
panelists the separate Round 3 runs and this caveat does not apply.

### B.7 Ghost panelist: generalize the detector we already have

A status line, an empty result, or an error dump is **not a contribution**. If
one enters the record, Round 2 critiques thin air and the panel degrades
silently.

review-loop already implements the strongest version of this gate for one
reviewer: the 0.4.0 §A2 post-round detector (a native Codex round with zero
`command_execution` items never read the tree ⇒ non-review). Generalize the
*rule*, keeping the strongest available evidence per panelist:

- **Codex, native path:** the existing structural `command_execution` detector.
  Unchanged. Embedded-diff rounds stay exempt (the diff is in the prompt).
- **Every other panelist:** the return must be a substantive review — findings
  or an explicit "no remaining problems". Re-run once on failure; on a second
  failure, **drop the panelist, continue, and disclose** which panel actually
  ran.
- **External CLIs must run in the foreground** with a generous timeout (≈10 min).
  A wrapper that backgrounds the call and returns early manufactures ghosts.

### B.8 Facilitator capture

The facilitator (the main session) frames, dispatches, validates, adjudicates,
and fixes. It may not put its own arguments in a panelist's mouth.

- Findings in the round output are **attributed** — `[codex]`, `[claude-sonnet]`
  — and Codex's wording is preserved verbatim.
- The facilitator's own observations go in a separate, explicitly labelled
  **Facilitator** section. They are never counted as panel findings and never
  gate anything.
- Adjudications are recorded with their reason: which critique was accepted or
  rejected, and why. This is the audit trail; it is also exactly what the
  existing review-journal step wants (§ *Learning capture*), now available at
  round time rather than reconstructed afterward. The journal additionally
  records **R2's kill rate and rounds consumed**, so the §B.2.4 cost hypothesis
  can be checked against reality.

**Deduplication is the largest capture surface, and attribution alone does not
close it.** With two reviewers on one diff, the facilitator must merge duplicate
findings — and "these two are the same issue, I'll keep one phrasing" is the
laundering the verbatim rule exists to stop. Rules:

- A merged finding **retains both verbatim texts and both attributions**. It
  never collapses into the facilitator's paraphrase.
- **Distinguish a real duplicate from a taxonomy difference.** Two panelists
  slicing one problem into different buckets are not agreeing; recording them as
  one finding manufactures consensus.
- Any **downgrade, merge, or dismissal of a tier-1 panelist's finding is surfaced
  in the round output** with its reason. The facilitator may propose it; the
  author sees it.

§B.8 is honest about what it buys: attribution plus a mandatory surfacing rule
is *structural* only for the tier-1 downgrade case. Tiering (T1/T2/T3) remains
facilitator judgement, because scope-of-fix is not something a reviewer can
assess for a repo it does not own.

### B.9 Report the tier that actually ran

"Local gate clean" is not one verdict. State the panel's composition and the
evidential weight of its agreement:

- **Heterogeneous** — at least one live tier-1 **CLI** panelist (Codex, or
  another coding CLI) alongside Claude → convergence is meaningful evidence.
- **User-asserted heterogeneity** — the only non-Claude panelist is a declared
  endpoint (`trust: user-asserted`). Report it as such and **do not claim the
  heterogeneous tier**. §A.4 warns that a local 7B model is noise rather than
  decorrelation; a config file must not be able to upgrade the verdict that
  warning exists to prevent.
- **Same-family** — Claude subagent only, or Claude + a different Claude model →
  *"gate clean at tier 2 — same-family panel, shared blind spots possible; this
  is weak evidence."*
- **Fresh-context only** — `claude-alt.model` turned out to equal the session
  model (§A.6). The weakest verdict there is. Say it.

Report the panel that **actually ran**, verified. "Verified" means the model
actually *differed*, the CLI actually *ran a review*, the panelist actually
*returned findings* — not that a config field was set to the intended value, and
not the panel the config described. Where the composition changed mid-run (§B.2.2),
report it **per round** rather than by its best round.

**Verifying `claude-alt` needs a mechanism, or "verified" is a word.** A `model`
parameter can be ignored or silently substituted, and the skill has no way to
observe what a `Task` dispatch actually ran. So the R1 brief requires the subagent
to **state its own model id in the first line of its review record**, and the
facilitator compares that against both the requested model and the session model:

- Echo matches the requested model, and it differs from the session's → **tier 2**.
- Echo equals the session model → **fresh-context only** (§A.6), whatever the
  config asked for.
- No echo, or a model the session could not dispatch (the dispatch errors, or
  returns under a substitute) → **fresh-context only**, and say why.

A self-reported model id is itself a model's claim, and a weak one. It is what the
tool permits; the alternative is asserting a tier from a config field, which is
strictly worse. Where a check is weak, report the verdict it supports and no
stronger — that is the second principle's whole content.

### B.10 Degradation

- **Only Claude available** → single reviewer, no cross-critique, and the
  same-family caveat in §B.9. This is today's Claude-only fallback, now labelled
  honestly.
- **≥ 2 Claude panelists, no external CLI** → force **method-level divergence**,
  not tone: one reviews from first principles, one from base rates ("what
  usually breaks in changes shaped like this"), one hunts only for disconfirming
  evidence. A role name ("Red Team") does not decorrelate errors; a different
  method or an actual reproduction does. Reachable two ways, both legal: several
  `kind: claude-model` entries (§A.5), or one enrollment the facilitator
  dispatches under several method briefs. The gate verdict stays **same-family**
  either way — method divergence buys cross-critique, not decorrelated weights.
- **A panelist fails twice** → drop, continue, disclose (§B.2.2 governs findings
  it already contributed).

### B.11 Phase B is a forge slot, not a Copilot phase

Phase B in 0.4.0 is titled "GitHub Copilot" and its every step names `gh`. Retitle
it **"Forge reviewer (only when one is enrolled and the target is a PR/MR)"** and
rewrite its steps against the three operations of §A.4 — *request*, *poll*,
*recognize a clean pass*. GitHub Copilot becomes the `adapter: builtin` binding of
those operations to `scripts/copilot.sh` and `scripts/pr-comments.sh`; the existing
B0–B5 behavior (including the first-review 422 caveat and the repeat-comment guard)
is preserved **verbatim as that adapter's implementation**, not as the loop's
definition of Phase B.

Consequences worth stating, because they are the point of the exercise:

- **No forge reviewer enrolled → Phase B is skipped**, silently and correctly. The
  local panel gate is the whole loop. This is already true for non-GitHub forges
  today, but by accident rather than by design.
- **A forge reviewer is not a panelist.** It does not participate in R1's blind
  round or R2's cross-critique — it cannot, since it only exists once a PR is open.
  It reviews after the local gate is clean, exactly as Copilot does now.
- **A declared reviewer with no unambiguous clean signal never gets one invented
  for it** (§A.4). The loop polls, surfaces, and asks the author. Inventing a stop
  regex for a bot we have never watched is how a false clean is manufactured.
- **We ship one adapter because we can run one adapter.** Other forges have review
  agents; naming them here without an account to test against would put a
  ghost reviewer (§B.7) in the skill's own roster documentation.

### B.12 Covering the native branch without owning a native host

The author's Linux host routes Codex to the embedded-diff form. **This is not a
problem to be fixed.** The agent calls `codex`; embedding the diff is the tool we
built for exactly this host, and it works. A `broken` preflight is a *configuration*,
not an incident, and the loop never announces it (§A.3).

There is a real, narrow consequence and it is about **testing, not running**: R2 via
`resume "$thread_id" -` and its detector exemption would never once execute on the
machine where they are written.

**The coverage comes from a fixture, not from the author's kernel.** The detector is
a real `jq` predicate over `codex --json`'s event stream, so a recorded stream tests
it deterministically, with no sandbox involved:

| Fixture | `command_execution` items | Correct classification |
|---------|---------------------------|------------------------|
| a native `review` round the sandbox blocked | 0 | **non-review** → retry embedded, never a silent clean |
| a native `review` round that read the tree | ≥ 1 | review |
| an **R2 critique** round arguing from session context | 0 | **review** — exempt (§B.2.1) |

That third row is the whole exemption, and it is checkable without ever holding a
`usable` sandbox. (Empirically it is also the rare case: this spec's own R2 ran five
`command_execution` items, because refuting by reproduction means opening the file at
the cited line.)

Two consequences, neither of which is a gate on a human:

1. **Restoring the native path is separate work.** It means changing the host's
   AppArmor/sysctl policy (§A.3) — `sudo`, system-wide, every `bwrap` caller. `init`
   may point at the reference; the author may then do it as its own task. It is not a
   prerequisite for this spec, the implementation does not require it, the plan does
   not schedule it, and its absence is not a defect. The fixture is the coverage.
2. **What the fixture does not cover, the release notes disclose.** It exercises the
   predicate and the routing decision; it does not prove `codex exec resume` behaves
   as documented against a live `usable` sandbox. Shipping a branch nobody has watched
   run is how spec 009's false clean shipped. Disclose the residue; do not imply
   coverage you lack.

### B.13 Files (Part B)

- `plugins/review-loop/skills/review-loop/SKILL.md` — Phase A restructured
  (§B.2); panelist invocation forms and the standalone brief (§B.2.1); mid-panel
  death (§B.2.2); A4's thread/baseline/blocking rules (§B.2.3); the finding
  record (§B.3) folded into *Tiers*; the auto-fix gate (§B.4); the convergence
  prompt replaced (§B.6, 0.4.0 §A2 "Convergence rounds"); the ghost gate generalized
  (§B.7); a *Facilitator* discipline subsection (§B.8); *Exit conditions* reports
  the tier (§B.9).

  **One existing mechanism does change: the `command_execution` detector gains an
  exemption for R2 critique rounds** (§B.2.1). Sandbox routing, the embedded-diff
  form, the sticky-embedded rule, exit-code triage, the Copilot phase and the
  never-merge rule are untouched. An earlier draft of this spec claimed the
  detector was untouched too; that was false — a critique round reads no files by
  design, so an unmodified detector would fire on every healthy R2 and, via the
  sticky-embedded rule, permanently demote a `usable` host.
- `plugins/review-loop/skills/review-loop/references/why-adversarial.md` —
  **new.** The rationale (decorrelation, verification advantage, GAN lineage,
  the five observed anti-patterns) and credit to `makinux/adversarial-panel`
  (MIT). Rationale belongs in a reference file; SKILL.md carries only what the
  agent must execute.
- `plugins/review-loop/commands/review-loop.md` — invariant lines: blind
  round 1, cross-critique, never auto-fixes a low-confidence finding.
- `.claude-plugin/marketplace.json` — `review-loop` → `0.5.0`.
- `tools/review-loop/test-skill-content.sh` — new anchors (§ Testing).

## Open questions

Each carries a recommendation; they are the parts most worth arguing with.

1. **A `quick` escape hatch?** A `/review-loop <target> quick` argument that
   skips cross-critique for small diffs. *Recommendation: no, not yet.* The
   source skill's Round-0 triage is run by the same model whose blind spots the
   panel exists to catch — "you're confidently wrong exactly where the gate
   won't open." review-loop is already explicitly invoked, so the user's
   decision to run it *is* the triage. Revisit if R2 proves slow in practice.
2. **Should `init` pick the `claude-alt` model automatically** (read the session
   model, dispatch the subagent under a different one) rather than storing it?
   *Recommendation: store it.* Auto-picking hides which panel ran, and §B.9
   requires reporting the model actually set.
3. **Is the project-level override (`<project>/.claude/review-loop.local.md`)
   needed in 0.5.0?** Reviewer availability is a host fact. *Recommendation:
   specify it, implement it second* — the plausible per-project need ("a clean
   gate here requires Codex") is a policy statement that could equally live in
   the repo's own `CLAUDE.md`.
4. **Does the auto-fix gate bounce too much?** §B.4 now requires `survived` —
   so on a Claude-only host, *every* T1 typo without a reproduction goes to the
   author. That is the honest position, and it may also be an annoying one.
   *Recommendation: ship it strict, measure via the review journal, loosen with
   evidence.* The cheapest loosening, if needed: let a Claude-only run reach
   `survived` by dispatching a second, method-divergent Claude panelist (§B.10)
   rather than by weakening the gate.
5. **Should `init` ever read the `chat-subagent` registry** to offer its aliases
   as candidates? It would be one file read, no network. *Recommendation: no.*
   The author's constraint is that `init` probes CLI presence and takes
   everything else on request; an endpoint is named when it is wanted. Reading
   another plugin's config also couples two independently-installable plugins.

6. ~~**Split Part A and Part B into two specs / two versions?**~~ **Resolved: no
   split** (author, 2026-07-10). Both parts ship as `0.5.0` under one spec, as
   spec 010 did with its two parts. Fable 5's argument for splitting — one-way
   dependency, and a Part B revert would drag a working roster out with it — is
   sound but was outweighed: the two parts share one motivation, and the roster
   exists *because* Part B needs to know which panel actually ran. The residual
   risk is recorded rather than dismissed: if §B.2.1's native branch proves
   unworkable, Part B is reverted by disabling cross-critique (a one-panelist run
   is a legal configuration, §B.10), **not** by reverting the roster.

## Non-goals

- **Not a debate machine.** With the default 2-panelist panel, cross-critique is
  **one round**. Two sanctioned additions, both bounded: a separate Round 3 when
  **≥ 3 panelists** are live (§B.2), and the reversal-grounds ask (§B.6), which
  fires only on a detected unexplained reversal. Panelist disagreement about
  executable code is settled by a test (§B.1), not by more rounds.
- **Not Round-0 triage.** The user invoking `/review-loop` is the triage.
  (The triage-trap lesson — don't let the model's felt confidence decide whether
  review happens — applies to the *user's* `CLAUDE.md` "default is inline" rule,
  which is out of scope here.)
- **Not autonomous.** The author still decides T2/T3 fixes and the merge.
  Cross-critique adjudication that ends in a live disagreement is **surfaced**,
  not resolved by the facilitator's preference.
- **`init` is not a discovery engine.** Its *probe* is coding-CLI presence and
  nothing else — no network, no credentials, no scanning of other plugins' or
  repos' config. It *verifies invocation* by calling the CLIs it found (§A.3),
  and takes everything else from the user (§A.1).
- **Not a second endpoint registry.** Endpoints and keys stay in
  `chat-subagent`'s files; review-loop stores a name (§A.4).
- **`init` is not a precondition.** The zero-config loop keeps working (§A.7).
- **Not an inventory of forge review agents.** Other forges have them. This spec
  names none, ships none, and infers no clean-pass signal for one it has never
  watched run (§A.4, §B.11). It ships the slot and one tested adapter.
- **Not a claim that the native R2 path is tested.** It cannot be, on the host
  where it is written (§B.12).
- **Not changing** the sandbox routing, the embedded-diff form, the
  `command_execution` **detector's jq predicate**, exit-code triage, the Copilot
  adapter's behavior, or the never-merge rule. Two things in this list *do* change
  and are named here so no one can satisfy this bullet by ignoring them: the
  detector's **scope** gains an R2-critique exemption (§B.2.1), and Phase B's
  *framing* becomes a forge slot while its Copilot behavior is preserved verbatim
  (§B.11).
- **Not changing** the targeted `review --base` form itself. But note where it ends up:
  R1 becomes freeform (it must carry the record format, §B.2.1), R2 and A4 both
  `resume "$thread_id" -`, and the fresh-native fallback is freeform too. So the
  targeted form's only remaining home is **B3**, where Codex re-reviews pushed commits
  and needs no prompt. An earlier draft of this bullet claimed convergence kept the
  targeted form; convergence has always used `resume`. The implementation caught it.

## Testing

`SKILL.md` and the command docs are prose. Guard them with content anchors, and
give the one new script a real test.

**`tools/review-loop/test-skill-content.sh`** — extend. The harness has `need` and
`refute`. Add a third helper, because the failure this spec keeps committing is not
a wrong regex — it is a regex nobody ran against the old file:

```bash
# $1=regex, $2=description — must MATCH the new SKILL.md and NOT match the
# pre-change one. An anchor that already passes guards nothing.
need_new() {
  grep -Eq "$1" "$SKILL" || fail "SKILL.md missing: $2"
  if git -C "$REPO" show "$BASE_REF:$SKILL_REL" 2>/dev/null | grep -Eq "$1"; then
    fail "vacuous anchor (already present before the change): $2"
  fi
  pass "$2"
}
```

`BASE_REF` defaults to the merge-base with the default branch. **Three anchors
proposed across this spec's own review rounds were vacuous** — `need 'confidence'`
(SKILL.md:152 has "a bare `confidence is low`"), `need 'invocation'`
(SKILL.md:119 has "a `review` invocation"), and `refute '^## Phase B — GitHub
Copilot'` (the heading is `###`, so the regex never matched and the refute always
passed). Every one was proposed by a model that had not run `grep` against the file
it was making a claim about. `need_new` makes the mistake unrepeatable, which is
worth more than the three corrected regexes.

Anchors for **new** behavior use `need_new`; anchors guarding **pre-existing**
behavior against regression keep plain `need`, since they must pass on both files.

- `need_new 'blind'`, `need_new 'cross-critique'` — Phase A restructure.
- `refute 'Are your earlier points resolved'` — the leading convergence prompt is
  gone. (`refute` needs no novelty check: it asserts absence from the new file.)
- `need_new 'falsification condition'` — the finding record. Not `'confidence'`.
- `need_new 'refuted-undefended'` — the status that had to exist (§B.3).
- `need_new 'survived'` — the gate turns on `survived`, not `!= refuted`.
- `need_new 'weak evidence'` — same-family gate caveat.
- `need_new 'critique rounds are.*exempt'` — the R2 detector exemption.
- `need_new 'review-loop\.local\.md'`, `need_new 'Roster reconciliation'` — roster wiring.
- `need_new 'forge reviewer'` and `refute '^### Phase B — GitHub Copilot'` — Phase B
  is a slot, not a Copilot phase. Note the **three** hashes: SKILL.md:177 is an h3,
  and the two-hash regex proposed earlier could never have matched.
- `need_new 'invocation\.command'` — the learned recipe. Not bare `'invocation'`.
- `need_new 'facilitator confirms the quote'` — prose `reproduced` is a check the
  facilitator runs, not a capability the reviewer asserts (§B.5).
- `need 'verbatim'` — pre-existing word, but the facilitator-capture rule is new;
  anchor it on a phrase unique to that rule instead, e.g.
  `need_new 'retain both verbatim texts'`.
- Preserve every existing anchor (sandbox routing, detector predicate,
  embedded-diff exemption, watch gate, group-commits offer). Only the detector's
  *scope* changes; its jq predicate does not, so its anchor must still pass.

**The harness only greps `SKILL.md`** (`SKILL=…/SKILL.md`), so the invariant lines
this spec adds to `commands/review-loop.md` and `commands/init.md` are unguarded.
Either parameterize the harness over a file list, or drop the claim that anchors
cover the command docs. Do not leave it implied.

**`tools/review-loop/test-detector-predicate.sh`** — new, with recorded
`codex --json` fixtures under `tools/review-loop/fixtures/`. This is the one thing here
worth materializing (§ "materialize critical knowledge only"), because the R2 detector
exemption never executes on a host whose sandbox routes to embedded-diff (§B.12), and
because the predicate has already been mis-transcribed once.

- A native `review` round with **zero** `command_execution` items → **non-review**
  (retry embedded; never a silent clean). Fixture also carries the corroborating text
  marker.
- A native `review` round with `command_execution` items → review.
- An **R2 critique** round with zero `command_execution` items → **review (exempt)**.
  This row is the exemption, and it is checkable with no sandbox at all.
- The suite must be shown to *fail* when the exemption is removed. A test that cannot
  fail is not a test.

There is **no** `test-panel-detect.sh`, because there is no `panel-detect.sh` (§A.2).

**Manual verification:**

- `/review-loop:init` on a host with only `codex` → enrolls `codex`, asks which
  model the `claude-alt` subagent should use, offers nothing else, writes
  `~/.claude/review-loop.local.md`.
- Re-running `init` → prints a no-op diff, preserves an `enabled: false` opt-out
  and any user-declared endpoint.
- Delete the config → the loop fields **the same roster** as 0.4.0 (Claude subagent
  + Codex if present + forge reviewer for PR targets) and hints at `init` once. It
  still runs the Part B protocol, because Part B is gated on panelist liveness, not
  on a config file (§A.7). "Exactly as 0.4.0" would be the wrong assertion: 0.4.0 is
  serial (`0.4.0 §A1` → fix → `0.4.0 §A2`), and this is not.
- Zero config, `codex` present → panel runs blind-parallel, gate reports
  **fresh-context only** (no `claude-alt.model`, so the subagent runs on the session
  model) alongside the tier-1 CLI. Enrolling one model upgrades it to tier 2.
- Enrolled `codex` removed from `PATH` → loop degrades, says so, and reports the
  gate as same-family/weak.
- `codex` present but not enrolled → one note pointing at `/review-loop:init`;
  no auto-enrollment.
- A diff with one real bug and one plausible-but-wrong finding → the wrong one
  is refuted in cross-critique and never reaches a commit.
- A Claude-only run → no cross-critique, and the clean verdict is labelled weak
  evidence.

## Acceptance criteria

- [ ] `/review-loop:init` exists, is idempotent, re-probes on every run, prints a
      diff of changes, and preserves explicit opt-outs and user-declared entries.
- [ ] `init`'s **probe** is coding-CLI presence only — no network call, no
      credential read, no other plugin's config. Endpoints and forge reviewers are
      recorded only when the user names one.
- [ ] `init` **verifies invocation by calling** each enrolled CLI once on a
      throwaway target, bounded to two attempts, and stores the literal command
      line that worked. A CLI whose invocation cannot be established is **detected
      but not enrolled**, with the reason shown.
- [ ] A stored `invocation` recipe never suppresses the preflight or the
      `command_execution` detector; recipe drift is surfaced with a re-init hint.
- [ ] Phase B is titled for the **enrolled forge reviewer**, skips silently when
      none is enrolled, and preserves the existing Copilot behavior as the one
      built-in adapter. A declared reviewer without a `clean_when` signal causes
      the loop to surface comments and ask, never to invent a stop condition.
- [ ] A prose finding that **cites the passage it contradicts** counts as
      `reproduced`; a Claude-only run against a spec can therefore auto-fix a typo
      without asking, while "this is unclear" still goes to the author.
- [ ] R1 findings are shown to the author, marked `proposed`, before R2 runs.
      Auto-fixed and refuted findings print as one line; the full five-field record
      is reserved for findings the author must judge.
- [ ] The presence probe is inline prose, not a shipped script, and names `gh` among
      its candidates.
- [ ] Config resolves project-over-global at `.claude/review-loop.local.md`,
      references endpoints by name only, and carries a `review-loop-config`
      schema stamp.
- [ ] With no config, the loop fields the **same roster** as 0.4.0 and hints at
      `init` once. (It runs the Part B protocol, which is gated on panelist
      liveness, not on a config file — a zero-config host with `codex` has two
      live panelists and therefore cross-critiques.)
- [ ] Enrolled-but-absent and present-but-unenrolled drift are each handled per
      §A.6 — surfaced, never silently followed.
- [ ] `claude-alt.model` equal to the session model is detected and reported as
      **fresh-context only**, not as tier 2.
- [ ] Round 1 runs every live panelist **blind and in parallel against the same
      unfixed diff**; no panelist sees another's findings. The Claude subagent's
      brief is self-contained and specified in `SKILL.md`, not improvised.
- [ ] Round 2 cross-critique runs whenever ≥ 2 panelists are live, reaches Codex
      via `resume "$thread_id" -` (native) or a fresh embedded call, and each
      panelist receives the others' findings verbatim.
- [ ] R2 critique rounds are **exempt** from the `command_execution` detector; a
      healthy R2 on a `usable` host never routes the run to embedded-diff.
- [ ] Codex's R1 uses a **prompt-bearing** form on every host — freeform native
      (`review -`) or embedded — so its findings carry `confidence` and
      `falsification` from R1. The facilitator **never** imputes those fields.
- [ ] R2's dispatch is specified for every panelist kind: Codex resumes;
      `claude-alt` is a **fresh** subagent (one-shot `Task`, no resume) given its own
      R1 findings back; other CLIs and endpoints get a fresh call carrying the diff
      and the other findings.
- [ ] A finding is `refuted-undefended` — surfaced as a live disagreement, never
      auto-fixed, never silently dropped — whenever its author could not answer the
      attack.
- [ ] A prose finding reaches `reproduced` only after the **facilitator verifies the
      citation with a command** and the fix is mechanically checkable. A quote plus
      the reviewer's interpretation does not qualify.
- [ ] `§B.3`/`§B.4` govern local-panel findings only; Phase B keeps 0.4.0's
      T1-auto-fix rule for forge-reviewer comments.
- [ ] The gate reports **fresh-context only** when the subagent's echoed model id
      equals the session model, is absent, or the requested model was not
      dispatchable.
- [ ] The loop's start-up reconciliation asks presence only; `<cli> --version` runs
      during `init` alone, so a review never spawns a subprocess per CLI.
- [ ] `test-skill-content.sh` gains `need_new`, and every anchor guarding new
      behavior uses it. The suite **fails** if an anchor already matches the
      pre-change `SKILL.md`.
- [ ] Auto-fix fires only under the §B.4 gate — `reproduced`, or `survived` +
      high confidence + a concrete falsification condition. A Claude-only run
      auto-fixes on `reproduced` alone.
- [ ] An `unreproduced` correctness finding withholds the "gate clean" verdict
      until the author waives it.
- [ ] A panelist that dies between R1 and R2 leaves its findings at `proposed`
      (surfaced, never auto-fixed), and §B.9 reports the panel **per round**.
- [ ] A `refuted` verdict on a finding its author never answered is surfaced as a
      live disagreement, not silently dropped.
- [ ] Merged duplicate findings retain both verbatim texts and both attributions;
      any downgrade of a tier-1 panelist's finding is surfaced.
- [ ] The convergence prompt does not ask the reviewer to accept the author's fix
      summary as evidence.
- [ ] A non-substantive panelist return is re-run once, then dropped with
      disclosure; the Codex detector's jq predicate is unchanged (only its scope
      gains the R2 exemption).
- [ ] The facilitator's own observations appear only under a labelled
      *Facilitator* section and never gate the loop.
- [ ] The gate verdict names the panel that actually ran, labels same-family
      convergence as weak evidence, and never lets a `trust: user-asserted`
      endpoint buy the heterogeneous tier.
- [ ] `tools/review-loop/test-skill-content.sh` and `tools/review-loop/test-detector-predicate.sh`
      both pass; all pre-existing anchors still pass. No anchor is vacuous — the harness
      itself fails any anchor that already matches the unmodified 0.4.0 `SKILL.md`.
- [ ] The R2 detector exemption is covered by fixtures, and the suite is demonstrated to
      go red when the exemption is removed.
- [ ] `review-loop` version bumped to 0.5.0 in `.claude-plugin/marketplace.json`.
