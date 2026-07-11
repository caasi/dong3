# review-loop Reviewer Roster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `/review-loop:init` so the reviewer roster is chosen per environment, and let the loop use more than one reviewer properly — blind, in parallel, before any fix — per [spec 014](../specs/014-review-loop-reviewer-roster-design.md).

**Architecture:** `SKILL.md` is an LLM-read system prompt, so behaviour is wording. **No new shipped script.** One new command doc (`/review-loop:init`), targeted edits to `SKILL.md`, and content anchors that quote the rules they guard. The Tiers rules, auto-fix behaviour, Phase B, sandbox routing and the `command_execution` detector are untouched.

**Tech Stack:** Markdown (system prompt), Bash (`set -euo pipefail`), `git`, `jq`, `codex`, `gh`. No build system.

## Global Constraints

Copied from the spec. Every task's requirements implicitly include these.

- **Wording is behavior, and a runnable code sample is an instruction just as much as prose.** A well-meant rewording is an unreviewed behaviour change.
- **No new script under `plugins/`.** The presence probe is a `command -v` loop the agent runs inline. A shipped script must encode something an agent would get wrong or skip; a `command -v` loop is not that, and wrapping it calcifies a decision a stronger model will make correctly unaided.
- **No secrets.** The config stores names, never a url, never an `api_key_env`, never a token.
- **`init` never asks for `sudo` and never changes the host.**
- **The built-in Copilot adapter needs no enrollment.** A GitHub PR with an authenticated `gh` and `jq` reaches it exactly as before. Enrollment adds a *declared* reviewer on another forge, or opts out.
- **Heterogeneity is a bonus, not a gate.** Nothing gates on having a cross-family reviewer. Reproduction is what makes a finding actionable.
- Dev tooling stays under `tools/review-loop/`. Bash uses `set -euo pipefail`; no pipeline feeds `grep -q`.
- Conventional commits scoped by plugin: `feat(review-loop):`, `docs(review-loop):`, `test(review-loop):`, `chore(review-loop):`. Repo-facing text is English.
- Target version: `review-loop` `0.4.0` → `0.5.0`.
- **Never merges autonomously.** The author decides T2/T3 and the merge.

## Scope & Conventions

- Work on a feature branch in a worktree, never `main`. Branch: `feat/review-loop-reviewer-roster`. Run **every** git command from inside the worktree.
- The spec is the source of truth. Where this plan and the spec disagree, the spec wins — report the discrepancy rather than guessing.
- All `SKILL.md` edits use the **Edit tool** with the verbatim Find anchors below as `old_string`. **If an Edit fails to match, re-read the live file and report — do not guess.**
- **Do not improve the prose.** If a sentence looks wrong, paste it as written and say so under Concerns. Every task in this plan's predecessor surfaced a real defect precisely by refusing to silently reconcile one.

## File Structure

**Create:**
- `plugins/review-loop/commands/init.md` — the `/review-loop:init` command doc.
- `plugins/review-loop/skills/review-loop/references/why-adversarial.md` — the rationale, the two hypotheses, and the credit.

**Modify:**
- `plugins/review-loop/skills/review-loop/SKILL.md` — roster, reconciliation, blind parallel round, finding record, verdict, ghost gate, facilitator discipline.
- `plugins/review-loop/commands/review-loop.md` — invariant lines.
- `plugins/review-loop/skills/review-loop/README.md` — roster, `init`, Copilot-as-adapter.
- `.claude-plugin/marketplace.json`, `plugins/review-loop/.claude-plugin/plugin.json` — version and description.
- `tools/review-loop/test-skill-content.sh` — new anchors, each quoting its rule.

**Deliberately unchanged:** `scripts/copilot.sh`, `scripts/pr-comments.sh`, `scripts/sandbox-preflight.sh`, the Tiers section, Phase B's steps B0–B5, the sandbox routing, the embedded-diff form, the `command_execution` detector, exit-code triage.

---

## Task 1: `SKILL.md` — the roster is enrolled, and reconciled at loop start

**Files:** `plugins/review-loop/skills/review-loop/SKILL.md`

- [ ] **Step 1: Reword the Requirements bullets**

Find (verbatim):

```
- **Always usable:** the Claude subagent reviewer needs nothing extra.
```

Replace with:

```
- **Always usable:** the Claude subagent reviewer needs nothing extra. `/review-loop:init`
  can pin it to a *different* Claude model — the cheapest strengthening available, and it
  needs no second CLI.
- **The roster is enrolled, not assumed.** Which reviewers this host can field is answered
  by a `command -v` sweep at loop start, plus `~/.claude/review-loop.local.md` (enrollment,
  and the invocation recipe `/review-loop:init` learned by actually calling each CLI). With
  no config the loop fields the same roster it always did; `init` is never a precondition.
```

Find (verbatim):

```
- **GitHub Copilot phase (optional):** the authenticated `gh` CLI and `jq`. Only used for GitHub PR targets.
```

Replace with:

```
- **Forge reviewer (optional):** the one built-in adapter is GitHub Copilot, which needs the
  **authenticated** `gh` CLI and `jq`, and runs only for GitHub PR targets. It needs **no
  enrollment** — zero config reaches it exactly as before. Presence of `gh` is not
  authentication. Enrollment adds a *declared* reviewer on another forge, or opts out of
  Copilot. With no forge reviewer available, Phase B is skipped and the local reviewers are
  the whole loop.
```

- [ ] **Step 2: Replace the roster section**

Find (verbatim):

```
## Reviewer roster & priority

1. **Local Claude subagent** — always. Dispatch a subagent (Task tool) to do the review.
2. **Local Codex** (headless `codex exec review`) — when `codex` is on `PATH`. tmux is not required; it adds a live-watch pane **only when you ask to watch** (and you're in tmux). See A2.
3. **GitHub Copilot** — only for GitHub PR targets, after the PR is open.
```

Replace with (note: the fenced `bash` block below is *content*, not a delimiter):

````
## Reviewer roster

Two things make a second look worth having, and they are not equally certain.

**More passes is more thinking.** A fresh pass over the same artifact finds real defects,
even by the same weights: a reviewer that has not seen its own earlier reasoning is a longer
chain of thought with a clean context. This is the load-bearing reason the loop reviews more
than once, it works on any host, and **same-family passes are first-class here, never a fallback**.

**Different model families may catch different holes.** Plausible, adopted, and **not
measured**. So heterogeneity is a **bonus, not a gate**: nothing here requires a cross-family
reviewer or blocks a clean verdict on its absence. What the loop does is *name which reviewers
ran* — disclosure, not a ranking — so a reader knows whether the cross-family perspective was
exercised this run, never to discount a same-family pass.

Reviewers carry a **role**, set by `/review-loop:init`, split by cost. Neither role adds a
sub-command:

1. **Routine panel** — runs on every review, blind and in parallel. Compose it from what the
   host has: the session's own model (fresh context), one or more *other* Claude models (e.g.
   Sonnet alongside an Opus session), and `codex` (a different family, actually called). Several
   at once is normal — Opus + Sonnet + gpt-5.5, not a single pick. A user-declared endpoint may
   join, but never counts as a cross-family voice.
2. **Direction guard** — an expensive, heavyweight model (e.g. Fable) held back from every
   round. It runs under this same `/review-loop`, proposed only when the escalation rule fires
   (see *When adversarial review is the point*). Never a sub-command, never every round.

**Forge reviewers are a separate phase** (Phase B) — they live on the code-hosting platform,
appear only once a PR/MR exists, and never review the local diff. GitHub Copilot is the one
built-in adapter and needs no enrollment.

### Roster reconciliation at loop start

Probe presence inline — no script; a `command -v` loop is not knowledge worth materializing:

```bash
for cli in codex gemini cursor-agent opencode aider crush amp llm gh; do
  command -v "$cli" >/dev/null 2>&1 && echo "$cli present" || echo "$cli absent"
done
```

(`<cli> --version` is `/review-loop:init`'s business, not a review's.)

Compare against the config and **surface every disagreement — never silently follow a stale config**:

- **Enrolled but absent** → note it, and reflect it in the panel the verdict names. A reviewer
  the author asked for and did not get is not a silent skip.
- **Present but unenrolled** (e.g. `codex` installed after `init` ran) → note once: "`codex` is
  on `PATH` but not enrolled — run `/review-loop:init` to add it." Do **not** auto-enroll.
- **Recipe drift** — the CLI's version differs from `invocation.verified_with`, or the preflight
  contradicts `invocation.form`. The stored recipe is a **learned default, not gospel**: the
  preflight and the post-round detector still run and still win. Follow this run's evidence, then
  suggest re-running `init`. **A recipe never suppresses a detector.**
- **A routine Claude reviewer's model equals the session model** → that reviewer is the session's
  own weights with a fresh context. Genuinely worth having; the verdict names it accurately (a
  fresh pass, not a distinct model) without treating it as lesser.
````

- [ ] **Step 3: Verify — check each phrase individually, never with one `grep 'A\|B\|C'`**

```bash
S=plugins/review-loop/skills/review-loop/SKILL.md
for phrase in 'More passes is more thinking' 'bonus, not a gate' 'never silently follow a stale config' 'needs no enrollment' 'same-family passes are first-class' 'Direction guard'; do
  printf '%-40s %s\n' "$phrase" "$(grep -c "$phrase" "$S")"
done
grep -c '^## Reviewer roster & priority' "$S"     # expect 0
awk '/^```/{n++} END{print "fences:", n, (n%2==0 ? "balanced" : "UNBALANCED")}' "$S"
grep -c '^````' "$S"                              # expect 0
bash tools/review-loop/test-skill-content.sh      # must still exit 0
```

Expected: each phrase ≥ 1, then `0`, `balanced`, `0`, and the suite green.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): the roster is enrolled and reconciled, not assumed

Two reasons to look twice, graded honestly. More passes is more thinking -- a fresh pass
finds real defects even by the same weights, and works on any host. Different model families
may catch different holes -- plausible, adopted, unmeasured. So heterogeneity is a bonus,
not a gate: nothing requires a cross-family reviewer, and the verdict says which ran.

Drift is surfaced, never silently followed. A stored recipe never suppresses the preflight
or the command_execution detector.

Implements spec 014 §A.1, §A.2, §A.6, and the roster half of §B.3."
```

---

## Task 2: `/review-loop:init` — the command doc, and the README

**Files:** create `plugins/review-loop/commands/init.md`; modify `plugins/review-loop/skills/review-loop/README.md`

- [ ] **Step 1: Read the house convention**

`plugins/tsugu/commands/init.md` is the sibling. Confirm its frontmatter carries exactly one `description:` key. Do not add others.

- [ ] **Step 2: Create `plugins/review-loop/commands/init.md`, verbatim**

```markdown
---
description: Discover which coding CLIs this host has, verify how to call each one by actually calling it, and record the reviewer roster you want here — idempotent; re-run whenever the host changes
---

# /review-loop:init

Invoke the `review-loop` skill and run the **init** routine. Pass `$ARGUMENTS` through as
free-form context.

**Usage:** `/review-loop:init`

Why it exists: the roster is a property of *this host* and of your taste. Which reviewers you
can field, and which you want, does not belong hard-coded in a skill.

Load-bearing invariants:

- **Probes presence, verifies invocation, asks for the rest.** The probe is `command -v` over a
  candidate list plus `<cli> --version` — no script, no network, no credentials, no other
  plugin's config. Everything it cannot probe is asked, not guessed.
- **Verifies by trying.** Knowing `codex` exists tells you nothing about how to drive it. `init`
  calls each enrolled CLI once, on a **throwaway fixture — never your real working tree** — and
  stores the literal command line that worked. Bounded to two attempts. A CLI whose invocation
  cannot be established is **detected but not enrolled**, with the reason shown.
- **Asks for the roster as two roles, split by cost.** A **routine panel** runs on every review —
  compose it from the session's own model, other Claude models, and `codex`; several at once is
  normal (Opus + Sonnet + gpt-5.5), and same-family members are first-class, not a fallback. A
  **direction guard** is an expensive model (e.g. Fable) held back from every round; `init` shows
  each reviewer's rough cost so you can decide. The direction guard adds **no sub-command** — it
  runs under the ordinary `/review-loop`, proposed only when the escalation rule fires. Each
  reviewer is written with its `role` (`routine` | `direction`).
- **Presence is not authentication, and Copilot is not enrollable.** The built-in GitHub Copilot
  adapter needs **no enrollment**: it runs for PR targets whenever `gh` is authenticated and `jq`
  is present, unless you opt out. `init` checks `gh auth status` *and* `command -v jq` so it can
  tell you whether Phase B will reach Copilot — it writes no Copilot enrollment record.
  Enrollment is for a *declared* reviewer on another forge.
- **Never asks for `sudo`, never fixes your host.** If Codex's native sandbox is blocked, `init`
  records `form: embedded` — a fully supported path, not a degradation — and may point once at
  `references/codex-sandbox-host-fixes.md`. Restoring the native path is an AppArmor/sysctl change
  affecting every `bwrap` caller on the machine: separate work, which you own.
- **Endpoints are declared, never discovered.** Name one and `init` records the name. Where it is
  an alias in the `chat-subagent` registry the entry is marked `via: chat-subagent`, and the url
  and `api_key_env` stay in that plugin's files. **No secrets are ever written.**
- **Idempotent, and it stamps its schema.** The config carries a `review-loop-config` stamp;
  `init` writes it and, on re-run, migrates an older one — removing the stale stamp rather than
  leaving both. Re-running re-probes, prints a diff of what changed, and preserves explicit
  opt-outs (`enabled: false` is a decision, not an absence).
- **Never a precondition.** With no config the loop works exactly as it does today, and hints at
  `init` once.

Writes `~/.claude/review-loop.local.md` (global), overridden per project by
`<project-root>/.claude/review-loop.local.md`. Offers to add `.claude/*.local.md` to
`.gitignore` if absent.
```

- [ ] **Step 3: Update the README's roster**

The README has its own roster list, worded differently from `SKILL.md`'s. Find (verbatim):

```
## Reviewer roster (in priority order)

1. **Claude subagent** — always; needs nothing extra.
2. **Codex** (headless `codex exec review`) — when `codex` is on `PATH`; tmux
   opens a live-watch pane only when you ask (never by default).
3. **GitHub Copilot** — only for GitHub PR targets, after the local gate is clean.
```

Replace with:

```
## Reviewer roster

Two reasons to look twice, and they are not equally certain. **More passes is more thinking**:
a fresh pass finds real defects even by the same weights, on any host — same-family passes are
first-class, not a fallback. **Different model families may catch different holes**: plausible,
adopted, and unmeasured — so heterogeneity is a *bonus, not a gate*. The loop never requires a
cross-family reviewer; it just names which ones ran, as disclosure, never to discount a
same-family pass.

Reviewers carry a **role**, set by `/review-loop:init`:

1. **Routine panel** — runs every review, blind and in parallel: the session's own model (fresh
   context), one or more *other* Claude models, and `codex` (a different family). Several at
   once is normal — Opus + Sonnet + gpt-5.5. A declared endpoint may join but never counts as a
   cross-family voice.
2. **Direction guard** — an expensive model (e.g. Fable) held back from every round, proposed
   under the ordinary `/review-loop` only when the escalation rule fires. No sub-command.

Routine reviewers answer **blind and in parallel** on the same unfixed diff — none sees another's
findings — and fixes land after all have reported. A **forge reviewer** (Phase B) is not one of
them: it appears only once a PR/MR exists. GitHub Copilot is the built-in adapter and needs no
enrollment.
```

- [ ] **Step 4: Update the README's Requirements bullet**

Find (verbatim):

```
- **Copilot phase (optional):** an authenticated `gh` CLI and `jq`; GitHub PRs only.
```

Replace with:

```
- **Forge reviewer (optional):** the built-in adapter is GitHub Copilot — an authenticated `gh`
  CLI and `jq`, GitHub PRs only, and **no enrollment needed**. Another forge's reviewer is
  reachable by declaring it and its three commands.
```

- [ ] **Step 5: Append the `init` section to the README**

```markdown
## `/review-loop:init` (optional)

Discovers which coding CLIs this host has, works out **how to call each one by actually calling
it**, and records the roster *you* want in `~/.claude/review-loop.local.md` (project override:
`<project-root>/.claude/review-loop.local.md`). Re-run it whenever the host changes; it is
idempotent and preserves your opt-outs.

It never writes a secret: endpoints are stored by name, and their url and `api_key_env` stay in
the `chat-subagent` registry. It never asks for `sudo`, and never changes your host.

**Copilot is one adapter, not the only possible remote reviewer.** Phase B is a forge-reviewer
slot with three operations — request, poll, recognize a clean pass. Copilot ships as the built-in
binding and needs no enrollment. Other forges have review agents; this skill names none and
implements none, because an adapter nobody here can run would poll forever or report a clean pass
that never happened. Declare one, supply its three commands and an unambiguous `clean_when`, and
the loop drives it.
```

- [ ] **Step 6: Verify**

```bash
test -f plugins/review-loop/commands/init.md && echo "command exists"
head -3 plugins/review-loop/commands/init.md          # exactly one frontmatter key
R=plugins/review-loop/skills/review-loop/README.md
for phrase in 'bonus, not a gate' 'blind and in parallel' 'no enrollment needed' 'never asks for'; do
  printf '%-28s %s\n' "$phrase" "$(grep -c "$phrase" "$R")"
done
grep -c '^## Reviewer roster (in priority order)' "$R"   # expect 0
awk '/^```/{n++} END{print "fences:", n, (n%2==0 ? "balanced" : "UNBALANCED")}' "$R"
grep -Eqi 'ghp_|sk-[A-Za-z0-9]{20}|Authorization: Bearer' plugins/review-loop/commands/init.md \
  && echo "SECRET LEAK" || echo "no secrets"
```

- [ ] **Step 7: Commit**

```bash
git add plugins/review-loop/commands/init.md plugins/review-loop/skills/review-loop/README.md
git commit -m "feat(review-loop): add /review-loop:init

The roster is a property of the host and of the author's taste; it does not belong in the
skill. init probes CLI presence, then VERIFIES INVOCATION BY TRYING -- one real call per
enrolled CLI against a throwaway fixture, never the user's working tree, since calibrating an
unenrolled third-party CLI on real changes would ship their code to a service they have not
agreed to enroll. It stores the literal command line that worked; a CLI whose invocation cannot
be established is detected but not enrolled.

Presence of gh is not authentication, and the built-in Copilot adapter is not enrollable: it
runs whenever gh is authenticated and jq is present, unless you opt out.

Implements spec 014 §A.3, §A.4, §A.5."
```

---

## Task 3: `SKILL.md` — blind and parallel, before any fix

**Files:** `plugins/review-loop/skills/review-loop/SKILL.md`

- [ ] **Step 1: Replace the A1 bullet**

Find (verbatim):

```
**A1. Claude subagent review** — dispatch a subagent to review the diff. Classify findings into T1/T2/T3, post the grouped list, resolve T2/T3 picks, then apply fixes (per *Tiers*). Commit fixes; push only if a remote/PR branch exists, otherwise commit locally.
```

Replace with (the fenced `bash` block is *content*):

````
**A1. Every live reviewer, blind and in parallel, on the same unfixed diff.** Nobody reviews a
tree someone else has already fixed, and **no reviewer sees another's findings**. A reviewer
shown another's output is not a second opinion, it is an editor.

Post the findings as each lands, marked **not yet actionable**. The independence rule binds
reviewers, not the author; making the author wait through parallel silence buys nothing.

How each is invoked:

- **Claude subagents** — one `Task` dispatch per enrolled routine Claude reviewer, each under its
  own `model`. The brief stands alone (the subagent sees none of this conversation): the diff, the
  tier definitions, the falsification-condition instruction, "state your model id on the first
  line", and "your final message is the review record; no preamble".
- **Codex, native path — the *freeform* form, because R1 needs a prompt.** A target flag takes
  none (`review --uncommitted -` errors rc=2), and the prompt is where the finding record is
  requested. The freeform form does take one:
  ```bash
  printf '%s\n' "$brief" | codex exec --json --sandbox read-only review -
  ```
  `$brief` names the exact range `<base>...<head-sha>` — three dots, the same range the check
  below runs — and requests the finding record. **An inferred diff may not be the same diff, and
  this is the blind round**, so the brief requires the review to state, as its first line, the
  range and file list it actually reviewed; the facilitator compares that against
  `git diff --name-only "$base"..."$head"`. A mismatch → re-run once with the diff embedded, which
  cannot be inferred wrong; a second mismatch → drop it, continue, disclose (*Ghost reviewer gate*).
- **Codex, embedded path** — unchanged. It carries a prompt too, so the record is requested the
  same way.
- **Any other enrolled CLI or endpoint** — the stored `invocation.command`, with the diff and the
  record format in the prompt. No resume protocol is assumed for anything but Codex.

**Then** classify the surviving findings into T1/T2/T3, post the grouped list, resolve T2/T3 with
the author, and apply fixes per *Tiers*. Commit fixes; push only if a remote/PR branch exists.

**Cross-critique is recommended, and gates nothing.** With two or more reviewers, showing each the
others' findings and asking them to attack is cheap and it kills false positives before they
become commits. Ask for the claim they *tried hardest to break*, and whether it held — never "you
disagree with at least one central claim; find it", which manufactures a refutation when the other
reviewer is right. A round that refutes nothing is a legitimate outcome; a round that **attacks**
nothing is the failed one. But a finding is actionable when it is **reproduced**, not when it
survives an argument: disagreement about executable code is settled by a test.
````

- [ ] **Step 2: Verify**

```bash
S=plugins/review-loop/skills/review-loop/SKILL.md
for phrase in "no reviewer sees another's findings" 'tried hardest to break' 'git diff --name-only' 'gates nothing'; do
  printf '%-38s %s\n' "$phrase" "$(grep -c "$phrase" "$S")"
done
grep -c 'A1. Claude subagent review' "$S"    # expect 0
awk '/^```/{n++} END{print "fences:", n, (n%2==0 ? "balanced" : "UNBALANCED")}' "$S"
grep -c '^````' "$S"                          # expect 0
```

**Then check the anchors the later tasks depend on still occur exactly once** (`Edit` fails on a
missing *or duplicated* `old_string`):

```bash
for a in 'Per round: post the grouped findings, **resolve T2/T3 with the author first**' \
         '### Phase B — GitHub Copilot (only for GitHub PR targets)' \
         '## Learning capture'; do
  printf '%s  %s\n' "$(grep -cF -- "$a" "$S")" "${a:0:40}"
done
```

Each must print `1`.

- [ ] **Step 3: Coherence hunt — quote what you find, do not fix it**

An edit correct in itself can make correct text elsewhere wrong; a cross-reference is the usual
seam. After your edit, read the surrounding sections and report:

- Does the old **A2. Codex review** bullet below still describe Codex as a *second, serial* gate
  that reads the already-fixed tree?
- Does any surviving sentence or **runnable code sample** present `review --base` as the first
  round's command? A sample is an instruction.
- Does the *Convergence rounds* bullet still resume a session A1 no longer creates the same way?

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): reviewers answer blind and in parallel, before any fix

The loop ran its reviewers as a queue: Claude reviewed, its fixes were committed, and only then
did Codex read the already-fixed tree -- so Codex could never dispute Claude's reading of a
finding, because it never saw what Claude saw.

R1 uses Codex's freeform native form because the targeted form takes no prompt, and the prompt is
where the finding record is requested. Freeform infers its own diff, which is dangerous in a blind
round, so the brief pins <base>...<head-sha> and the facilitator checks the echoed file list
against git diff --name-only: an inference is not a guarantee.

Cross-critique is recommended and gates nothing. A finding is actionable when it is reproduced,
not when it survives an argument.

Implements spec 014 §B.1, §B.4."
```

---

## Task 4: `SKILL.md` — the mechanics section stops describing a serial gate

Task 3 replaced the A1 step but the old **A2. Codex review** bullet still sits below it,
describing Codex as the second gate over an already-fixed tree, and its sample command still
shows the targeted form. Prose does not reinterpret itself.

**Files:** `plugins/review-loop/skills/review-loop/SKILL.md`

- [ ] **Step 1: Relabel the old A2 as shared mechanics — do not delete its body**

Its body holds the sandbox routing, the embedded-diff form, the `command_execution` detector,
`thread_id` resume, exit-code triage and usage-limit handling, all of which the spec keeps
unchanged.

Find (verbatim):

```
**A2. Codex review** (only if `codex` is on `PATH`; otherwise skip silently — don't block, don't mention it). Codex runs **headless** via `codex exec review` — no tmux, no pane, runs wherever `codex` is on `PATH`. The `review` subcommand is read-only by construction; Codex *finds* issues, Claude applies fixes (Codex never edits the tree).
```

Replace with:

```
#### Codex mechanics — how the Codex reviewer is driven

This section is **not a step**. It is the machinery the Codex reviewer runs on wherever it appears
above: blind in A1, and again when convergence re-checks the fixed diff. It applies only if
`codex` is live. **Never enrolled and absent → skip silently. Enrolled and absent → say so** and
grade the verdict (*Roster reconciliation*): a reviewer the author asked for and did not get is
not a silent skip. Codex runs **headless** via `codex exec` — no tmux, no pane. The `review`
subcommand is read-only by construction; Codex *finds* issues, Claude applies fixes.
```

- [ ] **Step 2: Make the first-round sample the freeform form**

Find (verbatim):

```
  codex exec --json --sandbox read-only review --base "$base"  >"$round" 2>"$err" || rc=$?   # branch vs base (default)
  # other targets: review --uncommitted (working tree) · review --commit "$sha" (one commit)
```

Replace with:

```
  printf '%s\n' "$brief" \
    | codex exec --json --sandbox read-only review - >"$round" 2>"$err" || rc=$?   # A1: freeform, carries the prompt
  # $brief names the range <base>...<head-sha> (three dots — matches the name-only check) and
  # requests the finding record. Targeted forms take NO prompt and so cannot serve A1. They remain
  # available where none is needed — see B3: review --base "$base" · review --uncommitted
```

- [ ] **Step 3: Fix every runnable sample that drops `--json`**

Without `--json` there are no `command_execution` items to count, so a sandbox that silently
blocked the round passes as a clean review — the failure spec 009 exists to kill.

```bash
S=plugins/review-loop/skills/review-loop/SKILL.md
grep -n 'codex exec' "$S" | grep -v -- '--json'
```

Every hit that is a **runnable command** (not prose naming the tool or the subcommand) must gain
`--json --sandbox read-only`. Judge by **snippet**, not by line: a line may contain one flagged
command and one bare one.

- [ ] **Step 4: Verify**

```bash
S=plugins/review-loop/skills/review-loop/SKILL.md
grep -c '^\*\*A2\.' "$S"                          # expect 0 — no second step label
grep -c 'Use `--base "$base"` as the canonical' "$S"   # expect 0
out=$(grep -n '^\s*|\?\s*codex exec' "$S" | grep -v -- '--json' || true)
[ -z "$out" ] && echo "every runnable codex command carries --json" || { echo "$out"; exit 1; }
grep -o '`[^`]*resume "\$thread_id"[^`]*`' "$S" | while IFS= read -r sn; do
  case "$sn" in *"codex exec"*) : ;; *) echo "BARE: $sn"; exit 1 ;; esac
done
for m in sandbox-preflight.sh command_execution thread_id 'Embedded-diff form' 'usage limit'; do
  printf '%-22s %s\n' "$m" "$(grep -c -- "$m" "$S")"
done
bash tools/review-loop/test-skill-content.sh
```

Expected: `0`, `0`, the `--json` line, no `BARE:`, every machinery mention ≥ 1, suite green.

- [ ] **Step 5: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "fix(review-loop): the mechanics section still described a serial gate

Task 3 installed the blind parallel round but left the old A2 bullet below it, which told the
agent Codex reads the already-fixed tree and showed 'review --base' as the first round's runnable
sample. In an LLM-read prompt a runnable sample is an instruction, and an agent reading top-down
obeys the sample.

The old bullet's body could not be deleted -- it holds the sandbox routing, the embedded-diff
form, the command_execution detector, thread_id resume, exit-code triage and usage-limit handling,
all of which spec 014 keeps unchanged. It is relabelled into shared mechanics.

Every runnable codex command now carries --json: without it there are no command_execution items
to count, and a sandbox that silently blocked the round passes as a clean review."
```

---

## Task 5: `SKILL.md` — findings carry a falsification condition; the verdict names the panel

**Files:** `plugins/review-loop/skills/review-loop/SKILL.md`

- [ ] **Step 1: Extend the Tiers paragraph with the finding record**

Find (verbatim):

```
Per round: post the grouped findings, **resolve T2/T3 with the author first** (quote the comment, draft 2–3 approaches with trade-offs, recommend one, wait for their pick), **then** apply the fixes — T1 auto-fixed, T2/T3 done as chosen. One commit per item, TDD, and reply/note the commit hash. (TDD and one-commit-per-item apply to executable changes; for prose/doc targets there are no tests to write first — prefer one logical edit per finding and review for clarity, consistency, structure, and factual accuracy.) Architectural decisions always land before mechanical edits are committed.
```

Replace with:

```
Per round: post the grouped findings, **resolve T2/T3 with the author first** (quote the comment, draft 2–3 approaches with trade-offs, recommend one, wait for their pick), **then** apply the fixes — T1 auto-fixed, T2/T3 done as chosen. One commit per item, TDD, and reply/note the commit hash. (TDD and one-commit-per-item apply to executable changes; for prose/doc targets there are no tests to write first — prefer one logical edit per finding and review for clarity, consistency, structure, and factual accuracy.) Architectural decisions always land before mechanical edits are committed.

### Reviewers are asked what would show a finding wrong; reproduction is the rule

A finding carries its **reviewer**, its **claim**, its **location** and its **tier**, and reviewers
are **asked** to add a concrete, checkable **falsification condition** — "not a bug if `cfg` is
non-null at every call site", "not a defect if line 152 does not already contain the word". A generic
condition — "if evidence emerges to the contrary" — carries no information; treat it as absent.

But **the absence of a falsification condition gates nothing** — it is not a required field, and no
finding is refused, downgraded, or auto-fixed on the strength of having one. The load-bearing rule is
one step up and already ours: **reproduce a finding before acting on it.** The falsification condition
is just the thing reproduction *checks*, and a reviewer who names it up front saves the facilitator
from reverse-engineering it; where it is left out, the facilitator reproduces anyway. A request, not a
contract — codifying it as required would be new machinery the roster split does not need.

**Reproduce before you accept.** On executable code, a failing test settles it. On prose there is
nothing to run, so reproduction is **a citation the facilitator verifies with a command** — the
quotation, its location, and a `grep`. "A reader can check it" is a capability, not a check. A
finding nobody could reproduce is still surfaced, and said to be unreproduced.

A reviewer may give a **confidence**. It informs the author and nothing else: it is a self-report by
the same weights that produced the finding. **The facilitator never imputes a confidence or a
falsification condition onto another reviewer's finding** — that would be Claude judging whether
Codex's finding is true and dressing the judgement as Codex's.

Codex's text is quoted **verbatim**, never paraphrased into Claude's voice.
```

- [ ] **Step 2: Replace the local-gate exit condition**

Find (verbatim):

```
- **Local gate clean + (for GitHub) Copilot clean pass** (matches "generated no comments." / "generated no new comments.") → stop and surface to the author. This is the primary, explicit stop signal — prefer it over inferring doneness from "no new comments for N polls".
```

Replace with:

```
- **Local gate clean + (for a forge target) the forge reviewer's clean pass** → stop and surface to the author. This is the primary, explicit stop signal — prefer it over inferring doneness from "no new comments for N polls".
- **"Clean" is not one verdict — but naming the panel is disclosure, not a ranking.** Same-family review is **never reported as a downgrade**: multiple passes, same family or not, are the strong hypothesis at work, and this project's history shows same-family reviewers finding a false premise, a class of test weakness, and four weak anchors. The verdict adds one honest note about what was and was not exercised this run:
  - **A cross-family reviewer ran** (a coding CLI alongside Claude) → the decorrelation bonus was exercised: agreement across families is less likely to share a blind spot.
  - **The panel was all one family** (Claude models only, however many) → say so plainly, as a fact, not a demerit. The multi-pass value is real and delivered; the cross-family bonus simply was not exercised this run — a note for the reader, not a verdict of "weaker".
  - **Only the session's own model ran** → still a genuine fresh-context pass; note no second reviewer participated, so the author can add one via `/review-loop:init`.
  - A user-declared endpoint never counts as a cross-family voice, whatever the config says.
  - Report what **actually ran, verified**: the CLIs that returned findings, and the models that actually *differed*. The subagent echoes its model id on the first line — a self-report, weak, and better than asserting composition from a config field. Where a check is weak, report the verdict it supports and no stronger — but **never let a weak check downgrade a same-family pass**.
```

- [ ] **Step 3: Add the escalation rule (§B.7) — when adversarial review is the point**

The direction guard needs a rule for *when* it is spent. Find (verbatim) the last line of the
verdict block you added in Step 2:

```
  - Report what **actually ran, verified**: the CLIs that returned findings, and the models that actually *differed*. The subagent echoes its model id on the first line — a self-report, weak, and better than asserting composition from a config field. Where a check is weak, report the verdict it supports and no stronger — but **never let a weak check downgrade a same-family pass**.
```

Insert this section immediately **after** it:

```

### When adversarial review is the point, and when looping is enough

The routine panel runs every review. The **direction guard** — the expensive, cross-family or
heavyweight reviewer — is spent only when the work needs decorrelation, and one axis decides
whether escalation is even on the table: **does the finding have a runnable ground truth?**

- **It does** — a test, a `grep`, `fxrank`, a type check settles it. **Keep looping.** Reproduction
  is the judge and the reviewer's family is irrelevant; same-family multi-pass converges here.
- **It does not** — the correctness is a judgement (design, premise, API shape, security argument).
  No test closes it, and a same-family judgement inherits the generator's blind spots. **Here the
  direction guard earns its cost.**

The axis decides whether escalation is possible; it does not by itself decide the spend is worth
it. **All three of the following presuppose that no check settles the finding** — a green check
takes it off the table first. Within that region, when one holds, the loop **proposes** the
direction guard (never auto-runs it, never a `/review-loop:direction` sub-command) and the author
says yes or no:

1. **No runnable ground truth** — design/prose/premise, not something a check adjudicates. This is
   the axis itself; the other two are reasons the spend is worth it within it.
2. **High or irreversible cost, with no check to settle it** — shared code, a merge gate, an
   outward-facing change, or a spec the downstream depends on. When judgement is all you have *and*
   a wrong judgement is expensive, the asymmetry justifies the spend. (A passing check that does
   not cover the risk is not ground truth for that risk — the finding is still in this region.)
3. **Converged without proof** — the panel went clean, but "clean" rests on judgement, not a green
   check. Same-family agreement with nothing runnable behind it is the
   diversity-illusion danger zone; convergence here is the signal to let a decorrelated reviewer
   try to break it.

When "clean" is backed by a passing check, **do not escalate** — the ground truth already ruled.
The default is to loop; adversarial review is the exception these triggers name.
```

- [ ] **Step 4: Verify**

```bash
S=plugins/review-loop/skills/review-loop/SKILL.md
for phrase in 'absence of a falsification condition gates nothing' 'a citation the facilitator verifies with a command' 'never imputes' 'never reported as a downgrade' 'never let a weak check downgrade a same-family pass' 'actually ran, verified' 'runnable ground truth' 'diversity-illusion danger zone'; do
  printf '%-46s %s\n' "$phrase" "$(grep -c "$phrase" "$S")"
done
grep -c 'Local gate clean + (for GitHub)' "$S"    # expect 0
grep -c '/review-loop:direction' "$S"             # expect 1 — only the denial
bash tools/review-loop/test-skill-content.sh
```

- [ ] **Step 5: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): findings say what would disprove them; the verdict names the panel

A falsification condition is not decoration. It is the thing reproduction checks, and naming it
lets someone who did not raise the finding check it. Confidence is a self-report by the weights
that produced the finding: it informs the author and authorizes nothing, and the facilitator never
imputes it onto another reviewer's finding.

'Local gate clean' was reported identically whether a cross-family reviewer participated or not.
The verdict now names who ran as disclosure, not a ranking: same-family review is never reported
as a downgrade -- it is the strong hypothesis at work -- and the note says only whether the
cross-family decorrelation bonus was exercised this run.

Implements spec 014 §B.2, §B.3."
```

---

## Task 6: `SKILL.md` — a review that is not a review; the facilitator is also a reviewer

**Files:** `plugins/review-loop/skills/review-loop/SKILL.md`

- [ ] **Step 1: Replace the leading convergence prompt**

Find (verbatim):

```
  printf '%s\n' "I applied these fixes: <summary>. Are your earlier points resolved? Any new concerns?" \
```

Replace with:

```
  printf '%s\n' "The fixes are applied. For each point you raised, verify it AGAINST THE CODE and state resolved or unresolved, with the evidence you used. Do not treat the author's description of the fix as evidence. Then state any new concerns." \
```

- [ ] **Step 2: Insert the two new sections before Learning capture**

Find (verbatim):

```
## Learning capture
```

Replace with:

```
## Facilitator discipline

The facilitator frames, dispatches, validates and fixes — and it is also the Claude subagent's
model. It may not put its own arguments in another reviewer's mouth.

- Findings in the round output are **attributed** — `[codex]`, `[claude-fable]` — and a reviewer's
  wording is preserved **verbatim**.
- The facilitator's own observations go under a separate, labelled **Facilitator** heading. They
  never count as a reviewer's findings and never gate anything.
- **Merged duplicates retain both verbatim texts and both attributions.** "These two are the same
  issue, I'll keep one phrasing" is the laundering the verbatim rule exists to stop. Two reviewers
  slicing one problem into different buckets are **not** agreeing.
- Any **downgrade or dismissal of a cross-family reviewer's finding is surfaced** with its reason.
  The facilitator may propose it; the author sees it.
- **An unexplained full reversal is a sycophancy flag.** A reviewer that abandons a finding without
  a reason, or concedes every attack, is asked for the grounds before the reversal is accepted.

Tiering (T1/T2/T3) stays facilitator judgement: scope-of-fix is not something a reviewer can assess
for a repo it does not own.

## Ghost reviewer gate

A status line, an empty result, or an error dump is **not a contribution**. If one enters the
record, the loop reasons about thin air.

- **Codex, native path:** the existing structural `command_execution` detector, unchanged — a native
  round that ran zero `command_execution` items never read the tree.
- **Every other reviewer:** the return must be a substantive review — findings, or an explicit "no
  remaining problems". Re-run once; on a second failure **drop the reviewer, continue, and disclose
  which panel actually ran**.
- **External CLIs run in the foreground** with a generous timeout (≈10 min). A wrapper that
  backgrounds the call and returns early manufactures ghosts.

## Learning capture
```

- [ ] **Step 3: Verify**

```bash
S=plugins/review-loop/skills/review-loop/SKILL.md
grep -c 'Are your earlier points resolved' "$S"     # expect 0
grep -c '^## Learning capture' "$S"                  # expect exactly 1
for phrase in 'Do not treat the author' 'retain both verbatim texts' 'drop the reviewer, continue, and disclose'; do
  printf '%-44s %s\n' "$phrase" "$(grep -c "$phrase" "$S")"
done
bash tools/review-loop/test-skill-content.sh
```

`## Learning capture` must print **exactly `1`**. `0` means you deleted it; `2` means you duplicated
it, and a later `Edit` fails on a non-unique `old_string`.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): non-leading convergence, ghost gate, facilitator discipline

The convergence prompt asked a reviewer to accept Claude's own summary of Claude's own fixes as
evidence, phrased so that 'yes' was the cooperative answer. It now hands over the code and refuses
the author's description as evidence.

Facilitator capture was unguarded: Claude is both a reviewer and the adjudicator. Attribution moves
into the round output, the facilitator's own views get a labelled section that gates nothing, and
merged duplicates keep both verbatim texts -- deduplication is the largest capture surface and
attribution alone does not close it.

Implements spec 014 §B.5, §B.6."
```

---

## Task 7: `references/why-adversarial.md`

**Files:** create `plugins/review-loop/skills/review-loop/references/why-adversarial.md`

- [ ] **Step 1: Write it**

It must contain, in this order:

1. **Credit.** `makinux/adversarial-panel`, <https://github.com/makinux/adversarial-panel>, MIT,
   Copyright (c) 2026 makinux; the essay by Ryousuke Wayama (@wayama_ryousuke), 2026-07-09.
2. **What we took — the insight**, not the architecture: confidently-wrong is the dangerous
   failure and self-critique shares the blind spot; a reviewer must not see another's findings
   before forming its own; refute by reproduction, not by assertion; and its five named failure
   modes as a checklist (*ghost panelist*, *sycophantic convergence*, *facilitator capture*,
   *confidence theater*, *diversity illusion*).
3. **What we did not take — the architecture**: the facilitator/panelist role split, Round 0
   triage, Rounds 1–3, the synthesis output format; mandatory cross-critique and the prompt that
   demands you disagree with at least one central claim; calibrated confidence as a gate; and above
   all a permission system built on adversarial survival. Its target is a **claim**, which can only
   be argued with. Ours is a **diff**, which has a runnable ground truth: where a finding is
   executable, a failing test settles what no debate could.
4. **The two hypotheses, graded.** Strong: more passes is more thinking — a fresh pass finds real
   defects even by the same weights, and this project's own history shows same-family reviewers
   finding a false premise the design rested on, a whole class of test weakness, four weak anchors,
   and a missing licence attribution. Weak: decorrelated error modes — plausible, adopted, **not
   measured**; what our record shows is that cross-family reviewers found *states nobody had run*,
   which decorrelation predicts but does not uniquely explain.
5. **Therefore heterogeneity is a bonus, not a gate.** Nothing requires a cross-family reviewer.
   The verdict names who ran as disclosure, not a ranking — so the reader knows whether the
   cross-family bonus was exercised, never to discount a same-family pass. Reproduction is what
   makes a finding actionable.

State plainly that we do not copy that skill's text.

- [ ] **Step 2: Verify**

```bash
W=plugins/review-loop/skills/review-loop/references/why-adversarial.md
for phrase in makinux MIT 'not its architecture' 'bonus, not a gate' 'not measured'; do
  printf '%-24s %s\n' "$phrase" "$(grep -ci "$phrase" "$W")"
done
```

Each ≥ 1.

- [ ] **Step 3: Commit**

```bash
git add plugins/review-loop/skills/review-loop/references/why-adversarial.md
git commit -m "docs(review-loop): credit makinux/adversarial-panel; take its insight, not its architecture

Its target is a claim, which can only be argued with. Ours is a diff, which has a runnable ground
truth: where a finding is executable, a failing test settles what no debate could. So we take the
independence rule and refute-by-reproduction, and leave behind the role split, the four-round
protocol, the mandatory cross-critique, and a permission system built on adversarial survival.

Its central mechanism -- decorrelated error modes -- is a hypothesis we adopted and did not
measure. We say so instead of gating on it."
```

---

## Task 8: Anchors that quote their rule; the command doc; the version bump

**Files:** `tools/review-loop/test-skill-content.sh`, `plugins/review-loop/commands/review-loop.md`, `.claude-plugin/marketplace.json`, `plugins/review-loop/.claude-plugin/plugin.json`, `plugins/review-loop/skills/review-loop/SKILL.md`

- [ ] **Step 1: Refresh `SKILL.md`'s frontmatter and intro**

They still describe the 0.4.0 serial loop, and the `description` is the skill's trigger text.

Find (verbatim, line 3):

```
description: General assisted review loop for changes — code or design artifacts (specs, plans, docs). Prefers local reviewers (Claude subagent + headless Codex via `codex exec review`) as the first gate; for GitHub PR targets, also requests Copilot after the PR is open. Loops each reviewer until clean or its usage limit, classifies comments into tiers, auto-fixes mechanical ones, pauses on architectural ones for user judgment. Never merges autonomously.
```

Replace with:

```
description: General assisted review loop for changes — code or design artifacts (specs, plans, docs). Local reviewers answer blind and in parallel on the same unfixed diff, before any fix; the verdict names which reviewers actually ran. The roster is enrolled per host by `/review-loop:init`, which is never a precondition. For PR/MR targets a forge reviewer follows the local gate; GitHub Copilot is the built-in adapter and needs no enrollment. Findings say what would disprove them, and are reproduced before they are acted on. Never merges autonomously.
```

Find (verbatim):

```
Claude and Codex reviewing **together** produces noticeably better output than either model alone — they catch different classes of issues, and Codex's pass tightens the diff before it ever reaches GitHub. The downstream payoff: by the time Copilot sees the PR, there's much less for it to complain about, so review rounds converge faster. Front-loading combined local Claude+Codex review as the first gate is the entire reason this loop exists.
```

Replace with:

```
A second look finds what the first missed. That is certain, and it does not need a second model family: a reviewer that has not seen its own earlier reasoning is a longer chain of thought with a clean context. Whether *different* model families catch *different* holes is plausible and unmeasured — so heterogeneity is a bonus here, never a gate. What matters is that the reviewers look at the **same unfixed diff**, that none of them sees another's findings first, and that the verdict says which ones actually ran. Serial review cannot do this: a reviewer shown the already-fixed tree is anchored on the first reviewer's judgement and can no longer dispute it.
```

- [ ] **Step 2: Update the command doc's invariants**

Find (verbatim):

```
- **Copilot is GitHub-only** — requested only for PR targets, after the local gate.
```

Replace with:

```
- **Blind and parallel** — every live reviewer reviews the same unfixed diff, none sees another's
  findings, and fixes land after all have reported. Cross-critique is recommended and gates nothing.
- **Heterogeneity is a bonus, not a gate** — the loop never requires a cross-family reviewer; the
  verdict names which ones actually ran.
- **The built-in forge reviewer needs no enrollment** — GitHub Copilot is requested for PR targets
  after the local gate, whenever `gh` is authenticated and `jq` is present, unless you opt out.
- **`/review-loop:init`** — optional; discovers which coding CLIs this host has and verifies how to
  call each one by actually calling it.
```

- [ ] **Step 3: Add the anchors — each must quote the rule it guards**

An anchor's strength is that it **quotes the rule**, not that its phrase is new. `need 'blind'`
is weak: delete the blind-review rule and two "blind spot" metaphors keep it green.

Find (verbatim):

```
echo "All SKILL.md content checks passed."
```

Replace with:

```
# spec 014 — the roster
need "no reviewer sees another's findings"               "A1 is blind"
need 'same unfixed diff'                                 "A1 reviews the unfixed diff"
need 'never silently follow a stale config'              "drift is surfaced"
need 'review-loop\.local\.md'                            "enrollment config path"
need 'bonus, not a gate'                                 "heterogeneity gates nothing"
need 'same-family passes are first-class'               "same-family is not a fallback"

# spec 014 — findings and the verdict
need 'absence of a falsification condition gates nothing' "a missing falsification condition gates nothing"
need 'a citation the facilitator verifies with a command' "prose reproduction is a check, not a capability"
need 'never imputes'                                     "the facilitator may not fill in another's fields"
need 'retain both verbatim texts'                        "dedup cannot launder attribution"
need 'never reported as a downgrade'                     "same-family is disclosed, never downgraded"
need 'never let a weak check downgrade a same-family pass' "a weak check may not downgrade same-family"
need 'actually ran, verified'                            "the verdict names the real panel"

# spec 014 — when adversarial review is the point (§B.7)
need 'does the finding have a runnable ground truth'     "the escalation axis is ground truth"
need 'never auto-runs it'                                "the direction guard is proposed, not auto-run"
need 'diversity-illusion danger zone'                    "converged-without-proof is the trigger"
# NB: the no-sub-command RULE is stated by NAMING /review-loop:direction as forbidden, so it is a
# need (the phrase is present as the denial), never a refute — Step 4's grep asserts exactly 1 hit.
need 'never a .?/review-loop:direction.? sub-command'    "no direction sub-command, stated as the rule"

# spec 014 — Codex's first round carries a prompt
need 'freeform, carries the prompt'                      "A1 uses the prompt-bearing form"
need 'git diff --name-only'                              "the inferred diff is checked"

# spec 014 — a review that is not a review
need 'drop the reviewer, continue, and disclose'          "ghost reviewer gate"

# gone
refute 'Are your earlier points resolved'                "leading convergence prompt"
refute '^\*\*A2\. Codex review'                          "the old serial second gate"

echo "All SKILL.md content checks passed."
```

- [ ] **Step 4: Prove each new anchor dies with its rule**

This is the only check that matters. For **each** anchor above, construct the minimal edit to
`SKILL.md` that deletes the rule while leaving the regex matching. If such an edit exists, the
anchor is weak — **tighten the anchor, never loosen it**. Run at least these three, restoring
byte-for-byte after each:

```bash
S=plugins/review-loop/skills/review-loop/SKILL.md
T=tools/review-loop/test-skill-content.sh
cp "$S" /tmp/s.bak
probe() { python3 -c "
p='$S'; s=open(p).read(); assert '''$1''' in s
open(p,'w').write(s.replace('''$1''','''$2''',1))"
  bash "$T" >/dev/null 2>&1 && echo "  GREEN (weak)  $3" || echo "  red (strong)  $3"
  cp /tmp/s.bak "$S"; }

probe "no reviewer sees another's findings" "reviewers may share findings" "delete the blind rule"
probe 'a citation the facilitator verifies with a command' 'a citation a reader can check' "weaken prose reproduction"
probe 'drop the reviewer, continue, and disclose' 'keep the reviewer and hope' "gut the ghost gate"
rm -f /tmp/s.bak
git diff --exit-code -- plugins/    # must be clean
```

Each must print `red (strong)`.

- [ ] **Step 5: Bump the version**

`.claude-plugin/marketplace.json` contains `"version": "0.4.0"` **twice** — `chat-subagent` is also
at 0.4.0. Use the two-line block so the anchor is unique.

Find (verbatim):

```
      "description": "Assisted multi-reviewer review loop — local Claude + Codex gate first, then GitHub Copilot for PRs; never merges autonomously",
      "version": "0.4.0"
```

Replace with:

```
      "description": "Assisted review loop — local reviewers answer blind and in parallel, the verdict names who ran; roster enrolled per host via /review-loop:init; never merges autonomously",
      "version": "0.5.0"
```

Then set the same description in `plugins/review-loop/.claude-plugin/plugin.json`, which ships to
the user's disk on install.

- [ ] **Step 6: Verify**

```bash
jq -r '.plugins[] | select(.name=="review-loop")  | .version' .claude-plugin/marketplace.json   # 0.5.0
jq -r '.plugins[] | select(.name=="chat-subagent") | .version' .claude-plugin/marketplace.json  # 0.4.0 — untouched
jq . .claude-plugin/marketplace.json >/dev/null && jq . plugins/review-loop/.claude-plugin/plugin.json >/dev/null && echo "valid json"
diff <(jq -r '.description' plugins/review-loop/.claude-plugin/plugin.json) \
     <(jq -r '.plugins[]|select(.name=="review-loop")|.description' .claude-plugin/marketplace.json) && echo "descriptions agree"
bash tools/review-loop/test-skill-content.sh
```

- [ ] **Step 7: Commit**

```bash
git add tools/review-loop/test-skill-content.sh plugins/review-loop/commands/review-loop.md \
        plugins/review-loop/skills/review-loop/SKILL.md .claude-plugin/marketplace.json \
        plugins/review-loop/.claude-plugin/plugin.json
git commit -m "chore(review-loop): bump to 0.5.0; anchors that quote their rule

An anchor's strength is that it quotes the rule, not that its phrase is new. need 'blind' is weak:
delete the blind-review rule and two 'blind spot' metaphors keep it green. Every new anchor here is
shown to turn the suite red when the rule it names is deleted.

No script can check that property -- finding the defeating edit is a search -- so it is checked by
the reviewers, and reproduced on a scratch copy.

The frontmatter description is the skill's trigger text; it described the 0.4.0 serial gate."
```

---

## Task 9: Full gate and manual verification

This task changes no files and makes no commit. If a check fails, report it — do not fix it here.

- [ ] **Step 1: Run everything**

```bash
bash tools/review-loop/test-skill-content.sh
bash tools/review-loop/test-sandbox-preflight.sh
git status --short
git diff --check main..HEAD
git grep -nE 'ghp_|sk-[A-Za-z0-9]{20}|Authorization: Bearer' -- plugins/ tools/
git diff --name-only main..HEAD
git diff --stat main..HEAD -- plugins/review-loop/skills/review-loop/scripts/   # must be empty
```

Expected: both suites exit 0; clean tree; no whitespace or conflict errors; every secret-shaped hit
is a sentence *forbidding* storage (read each); every changed file is under `plugins/review-loop/`,
`tools/review-loop/`, `.claude-plugin/` or `docs/superpowers/`; **nothing new under `scripts/`**.

- [ ] **Step 2: Prove the guards can fail**

A green suite is what a broken guard looks like. Run each edit, confirm RED, restore byte-for-byte
(`git diff --exit-code plugins/` clean afterwards), and paste the `FAIL:` line.

- Replace `no reviewer sees another's findings` → `reviewers may share findings`.
- Replace `drop the reviewer, continue, and disclose` → `keep the reviewer and hope`.
- Replace `a citation the facilitator verifies with a command` → `a citation a reader can check`.

- [ ] **Step 3: Read `SKILL.md` end to end and answer, quoting**

- Does any sentence still describe the loop as serial — Claude reviews, its fixes are committed,
  then Codex reads the already-fixed tree?
- Do the frontmatter `description`, the intro paragraphs, `commands/review-loop.md`, `README.md`
  and `plugin.json` all agree with the body about what the loop does?
- Is there any place where a **runnable code sample** and its surrounding prose disagree about which
  command a round runs? A sample is an instruction.
- Does `$brief` get its contents specified anywhere, or is it referenced and never described?
- Does anything gate on having a cross-family reviewer, or refuse to act without an adversary?
- Does the verdict anywhere call same-family review "weaker" or treat it as a downgrade? (It must not.)
- Does §B.7 read as a **proposal** the author approves, never an auto-run, and is `/review-loop:direction` named only to forbid it?
- Does the zero-config path (§A.7) still hint at `/review-loop:init` exactly **once** — not zero times, not on every run? This acceptance bullet has no `need` anchor (the hint is prose, hard to pin without a false-positive-prone regex); confirm it here by reading.

- [ ] **Step 4: Record the results** for the PR body. No commit.

---

## Task 10: Open the PR

Do **not** run this without the author's explicit go-ahead.

- [ ] **Step 1: Push**

```bash
git push -u origin feat/review-loop-reviewer-roster
```

- [ ] **Step 2: Open the PR**

Title: `review-loop 0.5.0: a reviewer roster you choose per environment`

Body must state:
- what changed (the roster, `init`, blind parallel review, the verdict naming who ran);
- what did **not** change (Tiers, auto-fix, Phase B, sandbox routing, the detector, never-merge);
- the two hypotheses and their grades, including that decorrelation is **adopted and unmeasured**;
- that heterogeneity gates nothing;
- the credit to `makinux/adversarial-panel` (MIT), and that we take the insight, not the architecture;
- the known coverage gap, if the host's sandbox preflight reports `broken`.

- [ ] **Step 3: Gate the PR**

Run `/review-loop <PR#>`. **Never merge autonomously** — the author decides. Prefer a merge commit.

---

## Self-Review (completed by plan author)

**1. Spec coverage.** §A.1 → Task 1. §A.2 → Task 1. §A.3 → Task 2. §A.4 (two roles — routine panel + direction guard) → Tasks 1, 2. §A.5 (config `role`) → Task 2. §A.6 → Task 1. §A.7 → Task 1 (zero-config hint) + Task 9 Step 3. §B.1 → Tasks 3, 4. §B.2 → Task 5. §B.3 (verdict names the panel, never downgrades same-family) → Tasks 1, 5. §B.4 → Task 3. §B.5 → Task 6. §B.6 → Task 6. §B.7 (escalation: ground-truth axis, direction guard proposed not auto-run, no sub-command) → Task 5 Step 3. *What we took, and what we did not* → Task 7. Testing → Task 8. Version → Task 8.

**2. Placeholder scan.** No TBD/TODO. Every `SKILL.md` edit carries verbatim Find/Replace text; `init.md` is given in full; Task 7's file is specified by required content rather than verbatim prose, deliberately — it is rationale, and an implementer should write it, then have it reviewed against the five required points.

**3. Ordering.** Task 3 installs the blind round; Task 4 fixes the mechanics it leaves stale — prose does not reinterpret itself, and this is where the predecessor plan bled. Task 8's anchors land after every `SKILL.md` edit they guard.

**4. What is deliberately absent.** No `need_new`. No git in the harness. No status ladder, no auto-fix gate rewrite, no mandatory cross-critique, no R2 `resume` channel, no detector exemption. **No `/review-loop:direction` sub-command** — the direction guard runs under the ordinary `/review-loop`, proposed by the §B.7 escalation rule. **The verdict never downgrades same-family review** — naming the panel is disclosure, not a ranking. Each absent mechanism existed only to serve a permission system built on adversarial survival, and the record shows that arm was never exercised: every fix on the predecessor branch was reproduced first.

**5. Branch discipline.** All work on `feat/review-loop-reviewer-roster` in a worktree; every git command from inside it.
