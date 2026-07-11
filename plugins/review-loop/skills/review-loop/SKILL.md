---
name: review-loop
description: General assisted review loop for changes — code or design artifacts (specs, plans, docs). Local reviewers answer blind and in parallel on the same unfixed diff, before any fix; the verdict names which reviewers actually ran. The roster is enrolled per host by `/review-loop:init`, which is never a precondition. For PR/MR targets a forge reviewer follows the local gate; GitHub Copilot is the built-in adapter and needs no enrollment. Findings say what would disprove them, and are reproduced before they are acted on. Never merges autonomously.
---

# Review Loop (Assisted)

Assisted, not autonomous. Preserves the author's architectural voice and learning across review cycles. General-purpose: the target may be a **local branch / working diff** (no remote needed) or a **GitHub PR**, and the changes under review may be **code or design artifacts** (specs, plans, docs).

**Local reviewers are preferred and run first.** The enrolled roster (§ Reviewer roster) — a Claude subagent, any other Claude models or CLIs you enrol, and Codex when it is enrolled (or, with no config, whenever it is present) — reviews the local diff **blind and in parallel**, and this is the first gate; it costs little and works on any host. A config that intentionally omits Codex is honoured; a present-but-unenrolled Codex is noted, not auto-run (§ Roster reconciliation). Codex runs headless via the `codex` CLI — no tmux needed; tmux only adds a live-watch pane **when the user asks to watch** (never by default). A forge reviewer (GitHub Copilot) is added only when the target is a GitHub PR, and only after the local gate is clean.

## Why this loop exists

A second look finds what the first missed. That is certain, and it does not need a second model family: a reviewer that has not seen its own earlier reasoning is a longer chain of thought with a clean context. Whether *different* model families catch *different* holes is plausible and unmeasured — so heterogeneity is a bonus here, never a gate. What matters is that the reviewers look at the **same unfixed diff**, that none of them sees another's findings first, and that the verdict says which ones actually ran. Serial review cannot do this: a reviewer shown the already-fixed tree is anchored on the first reviewer's judgement and can no longer dispute it. (Full rationale, the two hypotheses graded, and credit to the MIT-licensed `makinux/adversarial-panel`: `references/why-adversarial.md`.)

## Requirements

- **Always usable:** the Claude subagent reviewer needs nothing extra. `/review-loop:init`
  can pin it to a *different* Claude model — the cheapest strengthening available, and it
  needs no second CLI.
- **The roster is enrolled, not assumed.** Which reviewers this host can field is answered
  by a `command -v` sweep at loop start, plus `~/.claude/review-loop.local.md` (enrollment,
  and the invocation recipe `/review-loop:init` learned by actually calling each CLI). With
  no config the loop fields the same roster it always did; `init` is never a precondition.
- **Codex reviewer (optional):** the `codex` CLI on `PATH`. If Codex was **never enrolled** and is absent, the step is skipped silently; if it was **enrolled** but is absent, the loop says so and grades the verdict (§ Roster reconciliation) — an enrolled reviewer that did not run is never a silent skip. `jq` is used to capture the resume `thread_id` from `codex`'s `--json` stream — without `jq`, resume just falls back to `--last` (§ Convergence rounds). (tmux is **not** required — it only adds a live-watch pane **when you ask to watch**; see § Codex mechanics.)
- **Forge reviewer (optional):** the one built-in adapter is GitHub Copilot, which needs the
  **authenticated** `gh` CLI and `jq`, and runs only for GitHub PR targets. It needs **no
  enrollment** — zero config reaches it exactly as before. Presence of `gh` is not
  authentication. Enrollment adds a *declared* reviewer on another forge, or opts out of
  Copilot. With no forge reviewer available, Phase B is skipped and the local reviewers are
  the whole loop.

The skill and helper scripts resolve their CLI dependencies (`codex`, `gh`, `jq`, plus `tmux` only for the live-watch pane (used only when you ask to watch)) from `PATH`, so the skill is self-contained and portable across machines.

## Inputs

- **Target** — one of:
  - a **local diff/branch** (default: current branch vs its base), or
  - a **GitHub PR number** (or a branch that already has an open PR → treat as GitHub target).
  - The diff may contain code, design artifacts (specs, plans, docs), or both — the loop reviews whatever changed.
- Repo / base branch inferred from the current working directory.

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

## Helper scripts

Prebuilt so you don't re-derive the same commands each run. All in `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/`, executable:

- `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh {status <pr> | request <pr> | rerequest <pr>}` — manage the Copilot reviewer. `request` uses `gh pr edit --add-reviewer`; `rerequest` uses the GraphQL `requestReviews` mutation. Note: the first-ever Copilot review may need a one-time request through the GitHub UI (see B1).
- `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh {fetch <pr> | clean-pass <pr>}` — paginated fetch of reviews + inline comments; `clean-pass` exits 0 when Copilot's newest review is a clean pass.

Reach for these first. Only hand-write a command when a script genuinely doesn't cover the case.

## Tiers (used for every reviewer's comments)

- **T1 mechanical**: typos, lint, null checks, test-only changes, doc fixes, rename within one file.
- **T2 local refactor**: method extraction, variable naming across a module, added validation.
- **T3 architectural**: file/module moves, API shape, "should this exist", simplification, scope cuts.

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

## Flow

### Phase A — Local review (always first)

**A0. Author pass first** — before touching anything, ask: "Any simplifications you'd collapse across these changes before I start?" Capture as a commit-plan override.

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
- **Codex, native path — the *freeform* form, because the first round needs a prompt.** A target flag takes
  none (`review --uncommitted -` errors rc=2), and the prompt is where the finding record is
  requested. The freeform form does take one:
  ```bash
  brief="Review the change for the range ${base}...HEAD (a git three-dot range).
  FIRST LINE of your reply: state that range and the file list you actually reviewed.
  Then a findings list, most-severe first; for each finding give: your claim, its file:location,
  a tier (T1 mechanical / T2 local refactor / T3 architectural), and a concrete falsification
  condition ('not a defect if X'). No preamble; your final message is the review record."
  printf '%s\n' "$brief" | codex exec --json --sandbox read-only review -
  ```
  `$brief` names the exact range `<base>...HEAD` — three dots, the same range the check
  below runs — and requests the finding record (the reviewer / claim / location / tier /
  falsification-condition structure of *Reviewers are asked what would show a finding wrong*).
  **An inferred diff may not be the same diff, and this is the blind round**, so the brief
  requires the review to state, as its first line, the range and file list it actually reviewed;
  the facilitator compares that against `git diff --name-only "$base"...HEAD`. A mismatch →
  re-run once with the diff embedded, which cannot be inferred wrong; a second mismatch → drop it,
  continue, disclose (*Ghost reviewer gate*).
- **Codex, embedded path** — unchanged. It carries a prompt too, so the record is requested the
  same way.
- **Any other enrolled CLI or endpoint** — the stored `invocation.command`, with the diff and the
  record format in the prompt. No resume protocol is assumed for anything but Codex.

**Cross-critique is recommended, and gates nothing** — and it happens **before any fix is
committed**, which is the whole point: with two or more reviewers, showing each the others'
findings and asking them to attack is cheap and it kills false positives before they become
commits. Ask for the claim they *tried hardest to break*, and whether it held — never "you
disagree with at least one central claim; find it", which manufactures a refutation when the other
reviewer is right. A round that refutes nothing is a legitimate outcome; a round that **attacks**
nothing is the failed one. But a finding is actionable when it is **reproduced**, not when it
survives an argument: disagreement about executable code is settled by a test.

**Then** classify the surviving findings into T1/T2/T3, post the grouped list, resolve T2/T3 with
the author, and apply fixes per *Tiers*. Commit fixes; push only if a remote/PR branch exists.

#### Codex mechanics — how the Codex reviewer is driven

This section is **not a step**. It is the machinery the Codex reviewer runs on wherever it appears
above: blind in A1, and again when convergence re-checks the fixed diff. It applies only if
`codex` is live. **Never enrolled and absent → skip silently. Enrolled and absent → say so** and
grade the verdict (*Roster reconciliation*): a reviewer the author asked for and did not get is
not a silent skip. Codex runs **headless** via `codex exec` — no tmux, no pane. The `review`
subcommand is read-only by construction; Codex *finds* issues, Claude applies fixes.

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

- **Resolve the target into the working tree first.** `codex exec review` reviews the *current checkout*, so before reviewing, make the checkout match the requested target: for a `<branch>` target, `git checkout` it (or run from its worktree); for a `<PR-number>` target, `gh pr checkout <num>` first. Only then does `review --base "$base"` (or `--uncommitted`) look at the right diff. (If checkout isn't possible, **don't** pipe a diff into `review -`: both `codex exec -` and `review -` read the *prompt / instructions* from stdin, **never** a diff or review target — so it would still review the current checkout. Instead use the embedded-diff form (§ Codex mechanics): put the diff in the prompt, e.g. `codex exec --json --sandbox read-only "Review this diff for correctness, design, and risk:\n$(gh pr diff <num>)"` — or tell the author the PR can't be reviewed without checkout.)

- **Route by sandbox state, not by target.** The preflight `$sandbox` decides which Codex form is primary:
  - `usable` → native `review` (below): it reads the local tree directly, correct for pushed *and* unpushed targets (no remote fallback happens).
  - `broken` / `unknown` → **embedded-diff form** (below): native may be unable to read the tree (a `broken` host falls back to the connected GitHub repo, which for a local-only target silently false-cleans; `unknown` is inconclusive — bwrap absent, working Landlock, or an unrecognized failure), so route conservatively. Embedding the diff sidesteps the sandbox entirely, so it is safe for every target on such a host. This also skips the wasted false-clean round on the common docs-to-`main` (unpushed design-artifact) case.

  The **local-only** check is routing rationale (it explains *why* a broken host is dangerous), not a separate gate — it never overrides a `usable` sandbox. Detect local-only per target mode (heuristic, not proof — remote-tracking refs can be stale, so optionally `git fetch` first; the post-round detector is the real backstop): `--commit <sha>` → `git branch -r --contains <sha>` empty; `--base <base>` → any commit in `<base>..HEAD` unreachable (an unpushed `HEAD` ⇒ treat the whole target as local-only); `--uncommitted` → inherently local-only.

- **Embedded-diff form (the `broken`/`unknown` path).** Put the diff *into the prompt* — no sandboxed subprocess is needed to read the tree, so the failure cannot occur. It carries the **same `$brief`** (the finding-record request from A1) as the freeform form, so the structured record is requested the same way; only the diff delivery differs. Keep `--json` (captures `thread_id` for resume):
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"
  rc=0
  # $brief: assemble it here exactly as in A1 (the finding-record request) — it is a per-round
  # variable, not inherited from another code block, so define it on whichever path actually runs.
  printf '%s\n\n%s\n' "$brief" "$(git show "$sha")" \
    | codex exec --json --sandbox read-only - >"$round" 2>"$err" || rc=$?   # trailing - reads the PROMPT ($brief + embedded diff) from stdin
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
  On a `usable` sandbox prefer native `review --uncommitted` instead (it covers all three directly).

- **First round — the freeform prompt-bearing `review -` form, with `--json`.** This is the round whose session id we need, so run it with `--json` and capture `thread_id` for resume (§ Convergence rounds). `--sandbox read-only` goes **before** the subcommand. Target flags take **no** prompt (`review --uncommitted -` errors rc=2), so a targeted form *cannot* carry the finding-record request the blind round needs — the first round therefore pipes `$brief` into freeform `review -`, and names the range in prose (§ A1). The targeted forms stay available where no prompt is needed (B3):
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"
  rc=0
  printf '%s\n' "$brief" \
    | codex exec --json --sandbox read-only review - >"$round" 2>"$err" || rc=$?   # A1: freeform, carries the prompt
  # $brief names the range <base>...HEAD (three dots — matches the name-only check) and
  # requests the finding record. Targeted forms take NO prompt and so cannot serve A1. They remain
  # available where none is needed — see B3: review --base "$base" · review --uncommitted
  cat "$round" >>"$log"   # feed the watch pane
  [ "$rc" = 0 ] && thread_id=$(jq -r 'select(.type=="thread.started") | .thread_id' "$round" 2>/dev/null | head -1) || true   # parse only on success; non-fatal (no id → --last fallback). jq, not regex.
  ```
  With `--json` the stdout is a JSON **event stream**: Claude reads the review content from the assistant/agent-message events in `$round` and classifies it into T1/T2/T3, **and** extracts `thread_id` for resume. The human-readable findings still reach the author via Claude's own relayed tier list (Claude relays regardless), so JSON-on-stdout is fine.
  For **custom focus** (e.g. steering a doc-artifact review), use the freeform form — no target flag, Codex infers the diff itself; name the target in prose. Keep `--json` here too, so a focused first round still captures `thread_id` for resume (otherwise convergence falls back to `--last`):
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"
  rc=0
  printf '%s\n' "Review the changes against main as a design artifact: clarity, consistency, factual accuracy, gaps. No tests here." \
    | codex exec --json --sandbox read-only review - >"$round" 2>"$err" || rc=$?
  cat "$round" >>"$log"
  [ "$rc" = 0 ] && thread_id=$(jq -r 'select(.type=="thread.started") | .thread_id' "$round" 2>/dev/null | head -1) || true   # parse only on success; non-fatal (no id → --last fallback). jq, not regex.
  ```
  The blind first round (A1) **always** uses the prompt-bearing freeform form — it must carry `$brief` to request the finding record. The targeted forms (`review --base`, `review --uncommitted`) carry no prompt and so are for later rounds where none is needed (B3), never for A1.

- **Capture the exit status, don't pipe it away.** Never `codex … | tee` — that makes `$?` reflect `tee`, not Codex, and the three-outcome split below needs Codex's real exit code. Redirect stdout to the per-round `$round` file and stderr to `$err`, capturing the code set-e-safely (`rc=0; … || rc=$?`, never a bare `; rc=$?`), then `cat "$round" >>"$log"` for the watch and read `$round` for classification.

- **Model / effort — defer to the user's Codex config.** Pass **no `-m` and no reasoning-effort override**: `codex exec review` honors `~/.codex/config.toml`'s `review_model` (falling back to the session default). Only if the author names a model for the session ("use gpt-5.4") pass `-m` for the rest of the loop.

- **Three outcomes** after each call — branch on `rc`:
  - **`rc == 0` → first confirm Codex actually read the tree, *then* read the review.** Read **this round's `$round`** (not the cumulative `$log`). **Post-round detector (the guarantee) — all native-path rounds (initial `review`, `resume`, and the fresh native fallback):** a native round that ran **zero `command_execution` items** never executed a local command, so it never read the tree (a sandbox false-clean). `codex exec --json` nests item kinds under `.item.type`, not top-level `.type`, so test:
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

- **Freeform plain-exec fallback (rare).** Drop to `codex exec "<instructions + diff>"` only when (a) the installed `codex` is too old to have `exec review`, or (b) the target is **not** a git diff (e.g. a pasted artifact outside any repo) — in case (b) **only**, add `--skip-git-repo-check` (unnecessary on the normal `review`/`resume` paths).

- **Local, unpushed commits on `main` are a first-class case, not an edge case.** Under the docs-to-`main` convention, design-artifact reviews routinely target a freshly-committed, unpushed commit on `main`. On a `broken`/`unknown` host that is exactly where native `review` silently false-cleans (it falls back to the remote, which lacks the commit) — which is why the Codex mechanics route these to the embedded-diff form and guard every native round with the post-round detector.
- **Host fixes (optional).** If you want the native `review` path back on a host where the preflight reports `broken`, see `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/references/codex-sandbox-host-fixes.md` — a menu (bwrap-userns-restrict, legacy-landlock, …). The skill never applies these; embedded-diff already works with no host change.

**A3. Converge the local gate** — re-run A1 (all live reviewers) after fixes until Claude is clean **and** Codex is clean *when available*. "Done" for Codex means any of: clean review, **or** Codex was unavailable this run — the `codex` CLI is absent, it stopped at its usage limit, or it **failed for a non-limit reason** (the "Codex failed" path — surfaced to the author, then degraded to Claude-only). In every unavailable case the gate proceeds on Claude alone; only an *available, not-yet-clean* Codex blocks. Only then proceed.

### Phase B — GitHub Copilot (only for GitHub PR targets)

**B0. Ensure a PR exists.** If the target is a branch with no PR yet, open it now with `gh pr create` — **only after Phase A is clean** (the local gate comes before opening a PR). If a PR number was given, skip creation.

**B1. Request Copilot review** — get `copilot-pull-request-reviewer` onto the reviewer list before any polling, or the loop waits forever for a bot that was never asked:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh status <num>     # who's requested vs who reviewed
${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh request <num>    # add Copilot via gh pr edit --add-reviewer
```
First-time caveat: on some repos `gh pr edit --add-reviewer` returns 422 for the bot, and the GraphQL re-request can't run yet because it needs a bot node id that only exists once Copilot has reviewed. If `request` fails 422 and Copilot has never reviewed this PR, ask the author to trigger the first Copilot review through the GitHub UI once; every later round can then use `rerequest`.

**B2. Pre-scan** — `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh fetch <num>` (paginated reviews + inline comments). Group unresolved comments into tiers, then handle them per *Tiers*.

**B3. Re-request Copilot** after fixes push — Copilot won't re-examine otherwise: `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh rerequest <num>`. If `codex` is on `PATH`, have Codex review the new commits headlessly (`codex exec --json --sandbox read-only review --base "$base"`, or `printf '%s\n' "review the latest commits" | codex exec --json --sandbox read-only resume "$thread_id" -` to continue the session — `resume … -` reads its instruction from stdin, so it must be piped one) **before** re-requesting Copilot (local gate first).

**B4. Poll** — `/loop 3m` re-run `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh fetch <num>`. New comments → re-classify → B2.
- **Copilot clean-pass stop signal:** when `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh clean-pass <num>` exits 0 (newest Copilot review matches `generated no (new )?comments.` — "generated no comments." on a first review, "generated no new comments." on a re-review), **STOP immediately** — cancel the cron/`/loop` job, do not schedule another poll. Post: "Copilot review is clean — no new comments." Then run the **After convergence — offer to group commits** step (Exit conditions) *before waiting* — without it the offer is unreachable on the GitHub path — and wait for the author's call (group commits / review / merge / more work).

**B5. Repeat-comment guard (NL-based)** — for each new comment, compare semantically against prior comments on the same file/line. "Does this raise the same concern as a prior one that already had a fix commit?" If yes → **stop**, post "Copilot re-raised <X> after <commit>. Prior fix didn't satisfy it. Your call." and wait. Fingerprint (file:line + first 40 chars) is an acceptable fallback heuristic; NL comparison is the primary signal.

## Exit conditions

- **Local gate clean + (for a forge target) the forge reviewer's clean pass** → stop and surface to the author. This is the primary, explicit stop signal — prefer it over inferring doneness from "no new comments for N polls".
- **"Clean" is not one verdict — but naming the panel is disclosure, not a ranking.** Same-family review is **never reported as a downgrade**: multiple passes, same family or not, are the strong hypothesis at work, and this project's history shows same-family reviewers finding a false premise, a class of test weakness, and four weak anchors. The verdict adds one honest note about what was and was not exercised this run:
  - **A cross-family reviewer ran** (a coding CLI alongside Claude) → the decorrelation bonus was exercised: agreement across families is less likely to share a blind spot.
  - **The panel was all one family** (Claude models only, however many) → say so plainly, as a fact, not a demerit. The multi-pass value is real and delivered; the cross-family bonus simply was not exercised this run — a note for the reader, not a verdict of "weaker".
  - **Only the session's own model ran** → still a genuine fresh-context pass; note no second reviewer participated, so the author can add one via `/review-loop:init`.
  - A user-declared endpoint never counts as a cross-family voice, whatever the config says.
  - Report what **actually ran, verified**: the CLIs that returned findings, and the models that actually *differed*. The subagent echoes its model id on the first line — a self-report, weak, and better than asserting composition from a config field. Where a check is weak, report the verdict it supports and no stronger — but **never let a weak check downgrade a same-family pass**.

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

After each round, append to a review journal in the repo (e.g. `.claude/pr-review-journal.md`, create if absent):
- Target (PR # or branch), round N, which reviewer raised it (Claude / Codex / Copilot)
- Comment → fix pattern
- T3 decisions + chosen approach + why
- Repeat-issue escalations (these = gaps in the project's conventions; candidates for the project's guidelines doc)

Periodically distill recurring patterns into the project's conventions/guidelines doc.

## Non-goals

- Not fully autonomous. The author decides T2/T3 fixes and the final merge.
- Not a squash-merge tool. Default to a merge commit to preserve history.
- The Copilot path is GitHub-only (uses `gh` + GitHub GraphQL). For other forges, the local reviewer gate (the enrolled roster — a Claude subagent, others you enrol, Codex when present) still applies; the remote-reviewer phase does not.
