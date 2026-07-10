---
name: review-loop
description: General assisted review loop for changes — code or design artifacts (specs, plans, docs). Runs an adversarial panel of local reviewers: every live panelist answers blind on the same unfixed diff, then attacks the others' findings, before any fix is applied. Reviewers are discovered at loop start and may be enrolled by `/review-loop:init`, which is never a precondition; the gate names the panel that actually ran and calls same-family agreement weak evidence. For PR/MR targets a forge reviewer runs after the local gate is clean (GitHub Copilot is the built-in adapter and needs no enrollment). Findings carry a confidence and a falsification condition; a *panelist's* finding that neither faced an adversary nor was reproduced is never auto-fixed (a forge reviewer's comments are not gated this way). Never merges autonomously.
---

# Review Loop (Assisted)

Assisted, not autonomous. Preserves the author's architectural voice and learning across review cycles. General-purpose: the target may be a **local branch / working diff** (no remote needed) or a **GitHub PR**, and the changes under review may be **code or design artifacts** (specs, plans, docs).

**Local reviewers run first, and they run as a panel.** Every live panelist reviews the same **unfixed** diff blind — none sees another's findings — and then cross-critiques. Codex runs wherever the `codex` CLI is on `PATH` — no tmux needed; tmux only adds a live-watch pane **when the user asks to watch** (never by default). A forge reviewer (GitHub Copilot is the built-in adapter) is added only when the target is a PR/MR, and only after the local gate is clean.

## Why this loop exists

A reviewer catches what the author missed only when their failure modes differ. A model asked to critique its own output draws that critique from the same weights that produced the blind spot, so a same-family panel agreeing is weaker evidence than it looks. Running Claude and Codex **blind and in parallel**, then having each attack the other's findings, is what decorrelates the errors — and it kills false positives before they become commits, tests, and convergence rounds. Serial review cannot do this: a reviewer shown the already-fixed tree is anchored on the first reviewer's judgement and can no longer dispute it. That is the entire reason this loop exists.

## Requirements

- **Always usable:** the Claude subagent reviewer needs nothing extra.
- **The roster is enrolled, not assumed.** Which reviewers this host can field is
  answered by a `command -v` sweep at loop start (presence) plus
  `~/.claude/review-loop.local.md` (enrollment + the invocation recipe
  `/review-loop:init` learned by actually calling each CLI). With no config
  the loop fields the same roster it always did and hints at `init` once; `init` is
  never a precondition.
- **Codex reviewer (optional):** the `codex` CLI on `PATH`. Never enrolled and absent → skipped silently. **Enrolled and absent → say so** and lower the gate's evidential tier (see *Roster reconciliation*); a reviewer the author asked for and did not get is not a silent skip. `jq` is used to capture the resume `thread_id` from `codex`'s `--json` stream — without `jq`, resume just falls back to `--last` (see the *Convergence rounds* bullet under *Codex mechanics*). (tmux is **not** required — it only adds a live-watch pane **when you ask to watch**; see *Codex mechanics*.)
- **Forge reviewer (optional):** the one built-in adapter is GitHub Copilot, which needs
  the **authenticated** `gh` CLI and `jq`, and runs only for GitHub PR targets. It needs
  **no enrollment** — zero config reaches Copilot exactly as it always did. Presence of
  `gh` is not authentication. Enrollment adds a *declared* reviewer or opts out of Copilot.
  With no forge reviewer **available**, Phase B is skipped and the local panel is the whole loop.

The skill and helper scripts resolve their CLI dependencies (`codex`, `gh`, `jq`, plus `tmux` only for the live-watch pane (used only when you ask to watch)) from `PATH`, so the skill is self-contained and portable across machines.

## Inputs

- **Target** — one of:
  - a **local diff/branch** (default: current branch vs its base), or
  - a **GitHub PR number** (or a branch that already has an open PR → treat as GitHub target).
  - The diff may contain code, design artifacts (specs, plans, docs), or both — the loop reviews whatever changed.
- Repo / base branch inferred from the current working directory.

## Reviewer roster

Panelists are ranked by **heterogeneity** — decorrelated error modes are the only
reason a second reviewer catches anything the first missed:

1. **Tier 1 — a different model family**, actually called: `codex`, or another
   enrolled coding CLI, or a user-declared OpenAI-compatible endpoint (which is
   always `trust: user-asserted` and never counts as heterogeneous evidence).
2. **Tier 2 — a different Claude model**, via the `Task` tool's `model` parameter.
   Same family, so convergence here is weak evidence.
3. **Fresh-context only** — a Claude subagent on the session's own model. This is
   what a zero-config host gets, and the gate says so.

`tier` is **derived from `kind`, not declared**: writing `tier: 1` on an endpoint is
a lie the loop ignores.

These tiers map onto the verdicts *Exit conditions* reports: a live tier-1 **CLI** →
**Heterogeneous**; a tier-1 *endpoint* (always `trust: user-asserted`) → **User-asserted**,
never Heterogeneous; tier 2 → **Same-family**; and the last row → **Fresh-context only**.

**Forge reviewers are a separate slot** (Phase B) — they live on the code-hosting
platform, appear only once a PR/MR exists, and are never panelists. GitHub Copilot
is the one built-in adapter.

### Roster reconciliation at loop start

Probe presence inline — no script; a `command -v` loop is not knowledge worth
materializing. Then compare against the config and **surface every disagreement —
never silently follow a stale config**:

```bash
for cli in codex gemini cursor-agent opencode aider crush amp llm gh; do
  command -v "$cli" >/dev/null 2>&1 && echo "$cli present" || echo "$cli absent"
done
```

(`<cli> --version` is `/review-loop:init`'s business, not a review's: it spawns a real
subprocess per CLI and only drift detection needs it.)

- **Enrolled but absent** → degrade, note it, and lower the gate's evidential tier.
- **Present but unenrolled** (e.g. `codex` installed after `init` ran) → note once:
  "`codex` is on `PATH` but not enrolled — run `/review-loop:init` to add it."
  Do **not** auto-enroll; enrollment is the author's decision.
- **Recipe drift** — the CLI's version differs from `invocation.verified_with`, or
  the preflight contradicts `invocation.form`. The stored recipe is a **learned
  default, not gospel**: preflight and the post-round detector still run and still
  win. Follow this run's evidence, then suggest re-running `init`. A recipe must
  never suppress a detector.
- **`claude-alt.model` equals the session model** → the panel is **fresh-context
  only**, whatever the config asked for.

## Helper scripts

Prebuilt so you don't re-derive the same commands each run. All in `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/`, executable:

- `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh {status <pr> | request <pr> | rerequest <pr>}` — manage the Copilot reviewer. `request` uses `gh pr edit --add-reviewer`; `rerequest` uses the GraphQL `requestReviews` mutation. Note: the first-ever Copilot review may need a one-time request through the GitHub UI (see B1).
- `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh {fetch <pr> | clean-pass <pr>}` — paginated fetch of reviews + inline comments; `clean-pass` exits 0 when Copilot's newest review is a clean pass.

Reach for these first. Only hand-write a command when a script genuinely doesn't cover the case.

## Tiers (used for every reviewer's comments)

- **T1 mechanical**: typos, lint, null checks, test-only changes, doc fixes, rename within one file.
- **T2 local refactor**: method extraction, variable naming across a module, added validation.
- **T3 architectural**: file/module moves, API shape, "should this exist", simplification, scope cuts.

Per round: post the grouped findings, **resolve T2/T3 with the author first** (quote the comment, draft 2–3 approaches with trade-offs, recommend one, wait for their pick), **then** apply the fixes — T1 auto-fixed **only through the gate below**, T2/T3 done as chosen. One commit per item, TDD, and reply/note the commit hash. (TDD and one-commit-per-item apply to executable changes; for prose/doc targets there are no tests to write first — prefer one logical edit per finding and review for clarity, consistency, structure, and factual accuracy.) Architectural decisions always land before mechanical edits are committed.

### The finding record

**Scope: this and the auto-fix gate govern the local panel only.** A forge reviewer
is not a panelist — it never enters R1 or R2, so its comments can never reach
`survived`, and Copilot cannot be asked for a confidence. **Phase B is not gated by
the panel rule.** A forge reviewer's T1 comment is auto-fixed on its own merits, and its
T2/T3 comments go to the author — exactly as they did before the panel existed. Applying
the panel's gate to Copilot would revoke an auto-fix that works today, for nothing: the
gate exists to make a reviewer face an adversary, and there is no adversary left to face
once the local gate has closed.

Every finding **from a local panelist** carries: `reviewer` (Codex's text quoted
**verbatim**, never paraphrased into Claude's voice), `claim`, `location`, `tier`,
`confidence`, `falsification`, `status`.

- **`tier`** is the cost and scope of the fix. **`confidence`** is whether the
  finding is *true*. They are different axes — a T1 typo can simply be wrong.
- **`falsification`** is a concrete, checkable condition under which this is *not* a
  bug ("not a bug if `cfg` is non-null at every call site"). A generic one — "if
  evidence emerges to the contrary" — is calibration theater and counts as **absent**.
- **`confidence` authorizes nothing on its own.** The reviewer that raised the
  finding assigns it, because nobody else can — a self-assessment by the same weights
  that produced the finding. Its job is to inform the author and to be *attacked* in
  R2. **The facilitator never imputes these fields**: filling them in for Codex would
  be Claude judging whether Codex's finding is true and dressing the judgement as
  Codex's.

**Status ladder:**

| Status | Means | Auto-fix? |
|--------|-------|-----------|
| `proposed` | raised, not yet critiqued | never |
| `survived` | attacked in R2, and the attack failed | eligible |
| `refuted` | attacked, and its author conceded or lost | never |
| `refuted-undefended` | attacked, but its author never answered | never — **live disagreement** |
| `reproduced` | a failing test (code), or a facilitator-verified citation (prose) | eligible |
| `unreproduced` | a correctness finding nobody attempted to reproduce | never; withholds "gate clean" |

### The auto-fix gate

```
tier == T1  ∧  ( status == reproduced
               ∨ (status == survived ∧ confidence == high ∧ falsification present) )
```

`survived`, **not** `!= refuted`: an uncritiqued finding sits at `proposed`, which is
trivially "not refuted", so gating on that would let a lone same-family reviewer grade
its own finding `high` and auto-commit it. **A single-panelist run therefore auto-fixes
on `reproduced` alone** — a lone reviewer has not earned the right to commit
unsupervised.

### Refute by reproduction

- **Executable target:** a correctness finding is `reproduced` once a failing test
  demonstrates it. (`codex exec review` is read-only and cannot run one — reproduction
  is the facilitator's job, before the fix.) An `unreproduced` correctness finding does
  not block automatic convergence but **withholds the "gate clean" verdict** until the
  author waives it. Otherwise the facilitator — the party motivated to converge — could
  walk past a real finding simply by never attempting a repro.
- **Prose target:** there is nothing to run, so `reproduced` requires two mechanical
  conditions, both **obligations**, not capabilities:
  1. **The facilitator confirms the quote** occurs at the cited location — a `grep`,
     not a reading. A fabricated or mis-located quotation is a known model failure, and
     "a reader *can* check it" is capability, not a check.
  2. **The defect's fix is itself mechanically checkable** — a typo, a stale line
     reference, a regex that does not match the file it claims to guard.

  "Line 152 already contains `confidence`, so this anchor passes against the unmodified
  file" satisfies both. "This section is unclear" satisfies neither and goes to the
  author. **A citation plus the reviewer's interpretation is model judgement wearing
  evidence's clothes.**

## Flow

### Phase A — Local review (always first)

**A0. Author pass first** — before touching anything, ask: "Any simplifications you'd collapse across these changes before I start?" Capture as a commit-plan override.

**A1. Round 1 — blind, parallel, on the same unfixed diff.** Every live panelist
reviews *before any fix is applied*, and **no panelist sees another's findings**. A
reviewer shown another's output anchors on it, and the panel's whole value is that
their error modes differ.

Post the R1 findings to the author as soon as they land, marked
`proposed — not yet critiqued, none actionable`. The independence invariant binds
*panelists*, not the human; making the author wait through two silent rounds to
learn the loop is alive buys nothing.

**How each panelist is invoked:**

- **Codex, native path — the *freeform* form, not the targeted one.** A target flag
  takes no prompt (`review --uncommitted -` errors rc=2), and without a prompt Codex
  cannot be asked for the finding record, so its findings could never pass the
  auto-fix gate. The freeform native form does take a prompt:
  ```bash
  printf '%s\n' "$brief" | codex exec --json --sandbox read-only review -
  ```
  **An inferred diff may not be the same diff, and R1 is the blind round.** So the
  brief names the exact range `<base>...<head-sha>` — **three dots, the same range the check runs**; a two-dot range differs the moment the base advances — requires the review to state the
  commit range and file list it actually reviewed as its first line, and the
  facilitator compares that against `git diff --name-only "$base"..."$head"`. A
  mismatch → re-run once with the diff embedded (which cannot be inferred wrong); a
  second mismatch → *Ghost panelist gate*: drop, continue, disclose.
- **Codex, embedded path** — unchanged, and it carries a prompt too. Both paths
  request the same record format.
- **Claude subagent** — a `Task` dispatch under the enrolled `claude-alt.model`. The
  brief **stands alone** (the subagent sees none of this conversation): the diff, the
  tier definitions, the finding-record format, the falsification-condition
  instruction, "state your model id on the first line", and "your final message is
  the review record; no preamble".
- **Other enrolled CLIs / endpoints** — the stored `invocation.command`, with the
  diff and the record format in the prompt.

**A2. Round 2 — cross-critique, parallel.** Runs whenever **≥ 2 panelists are live**
(true on a zero-config host that has `codex`). Each panelist receives the *others'*
findings **verbatim** and is asked to attack them, then to restate its own, dropping
any it now believes wrong.

Do **not** mandate a disagreement. "You disagree with at least one central claim;
find it" manufactures a refutation when the other panelist is right, and an invented
refutation is worse than a missed one. Ask instead: *"name the central claim you
tried hardest to break, and either break it or say why it held."* A round that
refutes nothing is a legitimate outcome; a round that **attacks** nothing is the
failed one. Refute by reproduction — "this fails on input X", not "I doubt this".

- **Codex R2:** `codex exec --json --sandbox read-only resume "$thread_id" -` — the
  trailing `-` reads the prompt from stdin and is valid on `resume`. On the embedded
  path, a fresh embedded call carrying the complete current diff plus the other
  findings (the sticky-embedded rule).
- **Claude R2 is a *fresh* dispatch** — `Task` subagents are one-shot, so there is no
  instance to resume. Its brief carries the same diff, its own R1 findings quoted
  back to it, and the others' findings. A fresh instance defending text it did not
  produce is a weaker epistemic act than a panelist answering for its own argument.
  It is what the tool allows; say so rather than pretending otherwise.
- **Every other panelist R2 — a fresh call, no resume assumed.** For a `kind: cli`
  panelist other than Codex, and for a `kind: endpoint` panelist, re-invoke the stored
  `invocation.command` with the complete current diff, that panelist's own R1 findings
  quoted back to it, and the others' findings. Only Codex has a resume protocol; assume
  none for anything else.
- **Round 3** (each panelist answering critiques of its *own* findings) runs only
  with **≥ 3 live panelists**. With two, R2 is the merged "critique, then restate".

**R2 critique rounds are EXEMPT from the post-round `command_execution` detector.**
Not because a critique round reads no files — a good one reads many, since
reproduction means opening the file at the cited line. The detector's inference is
"zero commands ⇒ never read the tree ⇒ the sandbox false-cleaned a **review**", and
that is sound only when the round's job *is* to review the tree. An R2's subject is
the findings. Convicting it of a false clean is a category error, and the
sticky-embedded rule would then demote a `usable` host for the rest of the loop.
Every other native round keeps the detector, and its guarantee, unchanged.

**A panelist that dies between R1 and R2** (usage limit, or a double failure under *Ghost panelist gate*)
leaves its R1 findings at `proposed`: surfaced, never auto-fixed *while proposed*,
but not exiled — if the facilitator later reproduces one, it becomes `reproduced`
and is auto-fixable like any other. A successful attack on a dead panelist's finding
yields **`refuted-undefended`**, never `refuted`. Report the panel **per round**
("R1 heterogeneous; R2 and convergence same-family — Codex hit its usage limit").

**A3. Adjudicate → tier → resolve → fix.** Classify the surviving findings into
T1/T2/T3, resolve T2/T3 with the author, then apply fixes per *Tiers*, gated by the
auto-fix rule below. Commit fixes; push only if a remote/PR branch exists.

**A4. Convergence.** Resume the **same `thread_id`** used by R1 and R2 (R2 used
`resume`, so it did not fork). Verify against the **post-R2 restated list**, not the
raw R1 list — a finding its own author dropped is not resurrected. `claude-alt`
cannot resume: its convergence round is a fresh dispatch restating its surviving
findings. **Every live panelist blocks**; a panelist dropped under *Ghost panelist gate* stops
blocking the moment it is disclosed as dropped, and one that went clean then died
does not un-clean the gate.

**Output volume.** An auto-fixed finding prints as **one line** (claim, location,
commit). A `refuted` finding prints as one line plus who refuted it and why. A
**`refuted-undefended` finding prints as a live disagreement, never a one-liner** —
a "refuted by X" one-liner hides that nobody checked. The full record is reserved
for findings the author must judge: T2/T3, live disagreements, and anything that
failed the auto-fix gate.

#### Codex mechanics — how the Codex panelist is driven (used by R1, R2 and A4)

This section is **not a step**. It is the machinery the Codex panelist runs on wherever it appears above: blind in R1, attacking in R2, verifying in A4. It applies only if `codex` is live. **Never enrolled and absent → skip silently.** **Enrolled and absent → say so** and lower the gate's evidential tier (*Roster reconciliation*): a reviewer the author asked for and did not get is not a silent skip. Codex runs **headless** via `codex exec` — no tmux, no pane. The `review` subcommand is read-only by construction; Codex *finds* issues, Claude applies fixes (Codex never edits the tree).

- **Set up logs (once, at loop start):** pick a `<runid>` (PR number, branch slug, or `mktemp` suffix). `$log` is the **cumulative** feed for the optional watch pane *only*; each round also writes its own `$round` file, which is what Claude actually reads (so old rounds' findings are never replayed):
  ```bash
  log="/tmp/review-loop-codex.<runid>.log"; err="/tmp/review-loop-codex.<runid>.err"
  : >"$log"   # cumulative across rounds — for the tail -f watch pane only
  # Preflight once: can Codex's command sandbox build here? Routing hint only.
  sandbox=$("${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/sandbox-preflight.sh" 2>/dev/null) || true   # usable | broken | unknown
  ```
  Then **each round**: write Codex's stdout to a fresh `$round` file, capture `rc`, append that round to `$log` for the watch, and read **`$round`** (this round only):
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"   # template form: portable on BSD/macOS too
  rc=0
  <codex exec …> >"$round" 2>"$err" || rc=$?   # rc=0; … || rc=$? so it survives `set -e`; NEVER `| tee` (masks Codex's rc)
  cat "$round" >>"$log"                       # feed the cumulative watch pane
  # Claude reads "$round" (only this round); parse thread_id from "$round" too
  ```

- **Optional tmux live-watch (spectating only, not the channel) — spawn it only when the user explicitly asked to watch.** The channel is *always* `codex exec`. **Default — even inside tmux — is headless: no pane.** Spawn a read-only spectator pane *only when the user asked to watch* — a `watch` argument to the command, or an in-conversation request like "let me watch" / "show me the codex pane". Being inside tmux is **required but not a request on its own**. The agent sets `watch=1` when it recognized such a request (equivalently, it just runs the spawn only then); the pane follows the per-run `$log` (a raw-feed spectator aid — the authoritative human summary is still Claude's relayed tier list):
  ```bash
  # spawn ONLY when the user asked to watch (watch=1, set from intent) AND inside tmux.
  # $TMUX is necessary, not sufficient.
  [ -n "${watch:-}" ] && [ -n "${TMUX:-}" ] && watch_pane=$(tmux split-window -h -P \
    -F '#{session_name}:#{window_index}.#{pane_index}' "tail -f '$log'" 2>/dev/null) || true
  ```
  If the user asked to watch but `$TMUX` is unset (can't split a pane), note it once — "not in a tmux session, so I can't open a watch pane; Codex findings are still relayed in the tier list" — and continue headless. Never fail on this.
  The agent **never reads from this pane** — it reads `codex exec`'s stdout. All rounds append to the same `$log`, so the single pane keeps showing them. **Tear it down** at loop end (clean, usage-limit fallback, or abort) so it doesn't orphan — guard it so an unset/failed pane doesn't abort under `set -e`: `[ -n "${watch_pane:-}" ] && tmux kill-pane -t "$watch_pane" 2>/dev/null || true`. No tmux? Codex still runs — the human sees its findings relayed in Claude's own grouped tier list.

- **Resolve the target into the working tree first.** `codex exec review` reviews the *current checkout*, so before reviewing, make the checkout match the requested target: for a `<branch>` target, `git checkout` it (or run from its worktree); for a `<PR-number>` target, `gh pr checkout <num>` first. Only then does `review --base "$base"` (or `--uncommitted`) look at the right diff. (If checkout isn't possible, **don't** pipe a diff into `review -`: both `codex exec -` and `review -` read the *prompt / instructions* from stdin, **never** a diff or review target — so it would still review the current checkout. Instead use the embedded-diff form (§ *Codex mechanics*): put the diff in the prompt, e.g. `codex exec --json --sandbox read-only "Review this diff for correctness, design, and risk:\n$(gh pr diff <num>)"` — or tell the author the PR can't be reviewed without checkout.)

- **Route by sandbox state, not by target.** The preflight `$sandbox` decides which Codex form is primary:
  - `usable` → native `review` (below): it reads the local tree directly, correct for pushed *and* unpushed targets (no remote fallback happens).
  - `broken` / `unknown` → **embedded-diff form** (below): native may be unable to read the tree (a `broken` host falls back to the connected GitHub repo, which for a local-only target silently false-cleans; `unknown` is inconclusive — bwrap absent, working Landlock, or an unrecognized failure), so route conservatively. Embedding the diff sidesteps the sandbox entirely, so it is safe for every target on such a host. This also skips the wasted false-clean round on the common docs-to-`main` (unpushed design-artifact) case.

  The **local-only** check is routing rationale (it explains *why* a broken host is dangerous), not a separate gate — it never overrides a `usable` sandbox. Detect local-only per target mode (heuristic, not proof — remote-tracking refs can be stale, so optionally `git fetch` first; the post-round detector is the real backstop): `--commit <sha>` → `git branch -r --contains <sha>` empty; `--base <base>` → any commit in `<base>..HEAD` unreachable (an unpushed `HEAD` ⇒ treat the whole target as local-only); `--uncommitted` → inherently local-only.

- **Embedded-diff form (the `broken`/`unknown` path).** Put the diff *into the prompt* — no sandboxed subprocess is needed to read the tree, so the failure cannot occur. Keep `--json` (captures `thread_id` for resume):
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"
  rc=0
  printf '%s\n\n%s\n' "Review this diff for correctness, design, and risk. List concrete defects:" "$(git show "$sha")" \
    | codex exec --json --sandbox read-only - >"$round" 2>"$err" || rc=$?   # trailing - reads the PROMPT from stdin
  cat "$round" >>"$log"
  [ "$rc" = 0 ] && thread_id=$(jq -r 'select(.type=="thread.started") | .thread_id' "$round" 2>/dev/null | head -1) || true
  ```
  Do **not** also pass a `[PROMPT]` argument alongside `-` — stdin replaces it. Target variants: `--base` embeds `$(git diff "$base"...HEAD)`. `--uncommitted` must embed the **complete** snapshot — `git diff HEAD` (staged + unstaged tracked) **plus** each untracked file's contents (a filename list alone has none). Because `git diff --no-index` exits 1 whenever it emits a diff, build the snapshot `set -e`-safely by swallowing that status per file:
  ```bash
  unc="$(git diff HEAD
  git ls-files --others --exclude-standard -z \
    | xargs -0 -I{} sh -c 'git diff --no-index -- /dev/null "$1" || true' _ {}
  echo "--- untracked files ---"; git ls-files --others --exclude-standard)"
  # then embed "$unc" in the prompt. The trailing manifest is always appended so
  # genuinely empty new files (which produce no diff) are still part of the snapshot.
  ```
  On a `usable` sandbox the native form covers all three targets directly — but **R1 still uses
  freeform `review -`**, naming the target in prose, because a target flag takes no prompt and R1's
  prompt must request the finding record. The targeted forms belong where no prompt is needed (B3).

- **First round (R1) — the freeform form, because R1 needs a prompt.** This is the round whose session id we need, so run it with `--json` and capture `thread_id` for resume (see the *Convergence rounds* bullet below). `--sandbox read-only` goes **before** the subcommand. Target flags take **no** prompt (they conflict with `[PROMPT]` — `review --uncommitted -` errors rc=2), so a targeted round carries no instructions — and R1 **must** carry instructions: its prompt names the exact `<base>...<head-sha>` and requests the §finding-record fields. A finding with no falsification condition can never be auto-fixed, which would disqualify the panel's only tier-1 reviewer. So R1 is freeform, and the facilitator checks the echoed file list against `git diff --name-only` because a freeform Codex infers its own diff (see A1):
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"
  rc=0
  printf '%s\n' "$brief" \
    | codex exec --json --sandbox read-only review - >"$round" 2>"$err" || rc=$?   # R1: freeform, carries the prompt
  # $brief names the range <base>...<head-sha> (three dots — matches the name-only check) and
  # requests the finding-record fields.
  # Targeted forms take NO prompt and so cannot serve R1. They remain available where
  # no prompt is needed. B3 uses `review --base "$base"`; `review --uncommitted` and
  # `review --commit "$sha"` are the other targeted forms, for manual use outside the panel.
  cat "$round" >>"$log"   # feed the watch pane
  [ "$rc" = 0 ] && thread_id=$(jq -r 'select(.type=="thread.started") | .thread_id' "$round" 2>/dev/null | head -1) || true   # parse only on success; non-fatal (no id → --last fallback). jq, not regex.
  ```
  With `--json` the stdout is a JSON **event stream**: Claude reads the review content from the assistant/agent-message events in `$round` and classifies it into T1/T2/T3, **and** extracts `thread_id` for resume. The human-readable findings still reach the author via Claude's own relayed tier list (Claude relays regardless), so JSON-on-stdout is fine.
  The freeform form is also what steers a **custom focus** (e.g. a doc-artifact review): no target flag, Codex infers the diff, so name the target in prose. Keep `--json`, so R1 still captures `thread_id` for resume (otherwise convergence falls back to `--last`). Reach for a **targeted** form only where a prompt is genuinely unnecessary (see B3). The freeform custom-focus form:
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"
  rc=0
  printf '%s\n' "Review the changes against main as a design artifact: clarity, consistency, factual accuracy, gaps. No tests here." \
    | codex exec --json --sandbox read-only review - >"$round" 2>"$err" || rc=$?
  cat "$round" >>"$log"
  [ "$rc" = 0 ] && thread_id=$(jq -r 'select(.type=="thread.started") | .thread_id' "$round" 2>/dev/null | head -1) || true   # parse only on success; non-fatal (no id → --last fallback). jq, not regex.
  ```
  **Which form goes where.** R1 uses the **freeform** form (`review -`): it is the only native form that carries a prompt, and R1's prompt must request the finding record — a finding without a falsification condition can never be auto-fixed, which would disqualify the panel's only tier-1 reviewer. The price is that Codex infers the diff, so R1's prompt names the exact `<base>...<head-sha>` and the facilitator checks the echoed file list against `git diff --name-only` (see A1). **A4 convergence resumes the session** (`codex exec --json --sandbox read-only resume "$thread_id" -`), so it does not use a target flag either — and it keeps `--json`, without which the post-round detector has no `command_execution` items to count. The targeted `review --base "$base"` form's remaining home is **B3**, where Codex re-reviews pushed commits and needs no prompt.

- **Capture the exit status, don't pipe it away.** Never `codex … | tee` — that makes `$?` reflect `tee`, not Codex, and the three-outcome split below needs Codex's real exit code. Redirect stdout to the per-round `$round` file and stderr to `$err`, capturing the code set-e-safely (`rc=0; … || rc=$?`, never a bare `; rc=$?`), then `cat "$round" >>"$log"` for the watch and read `$round` for classification.

- **Model / effort — defer to the user's Codex config.** Pass **no `-m` and no reasoning-effort override**: `codex exec review` honors `~/.codex/config.toml`'s `review_model` (falling back to the session default). Only if the author names a model for the session ("use gpt-5.4") pass `-m` for the rest of the loop.

- **Three outcomes** after each call — branch on `rc`:
  - **`rc == 0` → first confirm Codex actually read the tree, *then* read the review.** Read **this round's `$round`** (not the cumulative `$log`). **Post-round detector (the guarantee) — every native-path round whose job is to *review the tree* (initial `review`, the A4 convergence `resume`, and the fresh native fallback). R2 critique rounds are EXEMPT** (their subject is the other panelists' findings, not the tree, so zero commands there says nothing about sandbox health — see A2): a native round that ran **zero `command_execution` items** never executed a local command, so it never read the tree (a sandbox false-clean). `codex exec --json` nests item kinds under `.item.type`, not top-level `.type`, so test:
    ```bash
    # set -e-safe: `jq -e` exits non-zero on no match, so branch on it (never run it bare).
    if ! jq -e 'select(.type=="item.completed") | select(.item.type=="command_execution")' "$round" >/dev/null; then
      :  # zero command_execution items ⇒ non-review (handle per below)
    fi
    ```
    Corroborate with text markers `sandbox prevented reading|repository sandbox|filesystem sandbox failed|not available in the connected GitHub repository`; treat a bare `confidence is low` as a non-review **only** alongside one of those markers. **Embedded-diff rounds are exempt** — the diff is in the prompt, so zero `command_execution` is expected and *not* a failure; judge them by reading the review (text markers only as a sanity check). On a **non-review**, retry with the embedded-diff form; if that still can't produce a real review, **degrade to Claude-only with a surfaced note** ("Codex couldn't read the target locally — proceeding Claude-only for the Codex gate") — never a silent clean. Otherwise Claude reads the review and classifies it into T1/T2/T3 or judges "no remaining problems," exactly as for its own subagent review.
  - **Non-zero *with* a limit message in `$err`** (matching `usage limit|rate limit|quota|too many requests|try again later`) → **usage-limited.** **Stop the Codex sub-loop**, note "Codex hit its usage limit — falling back to Claude-only local review (+ Copilot if this is a GitHub target)," and continue without Codex.
  - **Non-zero *without* a limit match → "Codex failed"** (bad flag, invalid base, auth failure, etc.). Do **not** silently fold this into the usage-limit fallback — **surface it to the author** with a stderr summary (`tail "$err"`), then degrade to Claude-only. (A read-only review in an untrusted/first-run directory was verified to *proceed* — rc=0 — not hard-fail, so no dedicated trust branch is needed; any future trust-gate non-zero exit lands here.)

- **Convergence rounds — resume the same session, with `--json`.** Use the `thread_id` captured from the first round (the `--json` stream's `thread_id` field — not `session_id`) and resume so Codex remembers its prior comments. **Keep `--json`** so the post-round detector (above) can still run on the resume round — read the review text from the assistant/agent-message events, exactly as on the first round (`resume`'s trailing `-` for the follow-up prompt is valid — only `review` target flags conflict with a prompt):
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"
  rc=0
  printf '%s\n' "The fixes are applied. For each point you raised, verify it AGAINST THE CODE and state resolved or unresolved, with the evidence you used. Do not treat the author's description of the fix as evidence. Then state any new concerns." \
    | codex exec --json --sandbox read-only resume "$thread_id" - >"$round" 2>"$err" || rc=$?
  cat "$round" >>"$log"   # feed the watch pane; Claude reads "$round" (this round only)
  ```
  **Fallbacks, in order:** no id captured (e.g. `jq` absent — the `thread_id` parse needs it) → `resume --last` (caveat: `--last` is cwd-scoped, so an unrelated `codex` session started in this repo mid-loop becomes the new "last"); `resume` fails (session expired/missing) → a **fresh** `codex exec --json --sandbox read-only review -` (freeform, no target flag) with the prior findings restated, so a round never silently loses the review.

- **Sticky embedded-diff convergence.** If the run is on the embedded-diff path (routed there, or moved there by the detector), keep **all** convergence rounds on it — re-embed the *complete* current target diff each round (`git show <sha>` / `git diff "$base"...HEAD`), **not** just the latest fix commit (a delta would hide regressions in earlier hunks). Resume against `thread_id` is fine only when the full current diff is embedded. **On the embedded path, the resume-failure fallback is a *fresh embedded-diff* call carrying the complete diff — not the generic fresh native `review -`** (which would re-trigger the sandbox false-clean on a broken host). Keep `--json` for `thread_id` + parsing; the structural detector does not apply to embedded-diff rounds (their guarantee is inherent — the diff is in the prompt). Any unavoidably plain-text round falls back to text markers alone.

- **Loop Codex until clean or its usage limit:** each round classify its findings into tiers, resolve picks, fix, then `resume` for re-review. Repeat until **either** Codex reports no remaining problems (Codex gate clean) **or** it hits the usage-limit outcome above.

- **Freeform plain-exec fallback (rare).** Drop to `codex exec --json --sandbox read-only "<instructions + diff>"` — keep both flags, or the detector cannot run and the round is not parseable — only when (a) the installed `codex` is too old to have `exec review`, or (b) the target is **not** a git diff (e.g. a pasted artifact outside any repo) — in case (b) **only**, add `--skip-git-repo-check` (unnecessary on the normal `review`/`resume` paths).

- **Local, unpushed commits on `main` are a first-class case, not an edge case.** Under the docs-to-`main` convention, design-artifact reviews routinely target a freshly-committed, unpushed commit on `main`. On a `broken`/`unknown` host that is exactly where native `review` silently false-cleans (it falls back to the remote, which lacks the commit) — which is why *Codex mechanics* routes these to the embedded-diff form and guards every tree-reading native round with the post-round detector.
- **Host fixes (optional).** If you want the native `review` path back on a host where the preflight reports `broken`, see `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/references/codex-sandbox-host-fixes.md` — a menu (bwrap-userns-restrict, legacy-landlock, …). The skill never applies these; embedded-diff already works with no host change.

#### Availability, not cleanliness — when a panelist stops blocking

A4 converges when every **live** panelist is clean. "Done" for Codex means any of: a clean review, **or** Codex was unavailable this run — the `codex` CLI is absent, it stopped at its usage limit, or it **failed for a non-limit reason** ("Codex failed": surfaced to the author, then degraded). In every unavailable case the gate proceeds without it, and the verdict reports the panel that actually ran. Only an *available, not-yet-clean* panelist blocks.

**"A4 converges" is not "gate clean".** Convergence is about panelists; the verdict is about evidence. An `unreproduced` correctness finding withholds the clean verdict until the author waives it, and where the panel's composition changed mid-run the verdict is reported **per round** — see *Exit conditions*.

### Phase B — Forge reviewer (only when one is available and the target is a PR/MR)

A **forge reviewer** lives on the code-hosting platform and is reachable only once the
change is a pull/merge request. It has three operations: **request**, **poll for
comments**, and **recognize a clean pass**. It is **not a panelist** — it never enters
R1 or R2, so the finding record and the auto-fix gate do not govern it; the *Tiers*
rules apply unchanged (T1 auto-fixed, T2/T3 to the author).

**The built-in adapter needs no enrollment.** A GitHub PR target with an authenticated `gh`
and `jq` reaches Copilot exactly as it did before the panel existed — zero config keeps the
roster it always had. *Enrollment* is how you **add** a declared reviewer or **opt out** of
Copilot (`enabled: false`), never a precondition for the adapter that ships.

**No forge reviewer available → skip Phase B silently.** No `gh`, no authentication, an
explicit opt-out, or a non-GitHub forge with nothing declared: the local panel is the whole
loop.

**GitHub Copilot is the one built-in adapter** (`adapter: builtin`), because
`scripts/copilot.sh` and `scripts/pr-comments.sh` implement those three operations and
have been exercised across many PRs. Steps B0–B5 below *are* that adapter.

**Other forges have review agents. This skill names none and implements none.** An
adapter written from documentation for a service nobody here can run is a ghost
panelist one layer up: it would poll forever, or report a clean pass that never
happened. A user with access declares the reviewer and supplies its commands —
`request`, `poll`, and a `clean_when` regex.

`clean_when` is load-bearing, and an unpinned regex *is* the false clean it exists to
prevent. A declared reviewer inherits the builtin's contract: `poll` must emit reviews
newest-first, one JSON object per line, each with a `body`; `clean_when` is a POSIX ERE
applied with `grep -Eq` to the **newest item's `body` only**, never to the whole poll
dump — matching the dump false-cleans forever the first time the bot ever said "no
comments". A `poll` that cannot satisfy the interface is declared wrong: say so at
enrollment and fall back to surface-and-ask. **If a declared reviewer has no unambiguous
clean signal, the loop polls, surfaces its comments, and hands the stop decision to the
author rather than inventing one.**

**B0. Ensure a PR exists.** If the target is a branch with no PR yet, open it now with `gh pr create` — **only after Phase A is clean** (the local gate comes before opening a PR). If a PR number was given, skip creation.

**B1. Request Copilot review** — get `copilot-pull-request-reviewer` onto the reviewer list before any polling, or the loop waits forever for a bot that was never asked:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh status <num>     # who's requested vs who reviewed
${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh request <num>    # add Copilot via gh pr edit --add-reviewer
```
First-time caveat: on some repos `gh pr edit --add-reviewer` returns 422 for the bot, and the GraphQL re-request can't run yet because it needs a bot node id that only exists once Copilot has reviewed. If `request` fails 422 and Copilot has never reviewed this PR, ask the author to trigger the first Copilot review through the GitHub UI once; every later round can then use `rerequest`.

**B2. Pre-scan** — `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh fetch <num>` (paginated reviews + inline comments). Group unresolved comments into tiers, then handle them per *Tiers*.

**B3. Re-request Copilot** after fixes push — Copilot won't re-examine otherwise: `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh rerequest <num>`. If Codex is **live** — enrolled, or present on a zero-config host — have it review the new commits headlessly **with `--json`**, so the post-round detector can run: `codex exec --json --sandbox read-only review --base "$base"`, or `codex exec --json --sandbox read-only resume "$thread_id" -` to continue the session. Without `--json` there are no `command_execution` items to count, and a sandbox that silently blocked the round would pass as a clean review. **Before** re-requesting Copilot (local gate first).

**B4. Poll** — `/loop 3m` re-run `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh fetch <num>`. New comments → re-classify → B2.
- **Copilot clean-pass stop signal:** when `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh clean-pass <num>` exits 0 (newest Copilot review matches `generated no (new )?comments.` — "generated no comments." on a first review, "generated no new comments." on a re-review), **STOP immediately** — cancel the cron/`/loop` job, do not schedule another poll. Post: "Copilot review is clean — no new comments." Then run the **After convergence — offer to group commits** step (Exit conditions) *before waiting* — without it the offer is unreachable on the GitHub path — and wait for the author's call (group commits / review / merge / more work).

**B5. Repeat-comment guard (NL-based)** — for each new comment, compare semantically against prior comments on the same file/line. "Does this raise the same concern as a prior one that already had a fix commit?" If yes → **stop**, post "Copilot re-raised <X> after <commit>. Prior fix didn't satisfy it. Your call." and wait. Fingerprint (file:line + first 40 chars) is an acceptable fallback heuristic; NL comparison is the primary signal.

## Exit conditions

- **Local gate clean + (for a forge target) the forge reviewer's clean pass** → stop and surface to the author. This is the primary, explicit stop signal — prefer it over inferring doneness from "no new comments for N polls".
- **"Clean" is not one verdict.** State the panel's composition and the evidential weight of its agreement:
  - **Heterogeneous** — at least one live tier-1 **CLI** panelist alongside Claude → convergence is meaningful evidence.
  - **User-asserted** — the only non-Claude panelist is a declared endpoint (`trust: user-asserted`). Report it as such; a config file must not buy the heterogeneous tier.
  - **Same-family** — Claude plus a different Claude model → "gate clean at tier 2 — same-family panel, shared blind spots possible; this is **weak evidence**."
  - **Fresh-context only** — the subagent's echoed model id equals the session model, is absent, or the requested model was not dispatchable. The weakest verdict there is. Say it.
  - Report the panel that **actually ran, verified**: the model that actually *differed* (the subagent echoes its model id on the first line of its record — a self-report, weak, and still better than asserting a tier from a config field), the CLI that actually returned findings. Where the composition changed mid-run, report it **per round**, not by its best round.
  - Any `unreproduced` correctness finding withholds "gate clean": report "clean except N unreproduced correctness findings" and let the author waive them.
- **Degradation.** Only Claude available → single reviewer, no cross-critique, and the same-family caveat above. Two or more Claude panelists and no external CLI → force **method-level divergence**, not tone (first principles / base rates / disconfirming evidence only); a role name like "Red Team" does not decorrelate errors, a different method or an actual reproduction does — and the verdict stays same-family either way.
- **Codex usage limit** → stop only the Codex sub-loop; the rest of the loop continues.
- **Merge** — never merge autonomously. Only on an explicit `merge` instruction. Default to a merge commit (`gh pr merge --merge`, not `--squash`) to preserve history; ask before deleting the branch, and prefer leaving the local branch in place for the author to prune. Honor the project's own merge conventions if they differ.

### After convergence — offer to group commits (assisted, never automatic)

When the loop reaches its clean/stop state and the current branch is a **non-default feature branch** carrying **≥ 2 commits** ahead of its target base, **offer** (ask — never do it automatically) to group the review fixups before merge.

- **Never on a primary/default branch.** Detect the default branch across the branch's configured remote `<r>` — `git symbolic-ref --short refs/remotes/<r>/HEAD` with the `<r>/` prefix stripped — falling back to the local `main`/`master`/`develop` set and the project's stated default. If detection is inconclusive and the branch isn't clearly a feature branch, **don't offer**. On the default/primary branch, skip silently.
- **Count** against the integration **target** base — the loop's inferred `$base` (`$base..HEAD`), **not** `@{upstream}..HEAD` (which is ~empty on a pushed PR branch). Capture the branch tip at loop start so the offer reports what the loop added; otherwise phrase it as "N commits ahead of base".
- **Offer:** "The loop added N commits to `<branch>` (incl. M fixups). Group them before you merge? Feature branch only — I'll keep a backup; if the branch has an upstream I'll force-push to it, else group locally (no push)." Decline → do nothing.
- **On accept — non-interactive grouping (`git rebase -i` is unavailable):**
  1. require a clean tree — if dirty (tracked or untracked), `git stash --include-untracked`; restore later with `git stash pop --index` (refuse if the index can't be restored);
  2. backup: `git branch <backup> HEAD`; and if the branch has an upstream, **capture the upstream SHA now, before any rewrite** — `lease=$(git rev-parse @{upstream})` — for the pinned lease in step 8 (capturing it later risks a fetch refreshing the tracking ref mid-rewrite and the lease then accepting a concurrent remote commit);
  3. capture the branch point as a fixed SHA — `bp=$(git merge-base "$base" HEAD)` — and `git reset --soft "$bp"` then `git reset` (reset to the captured SHA, **not** a moving ref);
  4. re-commit in the chosen groups (ask the shape: by area / coarse / squash) by staging paths per commit — grouping is **by file/area**, so per-commit splits within one file can't be reconstructed;
  5. verify tree-hash: `git rev-parse <backup>^{tree}` equals `git rev-parse HEAD^{tree}`;
  6. run the project's tests if present;
  7. restore the stash (if taken) — **before** any push;
  8. **push last, only if the branch has an upstream** (`@{upstream}` resolves): derive remote+ref from `%(upstream:remotename)`/`%(upstream:remoteref)`, and push with the lease pinned to the SHA captured **in step 2 (before the rewrite)**: `git push --force-with-lease=<remoteref>:$lease <remotename> HEAD:<remoteref>`. No upstream → group locally, **do not push or publish**;
  9. **abort/rollback on any failure before the push** — `git reset --hard <backup>`, restore the stash (remove operation-created untracked artifacts blocking it; never the user's content; if it still won't restore, STOP and surface `<backup>` + the stash entry), and do not push. Keep `<backup>` until verified success.
- **Invariants:** never overwrite remote commits the regrouped branch lacks; on any lease mismatch, abort and surface — never auto-retry. **Grouping preserves the base relationship; it does not advance onto a moved base** (the merge commit reconciles that; advancing is a separate, explicit, user-driven rebase). Never offer on a primary branch.

## Facilitator discipline

The facilitator (this session) frames, dispatches, validates, adjudicates, and fixes.
It may not put its own arguments in a panelist's mouth.

- Findings are **attributed** in the round output — `[codex]`, `[claude-fable]` — and a
  panelist's wording is preserved **verbatim**.
- The facilitator's own observations go under a separate, labelled **Facilitator**
  heading. They never count as panel findings and never gate anything.
- **Merged duplicates retain both verbatim texts and both attributions.** "These two are
  the same issue, I'll keep one phrasing" is the laundering the verbatim rule exists to
  stop. Two panelists slicing one problem into different buckets are **not** agreeing;
  recording them as one finding manufactures consensus.
- Any **downgrade, merge, or dismissal of a tier-1 panelist's finding is surfaced** with
  its reason. The facilitator may propose it; the author sees it.
- **An unexplained full reversal is a sycophancy flag.** A panelist that abandons a
  finding without a reason, or concedes every attack, is asked for the grounds before the
  reversal is accepted. This ask is one extra panelist call and is the single sanctioned
  exception to "cross-critique is one round" (the other being Round 3 with ≥3 panelists).

Tiering (T1/T2/T3) remains facilitator judgement: scope-of-fix is not something a
reviewer can assess for a repo it does not own.

## Ghost panelist gate

A status line, an empty result, or an error dump is **not a contribution**. If one enters
the record, R2 critiques thin air and the panel degrades silently.

- **Codex, native path:** the existing structural `command_execution` detector, unchanged.
  Embedded-diff rounds stay exempt; **R2 critique rounds are now exempt too** (A2).
- **Every other panelist:** the return must be a substantive review — findings, or an
  explicit "no remaining problems". Re-run once; on a second failure **drop the panelist,
  continue, and disclose which panel actually ran**.
- **External CLIs run in the foreground** with a generous timeout (≈10 min). A wrapper
  that backgrounds the call and returns early manufactures ghosts.

## Learning capture

After each round, append to a review journal in the repo (e.g. `.claude/pr-review-journal.md`, create if absent):
- Target (PR # or branch), round N, which reviewer raised it (Claude / Codex / Copilot)
- Comment → fix pattern
- T3 decisions + chosen approach + why
- Repeat-issue escalations (these = gaps in the project's conventions; candidates for the project's guidelines doc)
- **R2's kill rate and rounds consumed.** Cross-critique costs one extra call per panelist before the first fix, and usage limits are a first-class outcome — so the marginal cost is not "one more call" but "one fewer convergence round before the limit". That R2 pays for itself (false positives dying before they become a commit, a test, and a convergence round) is a **hypothesis**. Record the data so it can be checked.

Periodically distill recurring patterns into the project's conventions/guidelines doc.

## Non-goals

- Not fully autonomous. The author decides T2/T3 fixes and the final merge.
- Not a squash-merge tool. Default to a merge commit to preserve history.
- The **built-in** forge adapter is GitHub-only (it uses `gh` + GitHub GraphQL). Other forges are reachable by declaring a reviewer and its three commands; none ships. With no forge reviewer, the local panel gate is the whole loop.
- **Not changing:** the sandbox routing, the embedded-diff form, the `command_execution` detector's **jq predicate**, exit-code triage, the Copilot adapter's behavior, or the never-merge rule. Two things *do* change and are named so nobody can satisfy this list by ignoring them: the detector's **scope** gains an R2-critique exemption (A2), and Phase B's *framing* becomes a forge slot while its Copilot behavior is preserved verbatim.
- **Not a debate machine.** With the default two-panelist panel, cross-critique is **one round**. Two bounded additions: a separate Round 3 with **≥ 3** panelists, and the reversal-grounds ask. Panelist disagreement about executable code is settled by a test, not by more rounds.
