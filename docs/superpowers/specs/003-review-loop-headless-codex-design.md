# 003 — `review-loop`: headless Codex via `codex exec review` (supersedes 002 § Phase A)

## Goal

Change *how the agent talks to Codex* in the `review-loop` skill. Today the agent
drives an interactive `codex` TUI **through a tmux pane** — it splits a window,
pastes the diff via a tmux buffer, and scrapes the reply back with
`capture-pane`. This conflates two unrelated concerns: the **communication
channel** (agent ↔ Codex) and **human spectating** (watching the review happen
live). The agent does not need tmux to talk to Codex; `codex exec` returns the
review as clean captured stdout with an exit code that reliably signals
failure/limit, from anywhere `codex` is on `PATH`. (The *review content* is still
judged by Claude, as today — the exit code only disambiguates failure, not
clean-vs-findings.)

This spec replaces the tmux-pane mechanism with the headless, purpose-built
**`codex exec review`** subcommand (+ `codex exec resume` for convergence rounds),
and demotes tmux to an **optional live-watch layer** the human can opt into. It
supersedes **only Phase A2 (and the dependent Requirements / Helper-scripts /
reviewer-roster text) of spec 002** — the tier model, the Copilot phase (B), the
assisted/never-auto-merge stance, and the all-artifacts target scope are unchanged.

## Background

Spec 002 packaged `review-loop` as a dong3 plugin. Its Phase A2 ("Codex review")
runs Codex only when `$TMUX` is set, via `scripts/codex-pane.sh`
(`find | ensure | send | capture | usage-limited`). Every fragile behavior lives
in that script: paste-then-Enter timing, "is the reply done?" scraping,
trust/onboarding-prompt grepping, and usage-limit detection by matching text on a
live TUI. When `$TMUX` is unset the Codex gate is **skipped entirely** — so
headless, cron, and non-tmux interactive runs never get a Codex review at all.

The realization, confirmed against the installed `codex` CLI:

- `codex exec` is non-interactive — it runs, prints to stdout, and exits. No pane,
  no scraping, no trust prompt (a non-interactive exec cannot show one).
- `codex exec review` is a **purpose-built code-review subcommand**:
  `--uncommitted` (staged + unstaged + untracked), `--base <branch>`,
  `--commit <sha>`, optional custom instructions via a `[PROMPT]` arg (`-` = read
  from stdin). It does its own diff/target selection — no hand-built diffs — and is
  read-only/non-destructive (the local `/review` never touches the working tree).
- `codex exec resume [SESSION_ID] [PROMPT]` resumes a prior session by **UUID or
  thread name** (or `--last` for the most recent). Resuming keeps Codex's memory of
  the comments it already made, so "are these resolved?" is a real signal.

tmux was only ever required for a human to *watch*; the channel never needed it.

## Scope

> Paths below are relative to the plugin root,
> `plugins/review-loop/skills/review-loop/`.

### In scope (this PR)

- **`SKILL.md`** — rewrite Phase A2; update the intro paragraph, **reviewer-roster
  item 2**, the **Requirements** entry for the Codex reviewer, the
  **PATH-dependency note**, the **Helper scripts** section, and the `description`
  frontmatter line — *all* currently assert the tmux gate. Document the
  `codex exec review` invocations **inline** (no Codex helper script).
- **Delete `scripts/codex-pane.sh`** entirely.
- **`commands/review-loop.md`** — overlooked consumer: its "Local gate first"
  invariant also asserts the `$TMUX`/tmux-pane gate; drop it to match (Codex gates
  on `codex` on `PATH`, tmux is optional live-watch).
- **`README.md`** — update reviewer-roster / requirements prose (Codex needs only
  `codex` on `PATH`; tmux is optional live-watch).
- **`.claude-plugin/marketplace.json`** — bump the `review-loop` plugin version.
  Leave `metadata.version` (no plugin added/removed).
- **Project `CLAUDE.md`** — update the one-line `review-loop` gloss that says
  "Codex in a `tmux` pane."

### Out of scope (follow-up)

- The **global** `~/.claude/CLAUDE.md` review-loop note ("Codex review applies only
  inside tmux (`$TMUX` set); skip silently otherwise") goes stale. Different repo
  (`~/.claude`); flag it for the author, don't edit it here.
- `copilot.sh` and `pr-comments.sh` are **untouched** — entirely GitHub-side.
- No change to the tier model, Copilot phase, target scope, or merge stance.

## Design

### 1. Channel — `codex exec review` (replaces Phase A2)

The agent runs Codex non-interactively and reads stdout directly. The `review`
subcommand is read-only by construction; for safety the examples still pin
`--sandbox read-only` as a top-level option (it must come **before** the
subcommand). Codex's job is to *find* issues; Claude applies fixes (TDD, one commit
per item, author decides T2/T3) — Codex never edits the tree.

**First round — map the loop's target to a `review` invocation.** The target flag
and a `[PROMPT]` are **mutually exclusive** (`codex exec review --uncommitted -`
errors: *"the argument '--uncommitted' cannot be used with '[PROMPT]'"*, rc=2).
So there are two modes:

*Targeted (primary) — explicit diff, built-in review behavior, no custom prompt.*
The first round runs with `--json` because it is the round whose session id the
loop needs for resume (§5): `--json` makes stdout a JSON **event stream**, from
which Claude reads the review text (assistant/agent-message events) to classify
into T1/T2/T3 **and** parses `thread_id`. The human still gets the findings via
Claude's relayed tier list (Claude relays regardless), so JSON-on-stdout costs the
author nothing.

```bash
# branch vs its base (the loop's default target)
codex exec --json --sandbox read-only review --base "$base" >>"$log" 2>"$err"; rc=$?
thread_id=$(grep -oE '"thread_id":"[^"]*"' "$log" | head -1 | sed 's/.*:"//;s/"//')

# other targets:
#   review --uncommitted     # working tree (uncommitted spec/plan/code, no branch yet)
#   review --commit "$sha"   # a single commit
```

The built-in review reviews the selected diff for correctness/design/risk and
handles a Markdown/doc diff sensibly on its own (verified) — no steering needed for
the common case.

*Freeform (to add focus) — Codex infers the diff itself; no target flag:*

```bash
# e.g. steer a doc-artifact review; name the target in prose since no flag is allowed
printf '%s\n' "Review the changes against main as a design artifact: clarity,
consistency, factual accuracy, gaps. No tests here." \
  | codex exec --sandbox read-only review - \
      >>"$log" 2>"$err"; rc=$?    # append stdout (cumulative log); capture rc (see below)
cat "$log"                        # ... then surface it; tail -f also shows it
```

Use the targeted form by default; reach for the freeform form only when custom
focus is worth giving up the explicit target flag.

**Capture the exit status, don't pipe it away.** Piping `codex … | tee` would make
`$?` reflect `tee`, not Codex — and §4's three-way outcome split depends on Codex's
real exit code. So the loop **redirects** Codex's stdout to the per-run log
(`$log` = `/tmp/review-loop-codex.<runid>.log`) and stderr to `$err`, captures
`rc=$?` immediately, then displays the log. The optional `tail -f` spectator pane
(§3) already follows `$log`, so nothing extra is needed to show it live.

**Model / effort — defer to the user's Codex config.** Pass **no `-m` and no
reasoning-effort override**. `codex exec review` honors the user's
`~/.codex/config.toml` `review_model` (a key whose entire purpose is "a consistent,
higher-reasoning model for reviews regardless of the day-to-day session model"),
falling back to their session default if unset. Nothing to drift; respects the
user's own review config. If the author names a model for the session
("use gpt-5.4"), pass `-m` for the rest of the loop — otherwise no prompt.

**Convergence rounds — resume the same session (§5):**

```bash
printf '%s\n' "I applied these fixes: <summary>. Are your earlier points
resolved? Any new concerns?" \
  | codex exec --sandbox read-only resume "$session_id" - \
      >>"$log" 2>"$err"; rc=$?    # same safe-capture pattern as the first round
cat "$log"
```

First round uses `review`; later rounds `resume` the captured session so Codex
remembers its prior comments. Fallbacks in §5.

**Fallback to freeform `codex exec` (rare).** The `review` subcommand is the
mandatory primary path. Drop to freeform `codex exec "<instructions + diff>"` only
when (a) the installed `codex` is too old to have `exec review`, or (b) the target
is **not a git diff** (e.g. reviewing a pasted artifact outside any repo). In case
(b) — and only there — add `--skip-git-repo-check`; on the normal `review`/`resume`
paths it is unnecessary (the loop reviews inside a git repo) and is omitted.

### 2. Inline, not a helper script

The invocations above live directly in `SKILL.md` prose. There is **no**
replacement for `codex-pane.sh` — the `review` subcommand absorbs everything the
script used to do (target selection, read-only, single-shot). `copilot.sh` and
`pr-comments.sh` remain: they wrap genuinely fiddly GitHub REST/GraphQL pagination
a one-liner cannot.

### 3. tmux — optional live-watch only (channel/spectating decoupled)

The channel is *always* `codex exec`. tmux is a pure observability add-on:

- Each loop run uses a **per-run** log/err path (`<runid>` = e.g. PR number, branch
  slug, or `mktemp` suffix), truncated/created at loop start — so concurrent or
  back-to-back runs never read each other's stale findings.
- Each invocation **appends** its stdout to that per-run `$log` (`>>`), so the log
  is cumulative across rounds; `$err` is overwritten per attempt (§4 only inspects
  the current round's stderr). Stdout is appended, not piped through `tee`, so
  Codex's own exit status survives (§1).
- **If `$TMUX` is set**, spawn one read-only spectator pane **before the first
  `codex exec` call** (right after the per-run log setup), so it covers round 1.
  The pane follows the per-run log — for round 1 that log is a JSON event stream;
  the human's authoritative summary is still Claude's relayed tier list, the pane
  is a raw-feed spectator aid:
  ```bash
  [ -n "${TMUX:-}" ] && watch_pane=$(tmux split-window -h -P \
    -F '#{session_name}:#{window_index}.#{pane_index}' \
    "tail -f /tmp/review-loop-codex.<runid>.log")
  ```
  The agent **never reads from this pane** — it reads `codex exec`'s stdout. All
  rounds append to the same log, so the single spectator pane keeps showing them.
- **Teardown:** when the loop ends (clean, usage-limit fallback, or abort), close
  the spectator pane (`tmux kill-pane -t "$watch_pane"`) so it doesn't linger as an
  orphan (per the project's no-orphan-process rule).
- **No tmux?** Codex still runs (the key win). The human sees Codex's findings
  relayed in Claude's own grouped tier list, exactly as for the Claude subagent
  reviewer.

### 4. "Clean", "failed", and "usage-limited" — three distinct outcomes

No more TUI scraping. After each `codex exec` call, branch on the result:

- **Exit 0 → read the review (NL judgment).** Codex's review is plain stdout;
  Claude classifies it into T1/T2/T3 or judges "no remaining problems," the same
  way it handles its own subagent review. No grep, no parsing.
- **Non-zero exit *with* a limit message in stderr** (matching the existing
  `usage limit|rate limit|quota|too many requests|try again later` set) → **usage
  limited.** Stop the Codex sub-loop, note the fallback to Claude-only local review
  (+ Copilot for GitHub targets), continue.
- **Non-zero exit *without* a limit match → Codex failed** (bad flag — e.g. the
  `--uncommitted -` conflict rc=2; no git repo; invalid base branch; auth failure).
  Do **not** silently fold this into the usage-limit fallback — surface it to the
  author with the stderr summary, then degrade to Claude-only per the existing
  policy. (A read-only review in an untrusted/first-run dir was verified to
  *proceed* — rc=0 — not hard-fail, so no dedicated trust branch is needed; should a
  future codex add a trust gate, its non-zero exit lands here.)

**Future option (not shipped now):** `codex exec --output-schema <file>` can
constrain the final response to a JSON verdict+severity+issue list for a
deterministic stop signal. Documented as a future enhancement; the NL-judgment path
above ships first (keeps the skill file-light, matching the subagent path).

### 5. Session continuity — resume by id (primary), `--last` / fresh (fallbacks)

`codex exec resume [SESSION_ID]` accepts a UUID or thread name, so id-based resume
is the **normal design**, not best-effort:

- **Capture round 1's session id** from the `--json` stream's **`thread_id`** field
  (verified: codex-cli 0.135.0 emits `"thread_id":"<uuid>"`; not `session_id`).
  Run the first round with `--json`, parse `thread_id`, store it for the loop.
- **Resume by id** on every convergence round: `… resume "$session_id" -` (resume's
  trailing `-` for the stdin follow-up prompt is valid — only the `review` target
  flags conflict with a prompt, `resume` does not).
- **Fallbacks, in order:** if no id was captured → `resume --last` (with the caveat
  below); if `resume` fails (session expired/missing) → fall back to a **fresh
  `codex exec review`** with the prior findings restated as a freeform prompt
  (`review -`, no target flag), so a round never silently loses the review.
- **`--last` caveat:** `--last` resumes the most recent session in this directory
  (cwd-scoped unless `--all`); if the author starts an unrelated `codex` session in
  the same repo mid-loop it becomes the new "last." Id-based resume avoids this; the
  caveat is documented for the `--last` fallback.

### 6. Requirements / reviewer-roster / Helper-scripts / description text

- **Requirements** — the Codex-reviewer bullet drops the `$TMUX` requirement: it
  needs only the `codex` CLI on `PATH`. tmux is listed under an optional
  "live-watch" note. The PATH-dependency note no longer lists `tmux` as required.
- **Reviewer roster** — item 2 ("Local Codex") no longer gates on `$TMUX`; it gates
  on `codex` being on `PATH`.
- **Helper scripts** — remove the `codex-pane.sh` entry; keep `copilot.sh` and
  `pr-comments.sh`.
- **Intro paragraph + `description` frontmatter** — replace "Codex (via the `codex`
  CLI in a tmux pane)" / "Codex in a tmux pane" with "Codex via `codex exec review`
  (headless; optional tmux live-watch)."

## Dogfooding workflow

Per the author's standing instruction, **the existing (tmux-pane) `review-loop`
reviews this change** — spec, plan, and code — right up until the PR is shipped.
This is the marketplace-installed plugin (`~/.claude/plugins/cache/caasi-dong3/
review-loop/`, currently `0.1.1`), whose source of truth is this repo's
`plugins/review-loop/` — there is **no** hand-placed `~/.claude/skills/` copy (the
migration-era copy spec 002 mentioned was retired when 002 merged). The headless
version takes over once this PR merges and the plugin updates. The old loop
reviewing its own replacement is a genuine self-review of the mechanism being
retired.

1. **Docs (this spec, the plan)** — local Claude subagent + Codex gate until clean,
   then committed to `main` (`docs:`), no PR phase.
2. **Code** — built on a feature branch (RAM-disk worktree), run through the full
   loop: local Claude + Codex gate → open PR → Copilot phase → clean pass. Merge
   only on the author's explicit instruction (merge commit, history preserved).

## Success criteria

- `scripts/codex-pane.sh` no longer exists.
- `SKILL.md` Phase A2 documents the **targeted** `codex exec review`
  (`--uncommitted` / `--base` / `--commit`, **no** prompt — target flags conflict
  with `[PROMPT]`) as the primary path, the **freeform** `review -` form for custom
  focus, plain `codex exec "<diff>"` only as a non-git/older-codex fallback, and
  `resume "$thread_id" -` for convergence rounds — all with `--sandbox read-only`
  before the subcommand, no `-m`/effort override (defers to `review_model`).
- `SKILL.md` Requirements + reviewer-roster item 2 list Codex as needing only
  `codex` on `PATH`; tmux is documented as optional live-watch, not a gate.
- No `codex-pane.sh` / "tmux pane" reference remains in `SKILL.md` (incl. intro,
  roster, requirements, PATH note, helper-scripts), `commands/review-loop.md`,
  `README.md`, or the `description` frontmatter.
- The three failure outcomes in §4 are distinct: clean (exit 0), usage-limited
  (non-zero + limit stderr → fallback), Codex-failed (non-zero, no limit → surfaced).
- **Non-tmux verification:** a smoke run with `$TMUX` unset performs a real Codex
  review (the regression the old design had). The plan includes this check; it is
  run manually before merge since the *old* loop drives the PR.
- The session-id capture path is documented as the `--json` **`thread_id`** field
  (verified on codex-cli 0.135.0), since id-based resume (§5) is the normal design.
- The untrusted/first-run-directory behavior is documented: a read-only review
  **proceeds** (rc=0, verified) — no trust hard-fail — so §4 needs no dedicated trust
  branch; any future trust-gate non-zero exit lands in the "Codex-failed" path.
- `README.md` and project `CLAUDE.md` reflect the headless mechanism.
- `marketplace.json` bumps the `review-loop` plugin version; the file is valid JSON.
- The change was driven through the (old) `review-loop` local gate — and Copilot,
  as a GitHub PR — to a clean pass before merge.

## Non-goals

- No change to the tier model, the Copilot phase (B), the assisted /
  never-auto-merge stance, or the all-artifacts target scope from 002.
- No general-purpose "external reviewer" abstraction — Codex-specific. Generalize
  only if a second external reviewer ever appears.
- `--output-schema` structured output is documented as a future option, not shipped.
- No edit to the global `~/.claude/CLAUDE.md` review-loop note in this PR
  (post-merge follow-up; the installed plugin updates via the marketplace, so there
  is no separate local copy to re-sync).
- No change to `copilot.sh` or `pr-comments.sh`.
