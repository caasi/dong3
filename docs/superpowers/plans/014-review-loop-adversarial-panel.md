# review-loop Reviewer Roster + Adversarial Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `review-loop` a discovered, calibrated reviewer roster (`/review-loop:init`) and turn its serial reviewers into an adversarial panel — blind parallel round 1, one cross-critique round, per-finding confidence + falsification, and an auto-fix gate that reproduction outranks — per [spec 014](../specs/014-review-loop-adversarial-panel-design.md).

**Architecture:** `SKILL.md` is an LLM-read system prompt, so most "behavior" is wording. **No new script ships.** The only new programs are dev tooling: a `need_new()` harness helper that fails any regression anchor which already matches the pre-change `SKILL.md`, and a fixture suite pinning the detector exemption. Everything else is prose edits plus a new namespaced command (`/review-loop:init`), guarded by content anchors.

**Tech Stack:** Markdown (system prompt), Bash (`set -euo pipefail`), `git`, `jq`, `codex` CLI, `gh`. No build system — plugin/skill repo.

## Global Constraints

Copied verbatim from the spec; every task's requirements implicitly include these.

- **Never trust a model where a check can run.** Anchors guarding new behavior use `need_new`; a prose citation is `reproduced` only after the facilitator runs the check. (Spec, "The second principle".)
- **Materialize critical knowledge only.** A shipped script must encode something an agent would get wrong or skip — GraphQL bot-ids, pagination, building a sandbox. A `command -v` loop does not qualify: wrapping it calcifies a decision that a more capable model will make correctly without help. Prefer prose the agent executes. (Spec, "Its corollary".)
- **The skill encodes no environment.** Nothing assumed present, nothing assumed callable, nothing ships that we cannot exercise. (Spec, "The governing principle".)
- **No secrets, ever.** The config stores names, never a url, never an `api_key_env`, never a token.
- **Dev tooling stays out of `plugins/<name>/`** (repo `CLAUDE.md`). Tests and fixtures live in `tools/review-loop/`. No new file is added under `plugins/review-loop/skills/review-loop/scripts/`.
- **Bash scripts use `set -euo pipefail`.**
- Conventional commits, scoped: `feat(review-loop):`, `docs(review-loop):`, `test(review-loop):`, `chore(review-loop):`.
- Repo-facing text (commits, code comments, SKILL.md, README) is **English**.
- Target version: `review-loop` `0.4.0` → `0.5.0` in `.claude-plugin/marketplace.json`.
- **Never merges autonomously**; the author decides T2/T3 and the merge. Unchanged.

## Scope & Conventions

- **Implementation must go on a feature branch in a worktree, never `main`.** Branch: `feat/review-loop-adversarial-panel`, worktree already at `/dev/shm/dong3/review-loop-panel`. Run **every** git command from inside it (`git -C /dev/shm/dong3/review-loop-panel`) — a wrong cwd lands commits on the main checkout's branch.
- The spec is the source of truth. Where this plan and the spec disagree, the spec wins; report the discrepancy rather than guessing.
- All `SKILL.md` edits use the **Edit tool** with the verbatim "Find" anchors below as `old_string`. Anchors were captured from `SKILL.md` at `0.4.0`. **If an Edit fails to match, re-read the live file and report — do not guess a replacement.**
- Line numbers in "Files" are advisory; the Find anchors are authoritative.

## File Structure

**Create:**
- `plugins/review-loop/commands/init.md` — the `/review-loop:init` command doc.
- `tools/review-loop/fixtures/*.jsonl` + `tools/review-loop/test-detector-predicate.sh` — dev tooling pinning the R2 detector exemption.

**Deliberately NOT created:** no `panel-detect.sh`. The presence probe is a `command -v` loop the agent runs inline (spec §A.2); a script for it would buy a maintenance burden and a JSON schema whose only consumer is the agent.

**Modify:**
- `tools/review-loop/test-skill-content.sh` — add `need_new()`; add spec-014 anchors.
- `plugins/review-loop/skills/review-loop/SKILL.md` — roster, calibration, Phase A restructure, finding record, gate, verdicts, forge slot.
- `plugins/review-loop/commands/review-loop.md` — invariant lines.
- `plugins/review-loop/skills/review-loop/README.md` — `init`, config path, Copilot-as-adapter.
- `.claude-plugin/marketplace.json` — version + description.

**Deliberately unchanged:** `scripts/copilot.sh`, `scripts/pr-comments.sh`, `scripts/sandbox-preflight.sh`, the detector's jq predicate, the embedded-diff form, the sticky-embedded rule, exit-code triage.

---

## Task 0: Baseline, and fixture coverage for the detector exemption

Task 4 adds an exemption to the `command_execution` detector for R2 critique rounds. On a host whose preflight reports `broken`, every Codex round routes to the embedded-diff form, so that native branch never executes here — a **testing** gap, not a running one.

**The coverage is a recorded event-stream fixture, not a change to anyone's machine.** The detector is a real `jq` predicate over `codex --json`'s output, so a fixture tests it deterministically with no sandbox involved.

**Nothing in this plan asks for `sudo`.** Restoring the native path means editing the host's AppArmor/sysctl policy — system-wide, affecting every `bwrap` caller. `/review-loop:init` may *suggest* it and point at `references/codex-sandbox-host-fixes.md`; the author may then do it, with an agent's help if they like, **as its own task in its own session**. Suggesting is not owning. It is not a prerequisite for this plan, and its absence is a configuration, not a defect (spec §A.3, §B.12).

**Files:**
- Create: `tools/review-loop/fixtures/codex-native-false-clean.jsonl`
- Create: `tools/review-loop/fixtures/codex-native-real-review.jsonl`
- Create: `tools/review-loop/fixtures/codex-r2-critique.jsonl`
- Create: `tools/review-loop/test-detector-predicate.sh`

**Interfaces:**
- Produces: `classify_round <kind> <file>` semantics pinned by test — `kind` ∈ {`review`, `critique`}; a `review` round with zero `command_execution` items is a **non-review**; a `critique` round with zero is a **review** (exempt).

- [ ] **Step 1: Record the baseline (informational; no human, no commit)**

Run:
```bash
cd /dev/shm/dong3/review-loop-panel
plugins/review-loop/skills/review-loop/scripts/sandbox-preflight.sh || true
codex --version
bash tools/review-loop/test-skill-content.sh
bash tools/review-loop/test-sandbox-preflight.sh
```
Expected: a verdict (`usable` / `broken` / `unknown`) — **record it, act on nothing** — then both suites exit 0. A pre-existing suite failure is reported, not fixed here.

If the verdict is `usable`, also exercise the real native path in Task 10 Step 3. If it is not, the fixtures below are the coverage and Task 11's PR body discloses the residue.

- [ ] **Step 2: Write the failing test**

Create `tools/review-loop/test-detector-predicate.sh`:

```bash
#!/usr/bin/env bash
# Pins the post-round detector's decision, using recorded `codex --json` streams.
# No sandbox, no network, no codex binary required.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX="$SCRIPT_DIR/fixtures"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# The predicate, verbatim from SKILL.md's detector.
ran_a_command() {
  jq -e 'select(.type=="item.completed") | select(.item.type=="command_execution")' "$1" >/dev/null 2>&1
}

# The routing decision the skill must make.
#   review  round + zero commands -> non-review (sandbox false clean)
#   critique round + zero commands -> review (exempt: its subject is the findings)
classify_round() { # $1=kind ($2=file)
  if ran_a_command "$2"; then echo "review"; return; fi
  case "$1" in
    critique) echo "review" ;;
    *)        echo "non-review" ;;
  esac
}

for f in codex-native-false-clean codex-native-real-review codex-r2-critique; do
  [ -f "$FIX/$f.jsonl" ] || fail "missing fixture: $f.jsonl"
  jq -e . "$FIX/$f.jsonl" >/dev/null || fail "fixture is not valid JSONL: $f"
done
pass "fixtures present and parse as JSONL"

[ "$(classify_round review "$FIX/codex-native-false-clean.jsonl")" = "non-review" ] \
  || fail "a sandbox-blocked native review must be a non-review, never a silent clean"
pass "native review + zero commands -> non-review"

[ "$(classify_round review "$FIX/codex-native-real-review.jsonl")" = "review" ] \
  || fail "a native review that ran commands must be a review"
pass "native review + commands -> review"

# The exemption. This is the branch that cannot execute on a `broken` host.
ran_a_command "$FIX/codex-r2-critique.jsonl" \
  && fail "the critique fixture must have ZERO command_execution items to test the exemption"
[ "$(classify_round critique "$FIX/codex-r2-critique.jsonl")" = "review" ] \
  || fail "an R2 critique round with zero commands must be EXEMPT, not a non-review"
pass "R2 critique + zero commands -> review (exempt)"

# The false-clean fixture must also carry a corroborating text marker.
grep -q 'sandbox prevented reading' "$FIX/codex-native-false-clean.jsonl" \
  || fail "false-clean fixture lacks its corroborating text marker"
pass "false-clean fixture carries a text marker"

# thread_id is parseable from every fixture (resume depends on it).
for f in "$FIX"/*.jsonl; do
  jq -re 'select(.type=="thread.started") | .thread_id' "$f" >/dev/null \
    || fail "no thread_id in $(basename "$f")"
done
pass "thread_id parseable from every fixture"

echo "All detector-predicate checks passed."
```

`chmod +x tools/review-loop/test-detector-predicate.sh`

- [ ] **Step 3: Run it to verify it fails**

Run: `bash tools/review-loop/test-detector-predicate.sh`
Expected: `FAIL: missing fixture: codex-native-false-clean.jsonl`

- [ ] **Step 4: Create the fixtures**

Event shapes are taken from real `codex-cli 0.139.0 --json` output: items nest their kind under `.item.type`, not top-level `.type`.

`tools/review-loop/fixtures/codex-native-false-clean.jsonl` — the sandbox blocked the round, so it never read the tree:
```
{"type":"thread.started","thread_id":"00000000-0000-0000-0000-00000000face"}
{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"The sandbox prevented reading the working tree, so I reviewed the connected GitHub repository instead. I found no issues, but my confidence is low."}}
{"type":"turn.completed"}
```

`tools/review-loop/fixtures/codex-native-real-review.jsonl` — it read the tree and found something:
```
{"type":"thread.started","thread_id":"00000000-0000-0000-0000-00000000beef"}
{"type":"item.completed","item":{"id":"item_0","type":"command_execution","command":"git diff main...HEAD","status":"completed"}}
{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"sed -n '1,80p' src/ttl.ts","status":"completed"}}
{"type":"item.completed","item":{"id":"item_2","type":"agent_message","text":"src/ttl.ts:41 - expiry comparison uses `<`, so an entry expiring exactly now survives one extra get(). confidence: high. not a bug if expiry is intended to be exclusive."}}
{"type":"turn.completed"}
```

`tools/review-loop/fixtures/codex-r2-critique.jsonl` — a cross-critique round arguing from what is already in its session. Zero commands, and correct:
```
{"type":"thread.started","thread_id":"00000000-0000-0000-0000-00000000cafe"}
{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"Attacking the other panelist's finding #2: it claims `opts` may be null, but their own quoted hunk shows `opts: Options = {}` on the line above. REFUTED. My own finding #1 I keep, at high confidence."}}
{"type":"turn.completed"}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tools/review-loop/test-detector-predicate.sh`
Expected: six `PASS:` lines, then `All detector-predicate checks passed.`, exit 0.

Sanity-check that the exemption is the thing being tested — remove it and watch the suite go red:
```bash
sed -i.bak 's/    critique) echo "review" ;;/    critique) echo "non-review" ;;/' tools/review-loop/test-detector-predicate.sh
bash tools/review-loop/test-detector-predicate.sh; echo "exit=$?"
mv tools/review-loop/test-detector-predicate.sh.bak tools/review-loop/test-detector-predicate.sh
```
Expected: `FAIL: an R2 critique round with zero commands must be EXEMPT` and a non-zero exit, then the file is restored. If it still passes, the test is not testing the exemption — fix it before continuing.

- [ ] **Step 6: Commit**

```bash
git add tools/review-loop/fixtures tools/review-loop/test-detector-predicate.sh
git commit -m "test(review-loop): cover the R2 detector exemption with recorded fixtures

The exemption Task 4 adds cannot execute on a host whose codex sandbox preflight
reports broken -- every round routes to the embedded-diff form. That is a testing
gap, not a running one, and it does not warrant touching anyone's machine: restoring
the native path is an AppArmor/sysctl policy change, system-wide and privileged, and
a review skill has no business asking for sudo.

The detector is a real jq predicate over codex --json's event stream, so a recorded
stream pins it deterministically with no sandbox involved. Three fixtures: a
sandbox-blocked native review (zero commands -> non-review, never a silent clean), a
native review that read the tree, and an R2 critique arguing from session context
(zero commands -> exempt). Step 5 flips the exemption and requires the suite to go
red, so the test is known to be capable of failing.

Empirically the exemption is a safety net rather than the common case: this spec's
own R2 ran five command_execution items, because refuting by reproduction means
opening the file at the cited line.

Implements spec 014 §B.12."
```

---

## Task 1: `need_new()` — make the harness prove an anchor can fail

This lands **before** any `SKILL.md` edit. Three anchors proposed during spec 014's own review rounds were vacuous (`need 'confidence'`, `need 'invocation'`, `refute '^## Phase B — GitHub Copilot'`), each asserted by a model that had not run `grep` against the file it was describing. A test that cannot fail is not a test.

**Files:**
- Modify: `tools/review-loop/test-skill-content.sh`

**Interfaces:**
- Produces: `need_new <regex> <description>` — passes only if the regex matches the working `SKILL.md` **and does not match** `SKILL.md` at `$BASE_REF`. Used by Tasks 3–10.

- [ ] **Step 1: Add the repo/base plumbing and the helper**

Find (verbatim):

```
refute() { # $1=regex, $2=description — fails if the regex IS present
  ! grep -Eq "$1" "$SKILL" || fail "SKILL.md still contains (should be gone): $2"
  pass "no longer present: $2"
}
```

Replace with:

```
refute() { # $1=regex, $2=description — fails if the regex IS present
  ! grep -Eq "$1" "$SKILL" || fail "SKILL.md still contains (should be gone): $2"
  pass "no longer present: $2"
}

# Novelty-checked anchor. An anchor that already matches the PRE-CHANGE SKILL.md
# guards nothing: it passes before the work is done. Three such anchors were
# proposed during spec 014's review and none of their authors had run grep.
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_REL="plugins/review-loop/skills/review-loop/SKILL.md"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
BASE_REF="${BASE_REF:-$(git -C "$REPO" merge-base HEAD "$DEFAULT_BRANCH" 2>/dev/null || true)}"

need_new() { # $1=regex, $2=description — must match now, must NOT match at $BASE_REF
  grep -Eq "$1" "$SKILL" || fail "SKILL.md missing: $2"
  if [ -z "$BASE_REF" ]; then
    echo "WARN: no BASE_REF (not a git checkout?) — novelty unchecked for: $2" >&2
    pass "$2"
    return
  fi
  local base_content
  base_content="$(git -C "$REPO" show "$BASE_REF:$SKILL_REL" 2>/dev/null)" || \
    fail "cannot read baseline $BASE_REF:$SKILL_REL for: $2"
  if grep -Eq "$1" <<<"$base_content"; then
    fail "vacuous anchor (already present at $BASE_REF): $2"
  fi
  pass "$2"
}
```

- [ ] **Step 2: Prove `need_new` actually catches a vacuous anchor**

This is the step that makes the helper trustworthy. Run, **without committing**:

The probe copy must live **beside** the real harness: `test-skill-content.sh` derives
`SCRIPT_DIR` from `${BASH_SOURCE[0]}` and `REPO` from `$SCRIPT_DIR/../..`, so a copy run
from `/tmp` would resolve `REPO` to `/` and the novelty check would silently no-op —
the step meant to prove the guard can fail would itself fail open.

```bash
cd /dev/shm/dong3/review-loop-panel
probe=tools/review-loop/.tsc-probe.sh          # beside the real harness, so SCRIPT_DIR resolves
cp tools/review-loop/test-skill-content.sh "$probe"
printf "\nneed_new 'Codex' 'deliberately vacuous anchor'\n" >> "$probe"
bash "$probe"; echo "exit=$?"
rm -f "$probe"
```
Expected: the run ends with
`FAIL: vacuous anchor (already present at <sha>): deliberately vacuous anchor` and a **non-zero** exit.
(`Codex` appears throughout the unmodified `SKILL.md`, so a working `need_new` must reject it.)
If it instead PASSES, `need_new` is broken — fix it before continuing. Do not commit `.tsc-probe.sh`.

- [ ] **Step 3: Run the real suite to confirm nothing regressed**

Run: `bash tools/review-loop/test-skill-content.sh`
Expected: all existing checks pass, exit 0 (no `need_new` calls yet).

- [ ] **Step 4: Commit**

```bash
git add tools/review-loop/test-skill-content.sh
git commit -m "test(review-loop): add need_new(), an anchor that must be able to fail

Three anchors proposed during spec 014's review rounds were vacuous -- they
matched the unmodified SKILL.md, so they passed before any work was done. Each
was asserted by a model that had not run grep against the file it described.
need_new asserts the regex matches the working file and does NOT match the file
at the merge-base, so a guard that cannot fail is itself a test failure.

Implements spec 014 § Testing."
```

---

## Task 2: `SKILL.md` — reviewer roster, requirements, loop-start reconciliation

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (Requirements ~16–22; "Reviewer roster & priority" ~32–36)

- [ ] **Step 1: Reword Requirements so Codex is enrolled, not assumed**

Find (verbatim):

```
- **Always usable:** the Claude subagent reviewer needs nothing extra.
```

Replace with:

```
- **Always usable:** the Claude subagent reviewer needs nothing extra.
- **The roster is enrolled, not assumed.** Which reviewers this host can field is
  answered by a `command -v` sweep at loop start (presence) plus
  `~/.claude/review-loop.local.md` (enrollment + the invocation recipe
  `/review-loop:init` learned by actually calling each CLI). With no config
  the loop fields the same roster it always did and hints at `init` once; `init` is
  never a precondition.
```

- [ ] **Step 2: Replace the roster section**

Find (verbatim):

```
## Reviewer roster & priority

1. **Local Claude subagent** — always. Dispatch a subagent (Task tool) to do the review.
2. **Local Codex** (headless `codex exec review`) — when `codex` is on `PATH`. tmux is not required; it adds a live-watch pane **only when you ask to watch** (and you're in tmux). See A2.
3. **GitHub Copilot** — only for GitHub PR targets, after the PR is open.
```

Replace with:

````
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
````

- [ ] **Step 3: Verify**

Run:
```bash
S=plugins/review-loop/skills/review-loop/SKILL.md
for phrase in 'Roster reconciliation' 'derived from `kind`' 'Fresh-context only'; do
  printf '%-24s %s\n' "$phrase" "$(grep -c "$phrase" "$S")"
done
grep -c '^## Reviewer roster & priority' "$S"
awk '/^```/{n++} END{print "fences:", n, (n%2==0 ? "balanced" : "UNBALANCED")}' "$S"
```
Expected: each phrase counts `1` or more — check them **individually**, never as one `grep 'A\|B\|C'`, because an OR match hides a miss in any single branch. Note `Fresh-context only` is capitalised. Then `0` (old heading gone) and `balanced`.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): roster is enrolled and reconciled, not assumed

Ranks panelists by heterogeneity, derives tier from kind so a config file cannot
buy the heterogeneous verdict, and reconciles the probe against the config at loop
start. All three drift cases are surfaced; none is silently followed. A stored
invocation recipe never suppresses the preflight or the command_execution detector
-- a recipe that silently false-cleans is exactly what spec 009 exists to prevent.

Implements spec 014 §A.1, §A.6, and the roster half of §B.9."
```

---

## Task 3: `/review-loop:init` — the command, and README

**Files:**
- Create: `plugins/review-loop/commands/init.md`
- Modify: `plugins/review-loop/skills/review-loop/README.md`

- [ ] **Step 1: Create the command doc**

Create `plugins/review-loop/commands/init.md`:

```markdown
---
description: Discover which coding CLIs this host has, verify how to call each one by actually calling it, and record the enrolled reviewer roster — idempotent; re-run whenever the host changes
---

# /review-loop:init

Invoke the `review-loop` skill and run the **init** routine. Pass `$ARGUMENTS`
through as free-form context.

**Usage:** `/review-loop:init`

Load-bearing invariants the skill enforces:

- **Probes presence, verifies invocation, asks for the rest.** The probe is a
  `command -v` sweep plus `<cli> --version` — no script, no network, no credentials,
  no other plugin's config. Everything it cannot probe is asked, not guessed.
- **Verifies by trying.** Knowing `codex` exists tells you nothing about how to
  drive it. `init` calls each enrolled CLI once, on a **throwaway fixture diff —
  never your real working tree** — and stores the literal command line that worked
  in `invocation.command`. Bounded to two attempts per CLI. A CLI whose invocation
  cannot be established is **detected but not enrolled**, with the reason shown.
- **Never asks for `sudo`, and never fixes your host.** If Codex's native sandbox is
  blocked, `init` records `form: embedded` — a fully supported path — and may point
  once at `references/codex-sandbox-host-fixes.md`. Restoring the native path is an
  AppArmor/sysctl change affecting every `bwrap` caller on the machine: **separate
  work, in its own session, which you own.** review-loop never gates on it, never
  blocks for it, and never re-raises it.
- **Presence is not authentication.** `gh` on `PATH` only *offers* a GitHub Copilot
  enrollment; `gh auth status` decides it. An unauthenticated `gh` is detected and
  not enrolled, rather than enrolled-and-broken.
- **Endpoints are declared, never discovered.** `init` does not go looking through
  other plugins' registries. Name one and it records the name — url and
  `api_key_env` stay in `chat-subagent`'s files. **No secrets are ever written.**
- **Idempotent.** Re-running re-probes, prints a diff of what changed, and preserves
  explicit opt-outs (`enabled: false` is a decision, not an absence), declared
  endpoints, and forge reviewers.
- **Never a precondition.** With no config the loop works exactly as it does today
  and hints at `init` once.

Writes `~/.claude/review-loop.local.md` (global), overridden per project by
`<project-root>/.claude/review-loop.local.md`. Offers to add `.claude/*.local.md`
to `.gitignore` if absent.
```

- [ ] **Step 2: Update the README's roster**

The README's roster is its own list — **not** the one in `SKILL.md`; the two are worded
differently. Find (verbatim, `README.md` lines ~15–20):

```
## Reviewer roster (in priority order)

1. **Claude subagent** — always; needs nothing extra.
2. **Codex** (headless `codex exec review`) — when `codex` is on `PATH`; tmux
   opens a live-watch pane only when you ask (never by default).
3. **GitHub Copilot** — only for GitHub PR targets, after the local gate is clean.
```

Replace with:

```
## Reviewer roster (by heterogeneity)

Decorrelated error modes are the only reason a second reviewer catches what the first
missed, so panelists are ranked by how different they are — not by how good they are.

1. **Tier 1 — a different model family**, actually called: `codex`, another enrolled
   coding CLI, or a user-declared endpoint (always `trust: user-asserted`, and never
   counted as heterogeneous evidence).
2. **Tier 2 — a different Claude model**, pinned by `/review-loop:init`. Same family,
   so agreement here is *weak* evidence and the gate says so.
3. **Fresh-context only** — a Claude subagent on the session's own model. What a
   zero-config host gets. The weakest verdict there is.

Panelists answer **blind and in parallel** on the same unfixed diff, then attack each
other's findings. A **forge reviewer** (Phase B) is not a panelist: it appears only once
a PR/MR exists. GitHub Copilot is the one built-in adapter.
```

Then append to the README's end:

```markdown
## `/review-loop:init` (optional)

Discovers which coding CLIs this host has, works out **how to call each one by
actually calling it**, and records the result in `~/.claude/review-loop.local.md`
(project override: `<project-root>/.claude/review-loop.local.md`). Re-run it
whenever the host changes; it is idempotent and preserves your opt-outs.

It never writes a secret: endpoints are stored by name, and their url and
`api_key_env` stay in the `chat-subagent` registry.

**Copilot is one adapter, not the only possible remote reviewer.** Phase B is a
forge-reviewer slot with three operations — request, poll, recognize a clean pass.
GitHub Copilot ships as the built-in binding of those operations. Other forges have
review agents; this skill names none and implements none, because an adapter nobody
here can run would poll forever or report a clean pass that never happened. Declare
one, supply its three commands and an unambiguous `clean_when`, and the loop drives
it. With no forge reviewer enrolled, Phase B is skipped and the local panel is the
whole loop.
```

- [ ] **Step 3: Verify**

Run:
```bash
test -f plugins/review-loop/commands/init.md && echo "command exists"
grep -n 'review-loop:init' plugins/review-loop/skills/review-loop/README.md
head -3 plugins/review-loop/commands/init.md
```
Expected: the file exists; README mentions `init`; the command doc opens with `---` frontmatter carrying exactly one `description:` key.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/commands/init.md plugins/review-loop/skills/review-loop/README.md
git commit -m "feat(review-loop): add /review-loop:init and document the forge slot

init probes CLI presence, then VERIFIES INVOCATION BY TRYING -- one real call per
enrolled CLI against a throwaway fixture diff, never the user's working tree, since
calibrating an unenrolled third-party CLI on real changes would ship their code to
a service they have not agreed to enroll. It stores the literal command line that
worked. A CLI whose invocation cannot be established is detected but not enrolled.

gh presence only offers Copilot; gh auth status decides it. Presence is not
authentication (SKILL.md requires 'the authenticated gh CLI').

Implements spec 014 §A.3, §A.4, §A.8."
```

---

## Task 4: `SKILL.md` — Phase A restructured into a blind panel

The heart of the change. §B.2, §B.2.1–§B.2.4.

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (Phase A, ~57–63)

- [ ] **Step 1: Replace A1/A2's serial preamble with the blind panel**

Find (verbatim):

```
**A1. Claude subagent review** — dispatch a subagent to review the diff. Classify findings into T1/T2/T3, post the grouped list, resolve T2/T3 picks, then apply fixes (per *Tiers*). Commit fixes; push only if a remote/PR branch exists, otherwise commit locally.
```

Replace with:

````
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
  brief names the exact range `<base>..<head-sha>`, requires the review to state the
  commit range and file list it actually reviewed as its first line, and the
  facilitator compares that against `git diff --name-only "$base"..."$head"`. A
  mismatch → re-run once with the diff embedded (which cannot be inferred wrong); a
  second mismatch → §B.7 panelist failure: drop, continue, disclose.
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

**A panelist that dies between R1 and R2** (usage limit, or a §B.7 double failure)
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
findings. **Every live panelist blocks**; a panelist dropped under §B.7 stops
blocking the moment it is disclosed as dropped, and one that went clean then died
does not un-clean the gate.

**Output volume.** An auto-fixed finding prints as **one line** (claim, location,
commit). A `refuted` finding prints as one line plus who refuted it and why. A
**`refuted-undefended` finding prints as a live disagreement, never a one-liner** —
a "refuted by X" one-liner hides that nobody checked. The full record is reserved
for findings the author must judge: T2/T3, live disagreements, and anything that
failed the auto-fix gate.
````

- [ ] **Step 2: Relabel the old serial steps the new Phase A replaced**

Step 1 inserts a new `A1`–`A4`. The **old** `**A2. Codex review**` and
`**A3. Converge the local gate**` bullets are still below it, so the file would carry
two `A2` labels and two `A3` labels — and the old ones still tell the agent to have
Claude review and fix, then let Codex read the already-fixed tree. Their bodies must
NOT be deleted: they hold the sandbox routing, the embedded-diff form, the
`command_execution` detector, `thread_id` resume, exit-code triage and usage-limit
handling, all of which spec 014 keeps unchanged. Relabel them into shared mechanics.

Replace the `**A2. Codex review** (only if …` line with a `#### Codex mechanics — how
the Codex panelist is driven (used by R1, R2 and A4)` heading, opening "This section is
**not a step**." Replace the `**A3. Converge the local gate**` line with
`#### Availability, not cleanliness — when a panelist stops blocking`, keeping its
availability rules and dropping "re-run A1/A2 after fixes".

Then **repoint the cross-references the relabel orphans.** Two sentences say `see A2`
and `the embedded-diff form (A2)`; both meant the old Codex step and now point at the
cross-critique round. Send them to *Codex mechanics*. Find them with:
```bash
grep -n 'see A2\|(A2)\|A1/A2\|§A2' plugins/review-loop/skills/review-loop/SKILL.md
```
Expected after the fix: no matches. `SKILL.md` is read by an agent, and an agent goes
where it is sent.

- [ ] **Step 3: Verify**

Run:
```bash
grep -c '^\*\*A2\.' plugins/review-loop/skills/review-loop/SKILL.md   # exactly 1
grep -c '^\*\*A3\.' plugins/review-loop/skills/review-loop/SKILL.md   # exactly 1
grep -n 'blind\|cross-critique\|refuted-undefended\|git diff --name-only' plugins/review-loop/skills/review-loop/SKILL.md
awk '/^```/{n++} END{print "fences:", n, (n%2==0 ? "balanced" : "UNBALANCED")}' plugins/review-loop/skills/review-loop/SKILL.md
```
Expected: matches for all four; fences **balanced**.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): blind parallel round 1 + one cross-critique round

Reviewers were serial gates: Claude reviewed, fixes were committed, then Codex
reviewed the already-fixed tree -- so Codex could never dispute Claude's reading of
a finding, and neither ever critiqued the other's findings. Now both review the
same unfixed diff blind, then attack each other's lists.

R1 uses Codex's freeform native form because the targeted form takes no prompt, and
without a prompt Codex cannot be asked for the finding record, which would make the
panel's only tier-1 reviewer the one that can never be auto-fixed. Freeform infers
its diff, so the brief pins the range and the facilitator checks the echoed file
list against git diff --name-only: an inference is not a guarantee, and R1's whole
value is that every panelist saw the same diff.

R2 is exempt from the command_execution detector -- not because a critique round
reads no files (a good one reads many; reproduction means opening the cited line)
but because the detector's inference only holds for a round whose job is reviewing
the tree. An R2's subject is the findings.

The R2 prompt does not mandate a disagreement. Manufacturing a refutation when the
other panelist is right is worse than missing one.

Implements spec 014 §B.1, §B.2, §B.2.1-§B.2.4."
```

---

## Task 5: `SKILL.md` — finding record, status ladder, auto-fix gate, reproduction

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (the *Tiers* section, ~47–53)

- [ ] **Step 1: Extend Tiers with the record, the ladder, and the gate**

Find (verbatim):

```
Per round: post the grouped findings, **resolve T2/T3 with the author first** (quote the comment, draft 2–3 approaches with trade-offs, recommend one, wait for their pick), **then** apply the fixes — T1 auto-fixed, T2/T3 done as chosen. One commit per item, TDD, and reply/note the commit hash. (TDD and one-commit-per-item apply to executable changes; for prose/doc targets there are no tests to write first — prefer one logical edit per finding and review for clarity, consistency, structure, and factual accuracy.) Architectural decisions always land before mechanical edits are committed.
```

Replace with:

````
Per round: post the grouped findings, **resolve T2/T3 with the author first** (quote the comment, draft 2–3 approaches with trade-offs, recommend one, wait for their pick), **then** apply the fixes — T1 auto-fixed **only through the gate below**, T2/T3 done as chosen. One commit per item, TDD, and reply/note the commit hash. (TDD and one-commit-per-item apply to executable changes; for prose/doc targets there are no tests to write first — prefer one logical edit per finding and review for clarity, consistency, structure, and factual accuracy.) Architectural decisions always land before mechanical edits are committed.

### The finding record

**Scope: this and the auto-fix gate govern the local panel only.** A forge reviewer
is not a panelist — it never enters R1 or R2, so its comments can never reach
`survived`, and Copilot cannot be asked for a confidence. Phase B keeps the rule
above unchanged: T1 auto-fixed, T2/T3 to the author.

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
````

- [ ] **Step 2: Verify**

Run: `grep -n 'refuted-undefended\|facilitator confirms the quote\|survived' plugins/review-loop/skills/review-loop/SKILL.md`
Expected: matches for each. Then re-check fence balance as in Task 4 Step 2.

- [ ] **Step 3: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): finding record, status ladder, and an auto-fix gate

confidence is a self-report by the same weights that produced the finding, so it
authorizes nothing alone; what authorizes an automatic fix is surviving an adversary
or being reproduced. Gating on '!= refuted' would have admitted `proposed` -- an
uncritiqued finding -- which on a Claude-only run reduces to a same-family reviewer
grading its own finding high and auto-committing it. That is the pre-014 failure mode
with extra paperwork. The gate now turns on `survived`.

refuted is split: an attack its author never answered is `refuted-undefended`, a live
disagreement, never a verdict the facilitator may act on.

Prose `reproduced` requires the FACILITATOR to verify the citation with a command and
the fix to be mechanically checkable. 'A reader can check it' is capability, not a
check, and a lone reviewer quoting a passage then attaching its own interpretation
would otherwise auto-commit in the one configuration with no adversary.

Implements spec 014 §B.3, §B.4, §B.5."
```

---

## Task 6: `SKILL.md` — non-leading convergence, ghost gate, facilitator discipline

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (Convergence rounds ~156–166; add a Facilitator subsection)

- [ ] **Step 1: Replace the leading convergence prompt**

Find (verbatim):

```
  printf '%s\n' "I applied these fixes: <summary>. Are your earlier points resolved? Any new concerns?" \
```

Replace with:

```
  printf '%s\n' "Here is the current diff. For each point you raised, verify it AGAINST THE CODE and state resolved or unresolved, with the evidence you used. Do not treat the author's description of the fix as evidence. Then state any new concerns." \
```

- [ ] **Step 2: Add the sycophancy guard and the facilitator rules**

Find (verbatim):

```
## Learning capture
```

Replace with:

```
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
```

- [ ] **Step 3: Extend Learning capture with the R2 cost data**

Find (verbatim):

```
- Repeat-issue escalations (these = gaps in the project's conventions; candidates for the project's guidelines doc)
```

Replace with:

```
- Repeat-issue escalations (these = gaps in the project's conventions; candidates for the project's guidelines doc)
- **R2's kill rate and rounds consumed.** Cross-critique costs one extra call per panelist before the first fix, and usage limits are a first-class outcome — so the marginal cost is not "one more call" but "one fewer convergence round before the limit". That R2 pays for itself (false positives dying before they become a commit, a test, and a convergence round) is a **hypothesis**. Record the data so it can be checked.
```

- [ ] **Step 4: Verify**

Run:
```bash
grep -c 'Are your earlier points resolved' plugins/review-loop/skills/review-loop/SKILL.md
grep -n 'retains both verbatim texts\|Do not treat the author' plugins/review-loop/skills/review-loop/SKILL.md
```
Expected: first prints `0`; second prints both matches.

- [ ] **Step 5: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): non-leading convergence, ghost gate, facilitator discipline

The convergence prompt asked Codex to accept Claude's own summary of Claude's own
fixes as evidence, phrased so that 'yes' was the cooperative answer. It now hands over
the diff and asks for verification against the code, explicitly refusing the author's
description as evidence.

Facilitator capture was unguarded: Claude is both panelist and adjudicator, and nothing
stopped it quietly downgrading a Codex finding it disliked. Attribution moves into the
round output, the facilitator's own views get a labelled section that gates nothing, and
merged duplicates keep both verbatim texts -- deduplication was the largest capture
surface and attribution alone does not close it. Two panelists slicing one problem
differently are not agreeing.

Implements spec 014 §B.6, §B.7, §B.8."
```

---

## Task 7: `SKILL.md` — report the panel that actually ran; degradation

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (Exit conditions ~199–201)

- [ ] **Step 1: Replace the local-gate exit bullet**

Find (verbatim):

```
- **Local gate clean + (for GitHub) Copilot clean pass** (matches "generated no comments." / "generated no new comments.") → stop and surface to the author. This is the primary, explicit stop signal — prefer it over inferring doneness from "no new comments for N polls".
```

Replace with:

```
- **Local gate clean + (for a forge target) the enrolled forge reviewer's clean pass** → stop and surface to the author. This is the primary, explicit stop signal — prefer it over inferring doneness from "no new comments for N polls".
- **"Clean" is not one verdict.** State the panel's composition and the evidential weight of its agreement:
  - **Heterogeneous** — at least one live tier-1 **CLI** panelist alongside Claude → convergence is meaningful evidence.
  - **User-asserted** — the only non-Claude panelist is a declared endpoint (`trust: user-asserted`). Report it as such; a config file must not buy the heterogeneous tier.
  - **Same-family** — Claude plus a different Claude model → "gate clean at tier 2 — same-family panel, shared blind spots possible; this is **weak evidence**."
  - **Fresh-context only** — the subagent's echoed model id equals the session model, is absent, or the requested model was not dispatchable. The weakest verdict there is. Say it.
  - Report the panel that **actually ran, verified**: the model that actually *differed* (the subagent echoes its model id on the first line of its record — a self-report, weak, and still better than asserting a tier from a config field), the CLI that actually returned findings. Where the composition changed mid-run, report it **per round**, not by its best round.
  - Any `unreproduced` correctness finding withholds "gate clean": report "clean except N unreproduced correctness findings" and let the author waive them.
- **Degradation.** Only Claude available → single reviewer, no cross-critique, and the same-family caveat above. Two or more Claude panelists and no external CLI → force **method-level divergence**, not tone (first principles / base rates / disconfirming evidence only); a role name like "Red Team" does not decorrelate errors, a different method or an actual reproduction does — and the verdict stays same-family either way.
```

- [ ] **Step 2: Verify**

Run: `grep -n 'weak evidence\|Fresh-context only\|per round' plugins/review-loop/skills/review-loop/SKILL.md`
Expected: matches for each.

- [ ] **Step 3: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): the gate verdict names the panel that actually ran

'Local gate clean' was reported identically whether Codex participated or not, though
the two verdicts carry very different evidential weight. Same-family convergence is now
labelled weak evidence, a user-asserted endpoint cannot buy the heterogeneous tier, and
a claude-alt that turns out to equal the session model degrades to fresh-context only.

'Verified' means the model actually DIFFERED and the CLI actually returned findings --
not that a config field was set. The subagent echoes its model id; that is a model's
self-report and a weak check, and it is still strictly better than asserting a tier from
a config file. Where a check is weak, report the verdict it supports and no stronger.

Implements spec 014 §B.9, §B.10."
```

---

## Task 8: `SKILL.md` — Phase B becomes a forge slot

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (Phase B heading ~177; Non-goals ~232–237)

- [ ] **Step 1: Retitle Phase B and frame Copilot as an adapter**

Find (verbatim):

```
### Phase B — GitHub Copilot (only for GitHub PR targets)
```

Replace with:

```
### Phase B — Forge reviewer (only when one is enrolled and the target is a PR/MR)

A **forge reviewer** lives on the code-hosting platform and is reachable only once the
change is a pull/merge request. It has three operations: **request**, **poll for
comments**, and **recognize a clean pass**. It is **not a panelist** — it never enters
R1 or R2, so the finding record and the auto-fix gate do not govern it; the *Tiers*
rules apply unchanged (T1 auto-fixed, T2/T3 to the author).

**No forge reviewer enrolled → skip Phase B silently.** The local panel is the whole
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
```

- [ ] **Step 2: Correct the Non-goals that the rest of the spec repudiates**

Find (verbatim):

```
- The Copilot path is GitHub-only (uses `gh` + GitHub GraphQL). For other forges, the local Claude + Codex gate still applies; the remote-reviewer phase does not.
```

Replace with:

```
- The **built-in** forge adapter is GitHub-only (it uses `gh` + GitHub GraphQL). Other forges are reachable by declaring a reviewer and its three commands; none ships. With no forge reviewer, the local panel gate is the whole loop.
- **Not changing:** the sandbox routing, the embedded-diff form, the `command_execution` detector's **jq predicate**, exit-code triage, the Copilot adapter's behavior, or the never-merge rule. Two things *do* change and are named so nobody can satisfy this list by ignoring them: the detector's **scope** gains an R2-critique exemption (A2), and Phase B's *framing* becomes a forge slot while its Copilot behavior is preserved verbatim.
- **Not a debate machine.** With the default two-panelist panel, cross-critique is **one round**. Two bounded additions: a separate Round 3 with **≥ 3** panelists, and the reversal-grounds ask. Panelist disagreement about executable code is settled by a test, not by more rounds.
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -c '^### Phase B — GitHub Copilot' plugins/review-loop/skills/review-loop/SKILL.md
grep -n 'forge reviewer\|clean_when' plugins/review-loop/skills/review-loop/SKILL.md | head -5
```
Expected: first prints `0` (heading gone — note it was an **h3**, so a `^## ` regex would never have matched it); second prints matches.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): Phase B is a forge slot, not a Copilot phase

Phase B was an adapter masquerading as an architecture: gh, a GraphQL mutation and a
Copilot stop-regex written straight into the skill. It becomes three operations --
request, poll, recognize a clean pass -- with GitHub Copilot as the one built-in
adapter, because its scripts exist and have been exercised. Not 'tested': nothing in
tools/ touches copilot.sh or pr-comments.sh, and that word was load-bearing in the
argument for why this adapter ships and others do not.

Other forges have review agents. This skill names none and implements none. An adapter
written from documentation for a service nobody here can run is a ghost panelist one
layer up -- it would poll forever, or report a clean pass that never happened. A
declared reviewer with no unambiguous clean signal gets none invented for it.

Also corrects two Non-goals bullets that the rest of the spec repudiates.

Implements spec 014 §B.11."
```

---

## Task 9: Command doc invariants, content anchors, version bump

**Files:**
- Modify: `plugins/review-loop/commands/review-loop.md`
- Modify: `tools/review-loop/test-skill-content.sh`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Refresh `SKILL.md`'s frontmatter and intro — they still describe 0.4.0**

Three lines still tell the reader the loop is serial. The `description` drives when the
skill triggers, so a stale one misleads users, and the "Why this loop exists" paragraph
now flatly contradicts Tasks 4–8.

Find (verbatim, line 3):

```
description: General assisted review loop for changes — code or design artifacts (specs, plans, docs). Prefers local reviewers (Claude subagent + headless Codex via `codex exec review`) as the first gate; for GitHub PR targets, also requests Copilot after the PR is open. Loops each reviewer until clean or its usage limit, classifies comments into tiers, auto-fixes mechanical ones, pauses on architectural ones for user judgment. Never merges autonomously.
```

Replace with:

```
description: General assisted review loop for changes — code or design artifacts (specs, plans, docs). Runs an adversarial panel of local reviewers: every live panelist answers blind on the same unfixed diff, then attacks the others' findings, before any fix is applied. Reviewers are discovered at loop start and may be enrolled by `/review-loop:init`, which is never a precondition; the gate names the panel that actually ran and calls same-family agreement weak evidence. For PR/MR targets an enrolled forge reviewer (GitHub Copilot is the built-in adapter) runs after the local gate is clean. Findings carry a confidence and a falsification condition; a finding no adversary examined is never auto-fixed. Never merges autonomously.
```

Find (verbatim, line 10):

```
**Local reviewers are preferred and run first.** A Claude subagent and Codex (headless, via `codex exec review`) cost nothing extra and are fast, so they are the first gate. Codex runs wherever the `codex` CLI is on `PATH` — no tmux needed; tmux only adds a live-watch pane **when the user asks to watch** (never by default). GitHub Copilot is added only when the target is a GitHub PR, and only after the local gate is clean.
```

Replace with:

```
**Local reviewers run first, and they run as a panel.** Every live panelist reviews the same **unfixed** diff blind — none sees another's findings — and then cross-critiques. Codex runs wherever the `codex` CLI is on `PATH` — no tmux needed; tmux only adds a live-watch pane **when the user asks to watch** (never by default). A forge reviewer (GitHub Copilot is the built-in adapter) is added only when the target is a PR/MR, and only after the local gate is clean.
```

Find (verbatim, line 14):

```
Claude and Codex reviewing **together** produces noticeably better output than either model alone — they catch different classes of issues, and Codex's pass tightens the diff before it ever reaches GitHub. The downstream payoff: by the time Copilot sees the PR, there's much less for it to complain about, so review rounds converge faster. Front-loading combined local Claude+Codex review as the first gate is the entire reason this loop exists.
```

Replace with:

```
A reviewer catches what the author missed only when their failure modes differ. A model asked to critique its own output draws that critique from the same weights that produced the blind spot, so a same-family panel agreeing is weaker evidence than it looks. Running Claude and Codex **blind and in parallel**, then having each attack the other's findings, is what decorrelates the errors — and it kills false positives before they become commits, tests, and convergence rounds. Serial review cannot do this: a reviewer shown the already-fixed tree is anchored on the first reviewer's judgement and can no longer dispute it. That is the entire reason this loop exists.
```

- [ ] **Step 2: Verify the intro no longer describes a serial gate**

```bash
S=plugins/review-loop/skills/review-loop/SKILL.md
grep -c 'as the first gate is the entire reason' "$S"   # expect 0
grep -c 'run as a panel' "$S"                            # expect 1
grep -c 'adversarial panel of local reviewers' "$S"      # expect 1
```
Expected: `0`, `1`, `1`. Do **not** check these with one `grep 'A\|B\|C'` — an OR match hides a miss in any single branch.

- [ ] **Step 3: Update the command doc's invariants**

Find (verbatim):

```
- **Copilot is GitHub-only** — requested only for PR targets, after the local gate.
```

Replace with:

```
- **Blind round 1, then one cross-critique round** — every live panelist reviews the
  same unfixed diff without seeing the others, then attacks their findings. Never
  auto-fixes a finding that no adversary examined.
- **Forge reviewers are enrolled, not assumed** — GitHub Copilot is the one built-in
  adapter, requested only for PR targets after the local gate. With none enrolled,
  Phase B is skipped.
- **`/review-loop:init`** — optional; discovers which coding CLIs this host has and
  verifies how to call each one by actually calling it.
```

- [ ] **Step 4: Add the spec-014 anchors**

Find (verbatim):

```
echo "All SKILL.md content checks passed."
```

Replace with:

```
# spec 014 Part A — roster, init, calibration
need_new 'Roster reconciliation'                         "roster reconciled at loop start"
need_new 'review-loop\.local\.md'                        "enrollment config path"
need_new 'derived from `kind`'                           "tier is derived, not declared"

# spec 014 Part B — the adversarial panel
need_new 'blind'                                         "round 1 is blind"
need_new 'cross-critique'                                "round 2 exists"
need_new 'refuted-undefended'                            "the status that had to exist"
need_new 'survived'                                      "gate turns on survived, not != refuted"
need_new 'falsification'                                 "finding record carries a falsification condition"
need_new 'facilitator confirms the quote'                "prose reproduction is a check, not a capability"
need_new 'retain both verbatim texts'                    "dedup cannot launder attribution"
need_new 'weak evidence'                                 "same-family convergence is labelled weak"
need_new 'critique rounds are now exempt'                "R2 detector exemption"
need_new 'forge reviewer'                                "Phase B is a slot"
need_new 'clean_when'                                    "declared reviewers pin their stop signal"

# the leading convergence prompt is gone
refute 'Are your earlier points resolved'                "leading convergence prompt"
# the old Copilot-only Phase B heading is gone (note: it was an h3, not an h2)
refute '^### Phase B — GitHub Copilot'                   "Copilot-only Phase B heading"

echo "All SKILL.md content checks passed."
```

- [ ] **Step 5: Close the cross-link between the fixture test and SKILL.md**

Task 0's `test-detector-predicate.sh` pins `critique → review`, but nothing ties that
to the exemption prose Task 4 wrote into `SKILL.md`. Both could be green while
disagreeing. Add the link now that both exist.

In `tools/review-loop/test-detector-predicate.sh`, find (verbatim):

```
echo "All detector-predicate checks passed."
```

Replace with:

```
# Cross-link: the exemption this test pins must actually be stated in SKILL.md.
# Without this, Task 4 could land an exemption that contradicts these fixtures and
# both suites would still pass.
SKILL="$SCRIPT_DIR/../../plugins/review-loop/skills/review-loop/SKILL.md"
grep -Eqi 'R2 critique rounds are [a-z ]*exempt' "$SKILL" \
  || fail "SKILL.md does not state the R2 critique exemption this test pins"
grep -Eq 'zero .*command_execution' "$SKILL" \
  || fail "SKILL.md no longer describes the zero-command detector condition"
pass "SKILL.md states the exemption these fixtures pin"

echo "All detector-predicate checks passed."
```

Run: `bash tools/review-loop/test-detector-predicate.sh`
Expected: seven `PASS:` lines, exit 0.

Prove the link can fail — temporarily break the prose, confirm red, restore:
```bash
cp plugins/review-loop/skills/review-loop/SKILL.md /tmp/skill.bak
sed -i 's/R2 critique rounds are EXEMPT/R2 critique rounds are handled normally/; s/R2 critique rounds are now exempt/R2 critique rounds are handled normally/' plugins/review-loop/skills/review-loop/SKILL.md
bash tools/review-loop/test-detector-predicate.sh; echo "exit=$?"
cp /tmp/skill.bak plugins/review-loop/skills/review-loop/SKILL.md; rm /tmp/skill.bak
bash tools/review-loop/test-detector-predicate.sh >/dev/null && echo "restored green"
```
Expected: `FAIL: SKILL.md does not state the R2 critique exemption this test pins`, non-zero exit, then `restored green`. The `sed` must break **both** phrasings — Task 4 writes "R2 critique rounds are EXEMPT from the post-round…" and Task 6 writes "R2 critique rounds are now exempt too" — so the grep is case-insensitive. If the break does not turn the suite red, the grep does not match what Tasks 4/6 actually wrote: **fix the grep to match the prose, never the prose to match the grep.**

- [ ] **Step 6: Bump the version and the description**

Find (verbatim):

```
      "description": "Assisted multi-reviewer review loop — local Claude + Codex gate first, then GitHub Copilot for PRs; never merges autonomously",
      "version": "0.4.0"
```

Replace with:

```
      "description": "Assisted adversarial review panel — reviewers answer blind, attack each other's findings, then converge; enrolled roster via /review-loop:init; never merges autonomously",
      "version": "0.5.0"
```

- [ ] **Step 7: Run the full harness**

Run: `bash tools/review-loop/test-skill-content.sh`
Expected: every check passes, including each `need_new`, ending `All SKILL.md content checks passed.`

If a `need_new` reports **`vacuous anchor (already present at <sha>)`**, the anchor phrase
already existed in `0.4.0`. **Fix the anchor, never the harness** — pick a phrase unique to
the new behavior. This is the failure mode the helper exists to catch.
If `refute '^### Phase B — GitHub Copilot'` fails, Task 8 Step 1 did not land.

- [ ] **Step 8: Validate the manifest**

Run:
```bash
jq -r '.plugins[] | select(.name=="review-loop") | .version' .claude-plugin/marketplace.json
jq . .claude-plugin/marketplace.json >/dev/null && echo "valid json"
```
Expected: `0.5.0`, then `valid json`.

- [ ] **Step 9: Commit**

```bash
git add plugins/review-loop/commands/review-loop.md tools/review-loop/test-skill-content.sh .claude-plugin/marketplace.json
git commit -m "chore(review-loop): bump to 0.5.0; anchor spec 014 with need_new

Every anchor guarding new behavior is novelty-checked, so a guard that would pass
against the unmodified SKILL.md fails the suite instead. The Phase B refute is anchored
on '^### ' -- the heading is an h3, and the h2-anchored regex proposed during review
could never have matched it.

Implements spec 014 § Testing."
```

---

## Task 10: Full gate and manual verification

- [ ] **Step 1: Run everything**

Run:
```bash
bash tools/review-loop/test-skill-content.sh
bash tools/review-loop/test-detector-predicate.sh
bash tools/review-loop/test-sandbox-preflight.sh
```
Expected: three suites, all exit 0.

- [ ] **Step 2: Clean tree, no conflict markers, no secrets**

Run:
```bash
git status --short
git diff --cached --check
git grep -nE 'api_key|Authorization|ghp_|sk-' -- plugins/review-loop || echo "no secrets"
```
Expected: clean tree; no whitespace/conflict errors; `no secrets` (or only the *names*
`api_key_env` in prose that forbids storing keys — read each hit, do not assume).

- [ ] **Step 3: Exercise the probe for real**

Run:
```bash
for cli in codex gemini cursor-agent opencode aider crush amp llm gh; do
  command -v "$cli" >/dev/null 2>&1 && echo "$cli present" || echo "$cli absent"
done
```
Expected: `codex present`, `gh present`, the rest `absent` on this host. Confirm `SKILL.md` carries this loop and that **no** new file exists under `plugins/review-loop/skills/review-loop/scripts/`.

- [ ] **Step 4: Manual read-through**

Confirm by reading `SKILL.md`:
- A1 says panelists review **blind**, on the same **unfixed** diff, and R1 findings are shown to the author as `proposed`.
- The freeform-native R1 pins `<base>..<head-sha>` and checks the echoed file list against `git diff --name-only`.
- R2's prompt asks for the claim you "tried hardest to break" and **does not** mandate a disagreement.
- The R2 detector exemption's stated reason is the **category error** (an R2's subject is the findings), not "critique rounds read no files".
- The gate is `survived ∨ reproduced`; a single-panelist run auto-fixes on `reproduced` alone.
- Prose `reproduced` requires the **facilitator** to verify the citation.
- Phase B is titled for the forge reviewer; Copilot's B0–B5 behavior is intact.

- [ ] **Step 5: Record results** for the PR body (no commit).

Note Task 0's recorded preflight verdict: whether the native path was exercisable here, or whether the fixtures are the coverage.

---

## Task 11: Open the PR

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/review-loop-adversarial-panel
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --base main --head feat/review-loop-adversarial-panel \
  --title "review-loop 0.5.0: enrolled reviewer roster + adversarial panel" \
  --body "$(cat <<'EOF'
Implements [spec 014](docs/superpowers/specs/014-review-loop-adversarial-panel-design.md).

## Part A — the roster is enrolled, not assumed
- `/review-loop:init` probes which coding CLIs exist, then **verifies how to call each one by actually calling it**, on a throwaway fixture diff — never your real working tree. A CLI whose invocation cannot be established is detected but not enrolled.
- The presence probe is a `command -v` sweep the agent runs inline. **No new script ships**: wrapping `command -v` in a program buys a maintenance burden and calcifies a decision a more capable model will make correctly without help. `<cli> --version` runs during `init` only.
- `gh` presence only *offers* Copilot; `gh auth status` decides it. Presence is not authentication.
- Drift (enrolled-but-absent, present-but-unenrolled, stale recipe) is always surfaced, never silently followed. A recipe never suppresses the preflight or the `command_execution` detector.

## Part B — reviewers become adversaries
- **Blind parallel round 1** on the same unfixed diff, then **one cross-critique round**. Previously Codex only ever saw the tree Claude had already fixed, so it could never dispute Claude's reading of a finding.
- Findings carry attribution, tier, **confidence**, and a concrete **falsification condition**. `confidence` is a self-report and authorizes nothing; what authorizes an auto-fix is `survived` (faced an adversary) or `reproduced`.
- `refuted` split: an attack its author never answered is `refuted-undefended` — a live disagreement, not a verdict.
- Prose targets get a `reproduced` analogue, but the **facilitator** must verify the citation with a command.
- The gate verdict names the panel that actually ran and labels same-family convergence as weak evidence.
- Phase B becomes a forge slot; Copilot is its one built-in adapter. Other forges' agents are neither named nor shipped — we cannot exercise what we have no access to.

## Tests
- New: `tools/review-loop/test-detector-predicate.sh` + recorded `codex --json` fixtures, covering the R2 detector exemption — the one branch that cannot execute on a host routed to embedded-diff. The suite is demonstrated to go red when the exemption is removed.
- New: `need_new()` in `tools/review-loop/test-skill-content.sh` — an anchor that already matches the pre-change `SKILL.md` now **fails the suite**. Three such vacuous anchors were proposed during this spec's own review rounds.

## Known coverage gap
<!-- Fill from Task 0's recorded verdict. If the preflight reported `broken`/`unknown`: -->
This host's Codex sandbox preflight reports `broken`, so every Codex round routes to the embedded-diff form — a **fully supported path**, not a degradation. The consequence is a testing gap, not a running one.

`tools/review-loop/test-detector-predicate.sh` covers the R2 detector exemption with recorded `codex --json` fixtures: the predicate and the routing decision are pinned deterministically, and the test is shown to be capable of failing. What the fixtures do **not** prove is that `codex exec resume` behaves as documented against a live `usable` sandbox. That residue is disclosed here rather than implied.

Restoring the native path is an AppArmor/sysctl change affecting every `bwrap` caller on the machine. It is **separate work that the author owns**, not a prerequisite for this PR, and nothing here asks for `sudo`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Gate the PR**

Run `/review-loop <PR#>` to add the forge-reviewer phase. **Never merge autonomously** — the author decides. Prefer a merge commit over a squash.

---

## Self-Review (completed by plan author)

**1. Spec coverage.** §A.1 → Task 2. §A.2 (inline probe, no script) → Task 2. §A.3 → Task 3. §A.4 (asks, forge slot, `clean_when`) → Tasks 3, 8. §A.5 (config shape) → Tasks 2, 3 — the file is written by `init` at runtime, not committed; its schema is documented in `init.md` and `SKILL.md`. §A.6 → Task 2. §A.7 → Task 2 (zero-config hint) + Task 10 Step 4. §A.8 → Tasks 2, 3. §B.1–§B.2.4 → Task 4. §B.3–§B.5 → Task 5. §B.6–§B.8 → Task 6. §B.9–§B.10 → Task 7. §B.11 → Task 8. §B.12 → Task 0 (fixture coverage; never a host change) and the PR's "Known coverage gap". §B.13 (files) → Tasks 2–9. § Testing → Tasks 0, 1, 9, 10. Version bump → Task 9.

**2. Placeholder scan.** No TBD/TODO. Every `SKILL.md` edit carries verbatim Find/Replace text; the fixtures and both new test scripts are given in full; the one intentional fill-in (the PR's coverage-gap paragraph) is explicitly sourced from Task 0's recorded preflight verdict.

**3. Name consistency.** `need_new` (never `needNew`); `invocation.command` / `invocation.form` / `invocation.verified_with`; statuses `proposed` / `survived` / `refuted` / `refuted-undefended` / `reproduced` / `unreproduced` — used identically in Tasks 4, 5, 7 and in the Task 9 anchors. Every anchor phrase in Task 9 is quoted verbatim from the replacement text in Tasks 2, 4, 5, 6, 7, 8, and each was checked against the unmodified `SKILL.md` to confirm it does not already match.

**4. Ordering.** `need_new` (Task 1) lands before every anchor that uses it (Task 9) and before every `SKILL.md` edit it guards (Tasks 2, 4–8). Task 0's fixtures land before Task 4 adds the exemption they cover. Task 0 gates nothing on a human and never touches the host.

**5. No new shipped script.** Spec's "materialize critical knowledge only": the presence probe is prose the agent runs. The only new programs are dev tooling under `tools/review-loop/`, which never reaches a user's disk.

**6. Branch discipline.** All work on `feat/review-loop-adversarial-panel` in the worktree at `/dev/shm/dong3/review-loop-panel`; every git command runs from inside it.
