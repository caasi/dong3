# review-loop

An assisted (not autonomous) multi-reviewer convergence loop for changes — code or
design artifacts (specs, plans, docs). It runs local reviewers first and only then
reaches for GitHub Copilot, and it never merges on its own.

## What this is

A Claude Code skill that loops reviewers over a diff until they stop finding
problems, classifying every comment into tiers and pausing for your judgment on the
architectural ones. The local reviewers answer **blind and in parallel** on the same
unfixed diff — none sees another's findings — and the verdict names which ones actually
ran. A second look finds what the first missed even by the same weights; whether a
*different* model family adds more is a bonus, never a gate. The local gate runs first
so that by the time a forge reviewer (Copilot) sees the PR, there is much less to flag.

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

## Requirements

- **Always usable:** the Claude subagent reviewer needs nothing extra; `/review-loop:init` can pin it to a different Claude model.
- **Codex (optional):** the `codex` CLI on `PATH` (tmux optional — opens a
  live-watch pane only when you ask). `jq` is used to read the resume `thread_id` from `codex`'s
  `--json` stream; without it, Codex resume falls back to `--last`.
- **Forge reviewer (optional):** the built-in adapter is GitHub Copilot — an authenticated `gh`
  CLI and `jq`, GitHub PRs only, and **no enrollment needed**. Another forge's reviewer is
  reachable by declaring it and its three commands.

## Tiers

- **T1 mechanical** — typos, lint, null checks, doc fixes — auto-fixed.
- **T2 local refactor** — extraction, naming, validation — resolved with you first.
- **T3 architectural** — module moves, API shape, "should this exist" — your call.

For document targets, findings are about clarity, consistency, structure, and
factual accuracy; the TDD / one-commit-per-item discipline applies only where there
is executable behavior.

## How to use

```text
review this branch with review-loop
```

Or the slash command:

```text
/review-loop              # current branch vs base
/review-loop 1234         # open PR #1234 (adds Copilot)
```

## Non-goals

- Not autonomous — you decide T2/T3 fixes and the final merge.
- Not a squash-merge tool — defaults to a merge commit to preserve history.
- The Copilot path is GitHub-only; on other forges the local reviewer gate (the
  enrolled roster — a Claude subagent, others you enrol, Codex when present) still applies.

## Observation log

`review-loop` ships an always-on `UserPromptSubmit` hook. Once the plugin is enabled, the hook
runs on every message you send, in every project — not only ones under review. By itself it does
nothing: it writes a line only once `observation-log: yes` is recorded in
`~/.claude/review-loop.local.md` (or a project override at
`<project-root>/.claude/review-loop.local.md`). Until then, and while the answer is `no`, the hook
still runs on every message, and still writes nothing.

`/review-loop:init` asks before it writes `yes`. It explains what the hook matches, what one line
contains, where the file goes, and how to turn it off, before you decide.

**What the hook matches.** The marker `#redo`, `#again`, or `#fix`, as a separate word in a message
you send — at the start or end of the message, or with whitespace around it. A marker glued to
other characters, like `#fix.` or `#fixed`, does not match. `#redo` means the whole output was unusable; `#again` means this was already corrected
once; `#fix` means one specific error. A marker inside a code block or an inline code span does
not count.

**What it writes.** One line per objection, to `~/.claude/review-loop.log` — a project slug, your
session id, and the matched tier. It never writes your message text. The file is global, one file
for every project on this host, so `grep` across it answers "when did I object, and how often" —
nothing more.

**Off, and how to turn it off.** Answer `no` at `/review-loop:init`, or set
`observation-log: no` in `review-loop.local.md` directly. Either way the hook keeps running on
every message — it must run to check the answer — but writes nothing. To silence it without editing
the config, export `REVIEW_LOOP_LOG=0` in your shell, or set it under `env` in `settings.json` to
cover every session.

**It travels with your dotfiles.** `review-loop.local.md` lives under `~/.claude/`. If that
directory is under a dotfiles repository you sync to a second host, a recorded `yes` arrives there
too. `init` treats that the same as an answer given locally: it does not ask again, and the hook
starts writing on that host as soon as the file lands.

`init` records the answer as `observation-log: yes` or `observation-log: no` in the file's
frontmatter. It does not bump `review-loop-config` — the key's absence is itself a meaningful
state, so no migration is needed — and it never asks twice once the key is present, whether that
answer is `yes` or `no`.

The hook needs `jq` to read its JSON payload. If `jq` is missing, `init` reports it at enrolment:
without `jq` the hook writes nothing, on every host, regardless of the answer you gave.

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
