# review-loop Observation Log — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a global, append-only, line-oriented log that records which reviewers ran each review-loop round with per-reviewer finding counts, and when the author objected (`#redo`/`#again`/`#fix`), behind an opt-in prompt hook disclosed before install.

**Architecture:** Two writers append to one file at `~/.claude/review-loop.log`. Both source one shared library `logline.sh` (timestamp, project slug, value rules, work-tree guard, atomic append). `log.sh` is called by the loop for `review` lines; `object.sh` is a `UserPromptSubmit` hook for `object` lines, shipped in `hooks/hooks.json` and inert until `observation-log: yes` resolves from the roster config. Two harness questions are answered in writing before any code.

**Tech Stack:** POSIX-ish bash + `git` + `jq` (optional; hook degrades to silent no-op without it). Tests are bash under `tools/review-loop/`. No new runtime dependency.

## Global Constraints

Copied verbatim from spec 016; every task inherits these.

- **Append-only.** A line is written once and never changed. Nothing may read a line back to update it. Columns are never padded to align.
- **Field format.** `<UTC ISO-8601 with trailing Z>  <event>  <key>=<value> ...`, fields separated by **exactly two spaces**. A value contains no whitespace, no `=`, no path separator — a writer drops those characters rather than write a malformed line. Key order as the spec's examples show; `end` last when present.
- **Line bound.** One `write()` per line under `O_APPEND`, bounded at **1024 bytes**; a line that would exceed it is not written.
- **Log path.** `~/.claude/review-loop.log`, mode **0600**, a fixed constant. Never `${CLAUDE_PLUGIN_ROOT}`. Never inside a repository under review.
- **Both writers exit 0 always** and write nothing to stdout, except `log.sh new-run` which prints the token. A non-zero hook exit erases the author's prompt; that is why.
- **Off switch.** `REVIEW_LOOP_LOG=0` stops both writers.
- **Project slug.** Derived identically by both writers from a directory (hook: payload `cwd`; `log.sh`: own cwd) by the three-step rule in spec 016 §Format. `project` is on every line.
- **Version.** `review-loop` `0.6.0 → 0.7.0`, in the `plugins` array of `.claude-plugin/marketplace.json`, not the `metadata` header. `plugin.json` carries no `version`.
- **Description identity (spec 014).** The short manifest description must stay byte-identical between `plugin.json` and the `marketplace.json` entry; change both together.
- **Test convention.** Bash harness under `tools/review-loop/`, following the `need`/`refute`/`need_in` pattern already in `tools/review-loop/test-skill-content.sh` and `tools/tsugu/test-skill-content.sh`. `set -euo pipefail`.

---

## File structure

| Path | Responsibility |
|---|---|
| `docs/superpowers/plans/016-harness-findings.md` | Written record of the two pre-code answers (Task 1). Not shipped. |
| `plugins/review-loop/skills/review-loop/scripts/logline.sh` | Shared: slug derivation, value rules, work-tree guard, atomic bounded append, off switch. Sourced by both writers. |
| `plugins/review-loop/skills/review-loop/scripts/log.sh` | `new-run` and `review` subcommands. The loop's writer. |
| `plugins/review-loop/hooks/object.sh` | `UserPromptSubmit` hook. Config gate, `agent_type` gate, fence/span marker match, `object` line. |
| `plugins/review-loop/hooks/hooks.json` | Declares the hook command + 5s timeout. |
| `plugins/review-loop/commands/init.md` | Gains the disclosure + `observation-log` ask. |
| `plugins/review-loop/skills/review-loop/SKILL.md` | §A3 gains the round-logging instruction. |
| `plugins/review-loop/skills/review-loop/README.md` | Gains the always-on-hook disclosure. |
| `plugins/review-loop/.claude-plugin/plugin.json` | Description gains the disclosure; version stays absent. |
| `.claude-plugin/marketplace.json` | Entry description gains the same disclosure; version `0.7.0`. |
| `tools/review-loop/lib.bash` | New: sources `logline.sh` into a shell, plus fixture builders (git repos of each shape). |
| `tools/review-loop/test-logline.sh` | Slug, value rules, guard, append, off switch. |
| `tools/review-loop/test-log-sh.sh` | `new-run`, `review`, stop line, `end`. |
| `tools/review-loop/test-object-sh.sh` | Config gate, `agent_type`, fence/span, tiers, stdout/exit. |
| `tools/review-loop/test-format-rules.sh` | The four Format-paragraph rules and the end-to-end encoding/bound rules, asserted against writer output (see Task 9). |
| `tools/review-loop/test-skill-content.sh` | Migrated to `need_in` over five files. |

Tasks are ordered so each builds only on earlier ones. Task 1 is a gate: **no code before it is answered.**

---

## Task 1: Answer the two harness questions in writing

**Files:**
- Create: `docs/superpowers/plans/016-harness-findings.md`

No test cycle — this is a blocking investigation, per acceptance criteria items 3 and 18. Its deliverable is a written answer, not code.

- [ ] **Step 1: Determine whether `UserPromptSubmit` fires inside a subagent, and whether `agent_type` is in its payload.**

Install a throwaway `UserPromptSubmit` hook that appends its raw stdin to a temp file, dispatch a `Task` subagent that sends a prompt, and inspect what was captured. Or, if the installed Claude Code documents it, cite the doc version. Record the exact finding.

- [ ] **Step 2: Determine whether `plugin.json` needs a `hooks` key for `hooks/hooks.json` to be merged.**

Check the installed harness: does enabling a plugin whose manifest omits `hooks` still merge `hooks/hooks.json`? `plugin.json` lists `skills` and `commands` explicitly though both are defaults, so discovery cannot be assumed. Record whether a `hooks` key is required, and if so its exact form.

- [ ] **Step 3: Write both answers into `016-harness-findings.md`** with the harness version they were checked against, and state the fallback each implies:
  - If `agent_type` is absent for subagents → hook rule 1 is inert but harmless; keep it, note it does nothing.
  - If `UserPromptSubmit` does not fire for subagents at all → rule 1 is unnecessary; keep the guard as defence in depth, note why.
  - If `plugin.json` needs a `hooks` key → Task 7 adds it.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/016-harness-findings.md
git commit -m "docs(review-loop): 016 — answer the two pre-code harness questions"
```

---

## Task 2: Slug derivation in `logline.sh`

**Files:**
- Create: `plugins/review-loop/skills/review-loop/scripts/logline.sh`
- Create: `tools/review-loop/lib.bash`
- Test: `tools/review-loop/test-logline.sh`

**Interfaces:**
- Produces: `ll_project_slug <dir>` → prints the slug for `<dir>` (`project=` value, without the `project=` prefix). Never fails; prints `none` outside any repository.

- [ ] **Step 1: Write the fixture builders in `tools/review-loop/lib.bash`**

```bash
# tools/review-loop/lib.bash — sourced by every test-*.sh in this dir.
set -euo pipefail
LIBDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGLINE="$LIBDIR/../../plugins/review-loop/skills/review-loop/scripts/logline.sh"

# Build a throwaway clone with a given origin URL; echo its path.
# Local identity so --allow-empty commits work in a clean environment (no global git config).
git_id=(-c user.name=t -c user.email=t@t)
mk_repo_with_origin() { # $1=origin-url
  local d; d="$(mktemp -d)"; git -C "$d" init -q
  git -C "$d" remote add origin "$1"
  git "${git_id[@]}" -C "$d" commit -q --allow-empty -m x
  echo "$d"
}
# Plain clone, no remote.
mk_plain_repo() {
  local d; d="$(mktemp -d)"; git -C "$d" init -q
  git "${git_id[@]}" -C "$d" commit -q --allow-empty -m x
  echo "$d"
}
# A linked worktree of $1; echo the worktree path.
mk_worktree() { # $1=repo
  local w="$1-wt"; git -C "$1" worktree add -q "$w" -b wt-branch >/dev/null 2>&1
  echo "$w"
}
```

- [ ] **Step 2: Write the failing test `tools/review-loop/test-logline.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
. "$LOGLINE"
fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
eq() { [ "$1" = "$2" ] || fail "$3: expected [$2] got [$1]"; pass "$3"; }

# Remote forms
d=$(mk_repo_with_origin "https://github.com/caasi/dong3.git")
eq "$(ll_project_slug "$d")" "github.com-caasi-dong3" "https .git"
d=$(mk_repo_with_origin "git@gitlab.com:group/subgroup/repo.git")
eq "$(ll_project_slug "$d")" "gitlab.com-group-subgroup-repo" "scp nested"
d=$(mk_repo_with_origin "https://oauth2:ghp_SECRET@github.com/a/b.git")
case "$(ll_project_slug "$d")" in *SECRET*) fail "credential leaked";; esac
eq "$(ll_project_slug "$d")" "github.com-a-b" "userinfo stripped"
# No remote → step 2, non-empty
d=$(mk_plain_repo); base=$(basename "$d")
eq "$(ll_project_slug "$d")" "$base" "plain clone non-empty"
w=$(mk_worktree "$d")
eq "$(ll_project_slug "$w")" "$base" "worktree yields main checkout"
# No repo → none
eq "$(ll_project_slug /tmp)" "none" "no repo"
# upstream remote but no origin → falls through to step 2, same as no remote
d=$(mk_plain_repo); git -C "$d" remote add upstream https://example.com/x/y.git
eq "$(ll_project_slug "$d")" "$(basename "$d")" "upstream-only falls through to step 2"
# a submodule reached through step 2 yields its path name under .git/modules
sup=$(mk_plain_repo); sub=$(mk_plain_repo)
git -C "$sup" -c protocol.file.allow=always submodule add -q "$sub" mysub >/dev/null 2>&1
git -C "$sup/mysub" remote remove origin 2>/dev/null || true
eq "$(ll_project_slug "$sup/mysub")" "mysub" "submodule yields its superproject path name"
# same slug from a subdirectory of the repo
d=$(mk_repo_with_origin https://github.com/caasi/dong3.git); mkdir -p "$d/a/b"
eq "$(ll_project_slug "$d/a/b")" "github.com-caasi-dong3" "subdirectory yields repo slug"
echo ALL PASS
```

- [ ] **Step 3: Run it to verify it fails**

Run: `bash tools/review-loop/test-logline.sh`
Expected: FAIL — `ll_project_slug: command not found` (function undefined).

- [ ] **Step 4: Implement `ll_project_slug` in `logline.sh`**

```bash
#!/usr/bin/env bash
# logline.sh — shared writer library for the review-loop observation log.
# Sourced by log.sh and object.sh. Defines ll_* functions; runs nothing on its own.

# ll_scrub drops the characters a value may not contain. Defined here because the
# slug (below) routes its result through it; the value-rule tests live in Task 3.
ll_scrub() { local v="$1"; v="${v//[[:space:]]/}"; v="${v//=/}"; v="${v//\//}"; printf '%s' "$v"; }

# Derive the project slug for a directory. Never fails; prints `none` outside a repo.
ll_project_slug() { # $1=dir
  local dir="$1" url b cd
  if url=$(git -C "$dir" remote get-url origin 2>/dev/null); then
    url="${url#*://}"        # drop scheme
    url="${url#*@}"          # drop whole userinfo@ (token included)
    url="${url%.git}"        # drop trailing .git
    ll_scrub "${url//[\/:]/-}"   # a value-rule-forbidden char in a path is removed (spec line 105)
    return
  fi
  if cd=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    b=$(basename "$cd")
    if [ "$b" = ".git" ]; then ll_scrub "$(basename "$(dirname "$cd")")"; else ll_scrub "${b%.git}"; fi
    return
  fi
  printf 'none'
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `bash tools/review-loop/test-logline.sh`
Expected: `ALL PASS`.

- [ ] **Step 6: Commit**

```bash
git add plugins/review-loop/skills/review-loop/scripts/logline.sh tools/review-loop/lib.bash tools/review-loop/test-logline.sh
git commit -m "feat(review-loop): logline.sh project slug derivation"
```

---

## Task 3: Value rules and line assembly in `logline.sh`

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/scripts/logline.sh`
- Test: `tools/review-loop/test-logline.sh` (extend)

**Interfaces:**
- Consumes: `ll_project_slug`.
- Produces:
  - `ll_encode_id <model-id>` → percent-encoded id: `%`→`%25` first, then whitespace, `=`, `/`, `,`, `:`.
  - `ll_ts` → current UTC timestamp, ISO-8601, trailing `Z`.
  - `ll_line <event> <key=value>...` → a single log line joined by two spaces. Does not write.

- [ ] **Step 1: Extend the test with value rules**

```bash
eq "$(ll_scrub 'a b=c/d')" "abcd" "scrub drops space = /"
eq "$(ll_encode_id 'meta-llama/Llama-3.3-70B')" "meta-llama%2FLlama-3.3-70B" "encode path sep"
eq "$(ll_encode_id "$(printf 'a\tb')")" "a%09b" "encode tab (whitespace, not only space)"
eq "$(ll_encode_id 'a,b')" "a%2Cb" "encode comma"
[ "$(ll_encode_id 'a%2Cb')" != "$(ll_encode_id 'a,b')" ] && pass "encode % first keeps distinct" || fail "collision"
case "$(ll_ts)" in *[0-9]T*:*:*Z) pass "ts shape";; *) fail "ts shape";; esac
line="$(ll_line review project=foo run=abc123 round=1)"
[ "$line" = "$(printf '%s' "$line" | sed 's/  / /g' | sed 's/ /  /g')" ] || true  # informal
case "$line" in *"  review  project=foo  run=abc123  round=1") pass "two-space join";; *) fail "join: [$line]";; esac
```

- [ ] **Step 2: Run to verify the new asserts fail**

Run: `bash tools/review-loop/test-logline.sh`
Expected: FAIL — `ll_encode_id: command not found` (`ll_scrub` is defined in Task 2 with the slug).

- [ ] **Step 3: Implement**

`ll_scrub` is already defined in Task 2 (the slug uses it). Add the rest:

```bash
ll_encode_id() { # percent-encode; % first so the mapping is injective
  local v="$1"
  v="${v//%/%25}"
  v="${v// /%20}"; v="${v//$'\t'/%09}"; v="${v//$'\n'/%0A}"; v="${v//$'\r'/%0D}"   # whitespace
  v="${v//=/%3D}"; v="${v//\//%2F}"; v="${v//,/%2C}"; v="${v//:/%3A}"
  printf '%s' "$v"
}

ll_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

ll_line() { # $1=event, rest = key=value tokens already formed by caller
  local event="$1"; shift
  local out; out="$(ll_ts)  $event"
  local kv; for kv in "$@"; do out="$out  $kv"; done
  printf '%s' "$out"
}
```

- [ ] **Step 4: Run to verify passes**

Run: `bash tools/review-loop/test-logline.sh`
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugins/review-loop/skills/review-loop/scripts/logline.sh tools/review-loop/test-logline.sh
git commit -m "feat(review-loop): logline.sh value rules and two-space line assembly"
```

---

## Task 4: Guard, bound, off switch, and atomic append in `logline.sh`

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/scripts/logline.sh`
- Test: `tools/review-loop/test-logline.sh` (extend)

**Interfaces:**
- Produces: `ll_append <line>` → appends `<line>\n` to `$REVIEW_LOOP_LOG_FILE` (default `~/.claude/review-loop.log`), creating it 0600, under these gates: writes nothing and returns 0 if `REVIEW_LOOP_LOG=0`, or if the log file's own directory is inside a git work tree, or if the line would exceed 1024 bytes. One `write()` per line.

- [ ] **Step 1: Extend the test**

```bash
tmp="$(mktemp -d)"; export REVIEW_LOOP_LOG_FILE="$tmp/review-loop.log"
ll_append "one"; ll_append "two"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 2 ] && pass "two appends two lines" || fail "append count"
[ "$(stat -c %a "$REVIEW_LOOP_LOG_FILE")" = 600 ] && pass "mode 0600" || fail "mode"
REVIEW_LOOP_LOG=0 ll_append "three"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 2 ] && pass "off switch" || fail "off switch wrote"
ll_append "$(printf 'x%.0s' $(seq 1 2000))"
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = 2 ] && pass "over-1024 not written" || fail "bound"
# guard: log dir inside a work tree
wt="$(mk_plain_repo)"; REVIEW_LOOP_LOG_FILE="$wt/review-loop.log" ll_append "guarded"
[ ! -f "$wt/review-loop.log" ] && pass "guard refuses inside work tree" || fail "guard"
# concurrency: two writers, 1000 lines each, 2000 whole lines
REVIEW_LOOP_LOG_FILE="$tmp/c.log"
( for i in $(seq 1000); do ll_append "a$i"; done ) &
( for i in $(seq 1000); do ll_append "b$i"; done ) &
wait
[ "$(wc -l < "$tmp/c.log")" = 2000 ] && pass "2000 whole lines" || fail "interleave split"
```

- [ ] **Step 2: Run to verify fails**

Run: `bash tools/review-loop/test-logline.sh`
Expected: FAIL — `ll_append: command not found`.

- [ ] **Step 3: Implement**

```bash
ll_logfile() { printf '%s' "${REVIEW_LOOP_LOG_FILE:-$HOME/.claude/review-loop.log}"; }

# Note: the guard forks `git` once per call. In production each writer is invoked once
# per line (one review line per round, one object line per objection), so that is one
# fork per line written — fine. The 2000-line concurrency test below forks git 2000
# times and so runs for a few seconds; that is a test artifact, not the real write rate.
ll_append() { # $1=line. All failure paths return 0 and write nothing.
  [ "${REVIEW_LOOP_LOG:-1}" = 0 ] && return 0
  local line="$1" f dir
  f="$(ll_logfile)"; dir="$(dirname "$f")"
  # guard: refuse if the log's own directory is inside a work tree (printed value, not exit status)
  if [ "$(git -C "$dir" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]; then return 0; fi
  # bound: reject a line that would exceed 1024 bytes (line + newline)
  [ "$(printf '%s' "$line" | wc -c)" -ge 1024 ] && return 0
  mkdir -p "$dir" 2>/dev/null || return 0       # default ~/.claude may not exist; give up quietly
  # append-create, never truncate: two writers racing on a missing file must not
  # each run `: > "$f"` and wipe the other's already-appended line.
  [ -e "$f" ] || (umask 177; : >> "$f") 2>/dev/null || return 0
  printf '%s\n' "$line" >> "$f" 2>/dev/null || return 0   # one write(), O_APPEND
  return 0
}
```

- [ ] **Step 4: Run to verify passes**

Run: `bash tools/review-loop/test-logline.sh`
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugins/review-loop/skills/review-loop/scripts/logline.sh tools/review-loop/test-logline.sh
git commit -m "feat(review-loop): logline.sh guarded, bounded, atomic append with off switch"
```

---

## Task 5: `log.sh` — `new-run` and `review`

**Files:**
- Create: `plugins/review-loop/skills/review-loop/scripts/log.sh`
- Test: `tools/review-loop/test-log-sh.sh`

**Interfaces:**
- Consumes: `logline.sh` (`ll_*`).
- Produces the CLI in spec 016 §"Where it goes":
  - `log.sh new-run` → prints a 6-char `[a-z0-9]` token from `/dev/urandom`, nothing else.
  - `log.sh review run=<tok> round=<n> reviewer=<id>:<count> reviewer=<id>:<count> ... [end=<reason>]` → one `review` line. Each reviewer is a separate arg (a model id can contain a comma); `log.sh` encodes each id and assembles the one `reviewers=` value.
  - `log.sh review run=<tok> end=stopped` → the no-`round` stop line.
  - Supplies `ts` and `project` itself; never takes `session`.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
LOG="$LIBDIR/../../plugins/review-loop/skills/review-loop/scripts/log.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }; pass() { echo "PASS: $*"; }

tok="$(bash "$LOG" new-run)"
[ "${#tok}" = 6 ] && pass "6 chars" || fail "len [$tok]"
case "$tok" in *[!a-z0-9]*) fail "charset [$tok]";; *) pass "lowercase alnum";; esac
[ "$(bash "$LOG" new-run)" != "$(bash "$LOG" new-run)" ] && pass "differ" || fail "same token"

repo="$(mk_repo_with_origin https://github.com/caasi/dong3.git)"
tmp="$(mktemp -d)"; export REVIEW_LOOP_LOG_FILE="$tmp/l.log"
( cd "$repo" && REVIEW_LOOP_LOG_FILE="$tmp/l.log" bash "$LOG" review run=x7k2p9 round=1 reviewer=claude-opus-4-8:19 reviewer=gpt-5.5:5 )
line="$(cat "$tmp/l.log")"
case "$line" in
  *"  review  project=github.com-caasi-dong3  run=x7k2p9  round=1  reviewers=claude-opus-4-8:19,gpt-5.5:5") pass "review line" ;;
  *) fail "review line: [$line]" ;;
esac
# stop line: no round, no reviewers, end last
: > "$tmp/l.log"
( cd "$repo" && REVIEW_LOOP_LOG_FILE="$tmp/l.log" bash "$LOG" review run=x7k2p9 end=stopped )
case "$(cat "$tmp/l.log")" in
  *"  review  project=github.com-caasi-dong3  run=x7k2p9  end=stopped") pass "stop line" ;;
  *) fail "stop line: [$(cat "$tmp/l.log")]" ;;
esac
echo ALL PASS
```

- [ ] **Step 2: Run to verify fails**

Run: `bash tools/review-loop/test-log-sh.sh`
Expected: FAIL — `log.sh` does not exist.

- [ ] **Step 3: Implement `log.sh`**

```bash
#!/usr/bin/env bash
# log.sh — the loop's writer for the review-loop observation log.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/logline.sh"

case "${1:-}" in
  new-run)
    # Accumulate until at least 6 survivors: 96 filtered bytes usually suffice, but about
    # 0.7% of draws yield fewer than 6, so loop. No `head -c 6` on a live pipe — that would
    # SIGPIPE tr and fail the pipeline under `set -o pipefail`.
    s=""
    while [ "${#s}" -lt 6 ]; do s="$s$(head -c 96 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9')"; done
    printf '%s\n' "${s:0:6}"
    ;;
  review)
    shift
    # Each reviewer is its OWN arg — `reviewer=<id>:<count>`. A model id can contain a
    # comma, so a comma-joined list cannot be split back; separate args remove the
    # ambiguity. Parse the fixed key set so the output order is project run round
    # reviewers end regardless of input order, and skip a malformed reviewer arg
    # (empty id or empty count) rather than write a broken field.
    run="" round="" endkv="" revs=""
    for kv in "$@"; do
      case "$kv" in
        run=*)   run="$kv" ;;
        round=*) round="$kv" ;;
        end=*)   endkv="$kv" ;;
        reviewer=*)
          pair="${kv#reviewer=}"
          case "$pair" in
            *:*) id="${pair%:*}"; c="${pair##*:}"
                 [ -n "$id" ] && [ -n "$c" ] && revs="${revs:+$revs,}$(ll_encode_id "$id"):$c" ;;
          esac ;;
      esac
    done
    fields=("project=$(ll_project_slug "$PWD")")
    [ -n "$run" ]   && fields+=("$run")
    [ -n "$round" ] && fields+=("$round")
    [ -n "$revs" ]  && fields+=("reviewers=$revs")
    [ -n "$endkv" ] && fields+=("$endkv")
    ll_append "$(ll_line review "${fields[@]}")" || true
    ;;
  *) echo "usage: log.sh {new-run | review run=... [round=...] [reviewers=...] [end=...]}" >&2; exit 0 ;;
  # exit 0, not 2: acceptance §424 makes non-zero exit forbidden for either writer.
esac
```

Malformed `reviewer=` args are skipped: no colon, an empty id (`reviewer=:3`), or an empty
count (`reviewer=model:`) contributes nothing rather than a broken field. `log.sh` still
exits 0 and the line stays well-formed.

- [ ] **Step 4: Run to verify passes**

Run: `bash tools/review-loop/test-log-sh.sh`
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugins/review-loop/skills/review-loop/scripts/log.sh tools/review-loop/test-log-sh.sh
git commit -m "feat(review-loop): log.sh new-run and review writer"
```

---

## Task 6: `object.sh` — the hook

**Files:**
- Create: `plugins/review-loop/hooks/object.sh`
- Test: `tools/review-loop/test-object-sh.sh`

**Interfaces:**
- Consumes: `logline.sh` (sourced via a relative path from `hooks/` up to `skills/review-loop/scripts/`), a JSON payload on stdin.
- Behaviour, from spec 016 §"The hook": reads `{session_id, cwd, agent_type?, prompt}` from stdin; resolves `observation-log` from project then global `review-loop.local.md` frontmatter; writes one `object` line only when it resolves to `yes`, `agent_type` is absent, and the prompt carries a marker outside code. Always exits 0, never writes stdout.

- [ ] **Step 1: Write the failing test** (payloads via heredoc JSON)

```bash
#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
HOOK="$LIBDIR/../../plugins/review-loop/hooks/object.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }; pass() { echo "PASS: $*"; }

repo="$(mk_repo_with_origin https://github.com/caasi/dong3.git)"
cfg="$repo/.claude"; mkdir -p "$cfg"
tmp="$(mktemp -d)"; LOG="$tmp/o.log"

run() { # $1=prompt-json-value, $2=extra-json (e.g. agent_type)
  printf '{"session_id":"S1","cwd":"%s","prompt":%s%s}' "$repo" "$1" "${2:-}" \
    | REVIEW_LOOP_LOG_FILE="$LOG" HOME="$tmp" bash "$HOOK"
}
say_yes() { printf 'observation-log: yes\n---\n' > "$cfg/review-loop.local.md.frontmatter" 2>/dev/null || true
  printf -- '---\nobservation-log: yes\n---\n' > "$cfg/review-loop.local.md"; }

# absent config → nothing
: > "$LOG"; run '"#fix here"'; [ ! -s "$LOG" ] && pass "absent → silent" || fail "wrote without opt-in"
# yes → writes, tier fix
say_yes; : > "$LOG"; out="$(run '"please #fix here"')"
[ -z "$out" ] && pass "no stdout" || fail "stdout: [$out]"
grep -q '  object  project=github.com-caasi-dong3  session=S1  tier=fix$' "$LOG" && pass "fix line" || fail "no fix line"
# strongest wins
: > "$LOG"; run '"#fix and #redo"'; grep -q 'tier=redo$' "$LOG" && pass "redo wins" || fail "priority"
# fenced code on its own lines is ignored
: > "$LOG"; run '"before\n```\n#redo\n```\nafter"'; [ ! -s "$LOG" ] && pass "own-line fence ignored" || fail "fence counted"
# inline span is ignored
: > "$LOG"; run '"use `#redo` as the token"'; [ ! -s "$LOG" ] && pass "inline span ignored" || fail "span counted"
# a real marker outside a fence still counts even when a fenced example is present
: > "$LOG"; run '"```\n#fix\n```\nreally #redo now"'; grep -q 'tier=redo$' "$LOG" && pass "out-of-fence marker counts" || fail "out-of-fence missed"
# adjacency does NOT match: #fixed is not #fix
: > "$LOG"; run '"already #fixed it"'; [ ! -s "$LOG" ] && pass "adjacency no-match" || fail "#fixed matched"
# observation-log: no → nothing
printf -- '---\nobservation-log: no\n---\n' > "$cfg/review-loop.local.md"
: > "$LOG"; run '"#fix"'; [ ! -s "$LOG" ] && pass "no → silent" || fail "wrote against no"
# project no overrides a global yes — including from a subdirectory of the repo
mkdir -p "$repo/deep/sub"
printf -- '---\nobservation-log: yes\n---\n' > "$tmp/.claude/review-loop.local.md" 2>/dev/null || { mkdir -p "$tmp/.claude"; printf -- '---\nobservation-log: yes\n---\n' > "$tmp/.claude/review-loop.local.md"; }
printf -- '---\nobservation-log: no\n---\n' > "$cfg/review-loop.local.md"
: > "$LOG"; run '"#fix"'; [ ! -s "$LOG" ] && pass "project no overrides global yes" || fail "override failed"
# same, but the session cwd is a subdirectory — project config still found at the root
run_sub() { printf '{"session_id":"S1","cwd":"%s","prompt":%s}' "$repo/deep/sub" "$1" | REVIEW_LOOP_LOG_FILE="$LOG" HOME="$tmp" bash "$HOOK"; }
: > "$LOG"; run_sub '"#fix"'; [ ! -s "$LOG" ] && pass "subdir sees project no" || fail "subdir bypassed decline"
# a key only in the ## Notes body, not the frontmatter, is read as absent
rm -f "$tmp/.claude/review-loop.local.md"   # reset the global set by the override test above
printf -- '---\nreview-loop-config: 1\n---\n## Notes\nobservation-log: yes\n' > "$cfg/review-loop.local.md"
: > "$LOG"; run '"#fix"'; [ ! -s "$LOG" ] && pass "notes-body not read" || fail "read body key"
say_yes
# agent_type suppresses
: > "$LOG"; run '"#fix"' ',"agent_type":"general"'; [ ! -s "$LOG" ] && pass "agent_type silent" || fail "agent line"
# exit 0 even on garbage
echo 'not json' | REVIEW_LOOP_LOG_FILE="$LOG" bash "$HOOK"; [ $? = 0 ] && pass "exit 0 on garbage" || fail "nonzero"
echo ALL PASS
```

- [ ] **Step 2: Run to verify fails**

Run: `bash tools/review-loop/test-object-sh.sh`
Expected: FAIL — `object.sh` does not exist.

- [ ] **Step 3: Implement `object.sh`**

```bash
#!/usr/bin/env bash
# object.sh — UserPromptSubmit hook: appends one `object` line per author objection.
# Always exits 0. Never writes stdout. Inert unless observation-log: yes resolves.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../skills/review-loop/scripts/logline.sh"
trap 'exit 0' EXIT           # rule 2: any failure path still exits 0

command -v jq >/dev/null 2>&1 || exit 0   # no parser → silent (init reports it)

payload="$(cat)"
agent_type="$(printf '%s' "$payload" | jq -r '.agent_type // empty' 2>/dev/null)"
[ -n "$agent_type" ] && exit 0            # rule 1

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null)"
[ -n "$cwd" ] && [ -n "$sid" ] || exit 0

# resolve observation-log from project then global frontmatter (top scalar, stop at closing ---)
resolve() { # $1=file
  [ -f "$1" ] || return 1
  awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f&&/^observation-log:/{sub(/^observation-log:[[:space:]]*/,"");print;exit}' "$1"
}
# project config lives at the checkout root's .claude/, not necessarily $cwd — a session
# in a subdirectory must still see a project-level `no`. --show-toplevel gives the worktree
# root (where .claude/ lives); it is the right root here, unlike the slug, which uses
# --git-common-dir. Fall back to $cwd if not in a repo.
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")"
ans="$(resolve "$root/.claude/review-loop.local.md" || true)"
[ -n "$ans" ] || ans="$(resolve "$HOME/.claude/review-loop.local.md" || true)"
[ "$ans" = "yes" ] || exit 0

# Remove fenced blocks (lines between ``` fences) and inline spans (`...`),
# then match a whitespace-delimited marker word. Priority redo > again > fix.
stripped="$(printf '%s' "$prompt" | awk 'BEGIN{f=0} /^[[:space:]]*```/{f=!f;next} !f{print}' | sed 's/`[^`]*`//g')"
has() { # $1=word — true only if it appears whitespace-delimited
  printf '%s' " $stripped " | grep -Eq "[[:space:]]#$1[[:space:]]"
}
tier=""
if has redo; then tier=redo
elif has again; then tier=again
elif has fix; then tier=fix
fi
[ -n "$tier" ] || exit 0

proj="$(ll_project_slug "$cwd")"
ll_append "$(ll_line object "project=$proj" "session=$sid" "tier=$tier")"
exit 0
```

The `has` helper matches a marker only when it is a whitespace-delimited word, so `#fixed`
does not match `#fix`. Fenced blocks are dropped first (own-line ``` fences), then inline
spans, so a marker survives only outside code. The Step-1 fixtures — own-line fence, inline
span, out-of-fence marker, and the `#fixed` adjacency case — are the gate that this is right.

- [ ] **Step 4: Run to verify passes**

Run: `bash tools/review-loop/test-object-sh.sh`
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugins/review-loop/hooks/object.sh tools/review-loop/test-object-sh.sh
git commit -m "feat(review-loop): object.sh UserPromptSubmit hook"
```

---

## Task 7: `hooks/hooks.json` and the manifest question

**Files:**
- Create: `plugins/review-loop/hooks/hooks.json`
- Modify (only if Task 1 said so): `plugins/review-loop/.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: Task 1's answer on the `hooks` key.

- [ ] **Step 1: Write `hooks/hooks.json`** declaring the `UserPromptSubmit` command with a 5-second timeout. Use the harness's documented schema (confirm the field names against the installed version; the shape below is the common one):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/object.sh", "timeout": 5 } ] }
    ]
  }
}
```

- [ ] **Step 2: If Task 1 found `plugin.json` needs a `hooks` key**, add it pointing at `./hooks/` (or the exact form Task 1 recorded). If Task 1 found discovery is automatic, change nothing in `plugin.json` and note that in the commit.

- [ ] **Step 3: Manually verify the hook merges** — enable the plugin locally, send a message containing `#fix` in an opted-in repo, and confirm one `object` line appears. This is a runtime check, not an automated test.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/hooks/hooks.json plugins/review-loop/.claude-plugin/plugin.json
git commit -m "feat(review-loop): declare the UserPromptSubmit hook with a 5s timeout"
```

---

## Task 8: SKILL.md §A3 instruction, init disclosure, README, descriptions, version

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (§A3)
- Modify: `plugins/review-loop/commands/init.md`
- Modify: `plugins/review-loop/skills/review-loop/README.md`
- Modify: `plugins/review-loop/.claude-plugin/plugin.json` (description)
- Modify: `.claude-plugin/marketplace.json` (entry description + version `0.7.0`)

This is prose in system prompts — wording is behaviour. Its test is Task 10's content anchors, so this task ends at Task 10's green, not its own.

- [ ] **Step 1: SKILL.md §A3** — add the round-logging instruction: after aggregating the round's verdicts and deciding whether the round is dry, call `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/log.sh review run=<tok> round=<n> reviewer=<model>:<count> reviewer=<model>:<count> ...` (one `reviewer=` arg per reviewer, never a comma-joined list), minting `<tok>` with `log.sh new-run` once per run; put `end=converged` on the last round, and write `log.sh review run=<tok> end=stopped` if the author stops between rounds. State that the line is written **after** the dry decision (append-only; `end` cannot be known before).

- [ ] **Step 2: commands/init.md** — add the disclosure block: the plugin ships an always-on `UserPromptSubmit` hook; it runs on every message but writes nothing until `observation-log: yes` is recorded; ask before writing `yes`; state what it matches, that no message text is written, that it still executes while `no`/absent, how to remove it, and that a `yes` travels with `review-loop.local.md` through a dotfiles sync. Record the answer as `observation-log: yes|no` in the frontmatter; do not bump `review-loop-config`; do not re-ask once present. Report a missing `jq` at enrolment.

- [ ] **Step 3: README.md** — add the same disclosure at greater length.

- [ ] **Step 4: plugin.json + marketplace.json descriptions** — append the same one-clause hook disclosure to both, keeping them byte-identical (spec 014). Bump the `review-loop` entry in the `plugins` array of `marketplace.json` to `0.7.0`; leave `plugin.json` version absent.

- [ ] **Step 5: Verify the two descriptions are byte-identical**

Run: `diff <(jq -r .description plugins/review-loop/.claude-plugin/plugin.json) <(jq -r '.plugins[]|select(.name=="review-loop").description' .claude-plugin/marketplace.json)`
Expected: no output (identical).

- [ ] **Step 6: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md plugins/review-loop/commands/init.md plugins/review-loop/skills/review-loop/README.md plugins/review-loop/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "docs(review-loop): 016 — A3 logging instruction, init disclosure, README, version 0.7.0"
```

---

## Task 9: Format-rule and encoding tests against writer output

**Files:**
- Create: `tools/review-loop/test-format-rules.sh`

The Format paragraph's rules gap recurred four times in review. The answer is concrete assertions run against real writer output — not a keyword lint over the test files, which a reviewer showed proves nothing (it passes on a comment and survives deleting the assertion it claims to guard).

**Interfaces:**
- Consumes: `logline.sh`, `log.sh`, `object.sh` from earlier tasks; `sim3.log` shape.

- [ ] **Step 1: Write the four Format-rule assertions** against real writer output (two-space separation, no padding across a width change, key order, UTC-sortable timestamps), plus the encoding and 1024-bound rules. Build a multi-round log with `log.sh` (rounds 1 and 18) and check the separator width is exactly two on both.

```bash
#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
LOG="$LIBDIR/../../plugins/review-loop/skills/review-loop/scripts/log.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }; pass() { echo "PASS: $*"; }
repo="$(mk_repo_with_origin https://github.com/caasi/dong3.git)"; tmp="$(mktemp -d)"
export REVIEW_LOOP_LOG_FILE="$tmp/f.log"
( cd "$repo" && bash "$LOG" review run=x7k2p9 round=1 reviewer=a:1 )
( cd "$repo" && bash "$LOG" review run=x7k2p9 round=18 reviewer=a:1 )
grep -Eq ' {3,}' "$REVIEW_LOOP_LOG_FILE" && fail "padding: 3+ spaces present" || pass "exactly two spaces, no padding"
# UTC sortability: string sort == chronological (single host proxy: lines already in order)
LC_ALL=C sort -c "$REVIEW_LOOP_LOG_FILE" && pass "byte-sorts chronologically" || fail "not sortable"
# spec says plain string comparison = C/byte order; UTF-8 collation folds the separator spaces
# key order on a review line
head -1 "$REVIEW_LOOP_LOG_FILE" | grep -Eq '  review  project=[^ ]+  run=[^ ]+  round=' || fail "key order"
pass "key order"
```

- [ ] **Step 2: Assert the encoding and bound rules against real writer output**

```bash
# percent-encoding of a reviewer id reaches the log through log.sh, not just the unit
( cd "$repo" && bash "$LOG" review run=x7k2p9 round=2 reviewer=meta-llama/Llama-3.3-70B:3 )
grep -q 'reviewers=meta-llama%2FLlama-3.3-70B:3' "$REVIEW_LOOP_LOG_FILE" \
  && pass "reviewer id encoded on the writer path" || fail "id not encoded end to end"
# a line over 1024 bytes is not written
before=$(wc -l < "$REVIEW_LOOP_LOG_FILE")
( cd "$repo" && bash "$LOG" review run=x7k2p9 round=3 "reviewer=$(printf 'x%.0s' $(seq 1 1100)):1" )
[ "$(wc -l < "$REVIEW_LOOP_LOG_FILE")" = "$before" ] && pass "over-1024 line refused" || fail "bound not enforced"
echo ALL PASS
```

There is deliberately **no lint that greps the test files for rule keywords.** An earlier
draft had one; a reviewer showed it was theatre — it proves a keyword is present in a comment
or a `pass` string, not that a rule is asserted, and it survives deleting the assertion. The
real coverage is the concrete assertions in Step 1 and Step 2, run against writer output. The
symmetry gap this task answers is closed by those assertions, not by a keyword scan.

- [ ] **Step 3: Run to verify passes**

Run: `bash tools/review-loop/test-format-rules.sh`
Expected: `ALL PASS`.

- [ ] **Step 4: Commit**

```bash
git add tools/review-loop/test-format-rules.sh
git commit -m "test(review-loop): Format-paragraph rules and a lint that each has a test"
```

---

## Task 10: Migrate `test-skill-content.sh` to five files

**Files:**
- Modify: `tools/review-loop/test-skill-content.sh`

**Interfaces:**
- Consumes: Task 8's prose edits.

- [ ] **Step 1: Add a `need_in` helper and a `$ROOT`** matching the tsugu harness pattern, so the script can anchor text in files other than `SKILL.md`.

```bash
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
need_in() { grep -Eq -- "$2" "$ROOT/$1" || fail "$1 missing: $3"; pass "$3"; }
```

- [ ] **Step 2: Add anchors across the five files:**

```bash
need_in 'plugins/review-loop/skills/review-loop/SKILL.md' 'log\.sh review'          "A3 logs review lines"
need_in 'plugins/review-loop/commands/init.md' 'observation-log'                     "init records the answer"
need_in 'plugins/review-loop/commands/init.md' 'always-on|every message'            "init discloses the hook"
need_in 'plugins/review-loop/skills/review-loop/README.md' 'always-on|inert'        "README discloses the hook"
need_in '.claude-plugin/marketplace.json' 'always-on|inert'                         "marketplace description discloses"
need_in 'plugins/review-loop/.claude-plugin/plugin.json' 'always-on|inert'          "plugin.json description discloses"
```

- [ ] **Step 3: Add the identity + version jq assertions** (borrowing the tsugu `jq` style):

```bash
pd="$(jq -r .description "$ROOT/plugins/review-loop/.claude-plugin/plugin.json")"
md="$(jq -r '.plugins[]|select(.name=="review-loop").description' "$ROOT/.claude-plugin/marketplace.json")"
[ "$pd" = "$md" ] || fail "plugin.json and marketplace descriptions differ"
pass "descriptions identical"
v="$(jq -r '.plugins[]|select(.name=="review-loop").version' "$ROOT/.claude-plugin/marketplace.json")"
[ "$v" = "0.7.0" ] || fail "review-loop version is $v, not 0.7.0"
pass "version 0.7.0"
```

- [ ] **Step 4: Run the harness**

Run: `bash tools/review-loop/test-skill-content.sh`
Expected: all `PASS`, no `FAIL`. If a `need_in` fails, the corresponding Task 8 prose is missing — fix Task 8, not the test.

- [ ] **Step 5: Commit**

```bash
git add tools/review-loop/test-skill-content.sh
git commit -m "test(review-loop): content anchors across SKILL, init, README, marketplace, plugin"
```

---

## Task 11: Green-suite gate and acceptance sweep

**Files:**
- Create: `tools/review-loop/run-all.sh`

- [ ] **Step 1: Write a runner** that executes every `test-*.sh` in `tools/review-loop/` and fails if any does:

```bash
#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in "$D"/test-*.sh; do echo "== $t =="; bash "$t" || rc=1; done
[ $rc = 0 ] && echo "ALL SUITES PASS" || { echo "SUITE FAILURES"; exit 1; }
```

- [ ] **Step 2: Run it**

Run: `bash tools/review-loop/run-all.sh`
Expected: `ALL SUITES PASS`.

- [ ] **Step 3: Walk the spec's Acceptance criteria** (016 lines 416–456) and tick each against a test or a manual check. The two "answered in writing before any code" items map to Task 1's document; the rest map to suites above. Record any unmet item as a new step rather than declaring done.

- [ ] **Step 4: Commit**

```bash
git add tools/review-loop/run-all.sh
git commit -m "test(review-loop): one runner for the observation-log suite"
```

---

## Self-review notes

- **Spec coverage:** slug (T2), value/encoding rules (T3), guard/bound/off/append (T4), `log.sh` review+stop+new-run (T5), hook with three rules + config gate (T6), `hooks.json` + manifest question (T7), A3+init+README+descriptions+version (T8), Format rules + end-to-end encoding/bound (T9), five-file content harness (T10), acceptance sweep (T11), harness questions before code (T1).
- **Intentionally not automated, named rather than dropped:** the omission check (spec Testing 402-403, 408-410) is an offline procedure over transcripts, verified in T11 as a documentation check (Acceptance §436), not a shipped writer. The hook-merge check (T7 Step 3) is a manual runtime check. Both are stated as manual so they are not silently missing.
- **Deferred by the spec, not built:** any posterior/score; a `run`↔`object` join; a snapshot for uncommitted targets; finding identity. Do not add them.
- **Type consistency:** `ll_project_slug`, `ll_scrub`, `ll_encode_id`, `ll_ts`, `ll_line`, `ll_append` are named identically wherever referenced. `REVIEW_LOOP_LOG_FILE` overrides the log path in tests; `REVIEW_LOOP_LOG=0` is the off switch — two different variables, kept distinct.
- **Open runtime dependency:** Task 1's answers gate Tasks 6 and 7. If `agent_type` behaves unexpectedly, the hook's rule 1 changes; if the manifest needs a `hooks` key, Task 7 adds it. Neither blocks the other tasks.
