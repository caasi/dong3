# review-loop Codex Sandbox False-Clean Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `review-loop` skill's local Codex gate never report a silent false-clean when Codex's sandbox can't read the local tree (the design-artifact-committed-to-`main`, unpushed case), per [spec 009](../specs/009-review-loop-codex-sandbox-fix-design.md).

**Architecture:** One new shipped helper script (`sandbox-preflight.sh`, a routing-hint probe), targeted edits to `SKILL.md` Phase A2 (route by sandbox state, embedded-diff fallback, a post-round structural detector that is the real guarantee), and a new host-fix reference doc. Plus a plain-bash unit test (stubbed `bwrap`) and a content-regression test under repo-level `tools/review-loop/`.

**Tech Stack:** Bash (`#!/usr/bin/env bash`, `set -euo pipefail`), `bwrap` (bubblewrap), `jq`, `codex` CLI, Markdown. No build system — this is a plugin/skill repo.

---

## Scope & Conventions

- **This is implementation, not docs.** The script + SKILL.md (a system prompt that changes runtime behavior) + manifest are code. **Work on a feature branch in a worktree — never on `main`.** Branch name: `feat/review-loop-codex-sandbox-fix`. The execution skill creates the worktree (RAM disk, per `superpowers:using-git-worktrees`); every git command runs from inside that worktree.
- Conventional commits, scoped: `feat(review-loop):`, `test(review-loop):`, `docs(review-loop):`, `chore(review-loop):`.
- **Dev tooling stays out of the install boundary.** Tests/fixtures go under `tools/review-loop/`, never under `plugins/review-loop/`.
- The spec (`docs/superpowers/specs/009-review-loop-codex-sandbox-fix-design.md`) is the source of truth; this plan implements it verbatim.

## File Structure

**Create (shipped to users — inside the install boundary):**
- `plugins/review-loop/skills/review-loop/scripts/sandbox-preflight.sh` — the preflight probe. One job: report whether Codex's command sandbox can build here (`usable`/`broken`/`unknown`).
- `plugins/review-loop/skills/review-loop/references/codex-sandbox-host-fixes.md` — pick-your-own host-fix menu (the skill never applies these).

**Create (dev tooling — outside the install boundary):**
- `tools/review-loop/test-sandbox-preflight.sh` — stubbed-`bwrap` unit test for the probe.
- `tools/review-loop/test-skill-content.sh` — content-regression test asserting the load-bearing SKILL.md anchors exist.

**Modify:**
- `plugins/review-loop/skills/review-loop/SKILL.md` — Phase A2 (spec §a–g).
- `.claude-plugin/marketplace.json` — `review-loop` version `0.2.0` → `0.3.0`.

---

## Task 1: Preflight probe script (`sandbox-preflight.sh`)

Implements spec **Component 1**. The script uses only bash builtins (`command`, `[[ =~ ]]`, `printf`) plus `bwrap`, so the test can fully control its environment by overriding `PATH`.

**Files:**
- Create: `plugins/review-loop/skills/review-loop/scripts/sandbox-preflight.sh`
- Test: `tools/review-loop/test-sandbox-preflight.sh`

- [ ] **Step 1: Write the failing test**

Create `tools/review-loop/test-sandbox-preflight.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="$SCRIPT_DIR/../../plugins/review-loop/skills/review-loop/scripts/sandbox-preflight.sh"
BASH_BIN="$(command -v bash)"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

make_stub() { # $1=dir name, $2=exit code, $3=stderr line
  mkdir -p "$tmp/$1"
  cat >"$tmp/$1/bwrap" <<EOF
#!/usr/bin/env bash
echo "$3" >&2
exit $2
EOF
  chmod +x "$tmp/$1/bwrap"
}

make_stub usable 0 ""
make_stub broken 1 "bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted"
make_stub other  1 "bwrap: something unrelated went wrong"
make_stub noctx  1 "some-tool: Operation not permitted"   # EPERM but no bwrap: context

run() { # $1=PATH to use ; prints "<stdout> <exit>"
  local out rc=0
  out="$(PATH="$1" "$BASH_BIN" "$PREFLIGHT" 2>/dev/null)" || rc=$?
  printf '%s %s' "$out" "$rc"
}

echo "Test 1: usable sandbox -> usable/0"
[ "$(run "$tmp/usable:$PATH")" = "usable 0" ] || fail "expected 'usable 0'"
pass "usable"

echo "Test 2: broken sandbox (EPERM) -> broken/1"
[ "$(run "$tmp/broken:$PATH")" = "broken 1" ] || fail "expected 'broken 1'"
pass "broken"

echo "Test 3: bwrap absent -> unknown/2"
[ "$(run "/nonexistent-preflight-dir")" = "unknown 2" ] || fail "expected 'unknown 2'"
pass "absent"

echo "Test 4: non-EPERM failure -> unknown/2"
[ "$(run "$tmp/other:$PATH")" = "unknown 2" ] || fail "expected 'unknown 2'"
pass "non-EPERM"

echo "Test 5: EPERM without a bwrap: setup line -> unknown/2"
[ "$(run "$tmp/noctx:$PATH")" = "unknown 2" ] || fail "expected 'unknown 2'"
pass "EPERM-without-bwrap-context"

echo "All sandbox-preflight tests passed."
```

Then make it executable:

```bash
chmod +x tools/review-loop/test-sandbox-preflight.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tools/review-loop/test-sandbox-preflight.sh`
Expected: FAIL (the script doesn't exist yet) — Test 1 fails or the script path errors.

- [ ] **Step 3: Write the probe script**

Create `plugins/review-loop/skills/review-loop/scripts/sandbox-preflight.sh`:

```bash
#!/usr/bin/env bash
# sandbox-preflight.sh — probe whether Codex's local command sandbox (bubblewrap)
# can build on this host. Prints one status word + matching exit code:
#   usable  (0)  bwrap built the sandbox
#   broken  (1)  bwrap failed at userns/loopback setup with an EPERM
#   unknown (2)  bwrap absent on PATH, or a non-EPERM failure — can't conclude
#
# This is a ROUTING HINT only. review-loop's post-round structural detector is the
# real guarantee. Caveat: if the user set features.use_legacy_landlock=true, Codex
# uses Landlock and never calls bwrap, so this may report `broken` while native
# `review` actually works — harmless, since the skill then routes to embedded-diff.
set -euo pipefail

if ! command -v bwrap >/dev/null 2>&1; then
  echo unknown
  exit 2
fi

# Match the namespaces Codex's own bwrap invocation creates (issue #41 strace):
# --unshare-user --unshare-net. Capture bwrap's stderr; discard its stdout.
rc=0
errout="$(bwrap --ro-bind / / --unshare-user --unshare-net --dev /dev true 2>&1 1>/dev/null)" || rc=$?

if [ "$rc" -eq 0 ]; then
  echo usable
  exit 0
fi

# Userns/loopback EPERM on a bwrap setup line (Ubuntu apparmor_restrict_unprivileged_userns)
# ⇒ broken. Scope to bwrap's own diagnostics (the `bwrap:` prefix) so an unrelated EPERM
# from elsewhere stays `unknown`, per spec Component 1 ("in a bwrap setup line").
pat='bwrap:.*(Operation not permitted|Permission denied)'
if [[ "$errout" =~ $pat ]]; then
  echo broken
  exit 1
fi

# Non-EPERM failure (e.g. bad flags, other bwrap error) ⇒ can't conclude.
echo unknown
exit 2
```

Then make it executable:

```bash
chmod +x plugins/review-loop/skills/review-loop/scripts/sandbox-preflight.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tools/review-loop/test-sandbox-preflight.sh`
Expected: PASS — all 4 tests, ending with `All sandbox-preflight tests passed.`

- [ ] **Step 5: Sanity-run on this host**

Run: `plugins/review-loop/skills/review-loop/scripts/sandbox-preflight.sh; echo "exit=$?"`
Expected on this Ubuntu 24.04 box: `broken` then `exit=1` (bwrap can't build its namespace here — this is the bug environment). On a host without bwrap: `unknown` / `exit=2`.

- [ ] **Step 6: Commit**

```bash
git add plugins/review-loop/skills/review-loop/scripts/sandbox-preflight.sh tools/review-loop/test-sandbox-preflight.sh
git commit -m "feat(review-loop): add sandbox-preflight.sh probe + stubbed-bwrap tests

Reports usable/broken/unknown for Codex's local command sandbox (bubblewrap).
Routing hint for SKILL.md A2; the post-round detector remains the guarantee.

Refs #41."
```

---

## Task 2: Host-fix reference doc

Implements spec **Component 3**. A pick-your-own menu; the skill never applies these. Prose — no test; verified by reading.

**Files:**
- Create: `plugins/review-loop/skills/review-loop/references/codex-sandbox-host-fixes.md`

- [ ] **Step 1: Create the reference doc**

Create `plugins/review-loop/skills/review-loop/references/codex-sandbox-host-fixes.md`:

````markdown
# Codex sandbox host fixes (optional)

`review-loop` works correctly **without any of these** — its embedded-diff fallback
sidesteps a broken sandbox entirely (option 5). These fixes are only for restoring
the *native* `codex exec review` path on a host where bubblewrap can't build its
sandbox (Ubuntu 23.10+/24.04 default `kernel.apparmor_restrict_unprivileged_userns=1`).
The skill **never** applies any of them — pick what fits your machine.

Symptom: `sandbox-preflight.sh` prints `broken`, and `codex … review --commit <unpushed-sha>`
returns a false-clean ("…not available in the connected GitHub repository").

| # | Fix | sudo / scope | Trade-off | Prefer when |
|---|-----|--------------|-----------|-------------|
| 1 | `bwrap-userns-restrict` AppArmor profile | sudo; all bwrap callers | durable; also blocks nested-ns escape | you want the native path back, durably |
| 2 | `features.use_legacy_landlock=true` | none; codex only | **deprecated** in recent codex | a quick, no-sudo stopgap |
| 3 | hand-rolled `/etc/apparmor.d/bwrap` `flags=(unconfined){userns}` | sudo; all bwrap callers | least strict (nested-escape hole) | only if #1 unavailable |
| 4 | `sysctl …apparmor_restrict_unprivileged_userns=0` | sudo; whole system | drops the hardening globally | last resort |
| 5 | skill-side embedded-diff | none | n/a — already automatic | always available; zero config |

## 1. `bwrap-userns-restrict` (recommended durable default)

Ships in Ubuntu's `apparmor-profiles` (default in 25.04; backportable to 24.04). Restores
bwrap's userns under an AppArmor profile **and** denies a sandboxed child from creating
further namespaces (closing the nested-escape gap that option 3 leaves open).

```bash
sudo apt install apparmor-profiles   # if not present
sudo systemctl reload apparmor
```

Verify:

```bash
bwrap --ro-bind / / --unshare-user --unshare-net --dev /dev echo OK   # prints OK
```

## 2. `features.use_legacy_landlock=true` (temporary compatibility workaround)

No sudo, scoped to codex; uses the Landlock LSM instead of bwrap, with the read-only
sandbox preserved. **Recent `codex` marks this deprecated and slated for removal** — treat
it as a stopgap, not a long-term default. If it is removed, fall back to #1 or rely on
the skill-side embedded-diff path.

```toml
# ~/.codex/config.toml
[features]
use_legacy_landlock = true
```

Verify:

```bash
codex exec --sandbox read-only review --commit <unpushed-sha>   # produces a real review
```

## 3. Hand-rolled `/etc/apparmor.d/bwrap` (inferior to `bwrap-userns-restrict`)

Works, but is the **least strict** variant: sandboxed children also get userns (the
nested-escape hole that `bwrap-userns-restrict` closes). Use only if option 1 is unavailable.

Create the profile and load it:

```bash
sudo tee /etc/apparmor.d/bwrap >/dev/null <<'EOF'
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
  include if exists <local/bwrap>
}
EOF
sudo apparmor_parser -r /etc/apparmor.d/bwrap
```

Verify:

```bash
bwrap --ro-bind / / --unshare-user --unshare-net --dev /dev echo OK   # prints OK
```

## 4. `sysctl …=0` (last resort — drops hardening system-wide)

```bash
echo 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system
```

This disables the 24.04 unprivileged-userns hardening for **every** process. Not recommended.

Verify:

```bash
sysctl kernel.apparmor_restrict_unprivileged_userns                  # = 0
bwrap --ro-bind / / --unshare-user --unshare-net --dev /dev echo OK  # prints OK
```

## 5. Skill-side embedded-diff (no host change)

This is what `review-loop` does automatically on a `broken`/`unknown` host: it embeds the
diff in the prompt (`git show <sha>` / `git diff <base>...HEAD`), so Codex needs no
sandboxed subprocess to read the tree. Zero config; always available. The other options
only matter if you specifically want the native `review` path back.

Verify (no host change — confirm the fallback itself yields a real review):

```bash
sha=$(git rev-parse HEAD)
printf '%s\n\n%s\n' "Review this diff for correctness and risk:" "$(git show "$sha")" \
  | codex exec --sandbox read-only -        # produces a real review with no native sandbox
```
````

- [ ] **Step 2: Verify it renders and links resolve**

Run: `ls plugins/review-loop/skills/review-loop/references/codex-sandbox-host-fixes.md && grep -c '^##' plugins/review-loop/skills/review-loop/references/codex-sandbox-host-fixes.md`
Expected: the path prints and the section count is `5` (five `## ` headings).

- [ ] **Step 3: Commit**

```bash
git add plugins/review-loop/skills/review-loop/references/codex-sandbox-host-fixes.md
git commit -m "docs(review-loop): add codex-sandbox-host-fixes reference menu

Pick-your-own host fixes (bwrap-userns-restrict recommended; legacy-landlock
demoted to deprecated workaround). The skill never applies these.

Refs #41."
```

---

## Task 3: SKILL.md A2 — preflight, routing, embedded-diff (spec §a–d)

Implements spec **§(a) preflight**, **§(b) reachability**, **§(c) routing**, **§(d) embedded-diff form**. Prose edits to the existing Phase A2. No automated test here (a system prompt); Task 6 adds a content-regression guard.

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (Phase A2)

- [ ] **Step 1: Read the current A2 section**

Run: `sed -n '63,132p' plugins/review-loop/skills/review-loop/SKILL.md`
Purpose: confirm the anchor text below still matches before editing.

- [ ] **Step 2: Add the preflight call to the log-setup block**

Find this block (the "Set up logs (once, at loop start)" fenced example) and append the preflight call. Replace:

```
  log="/tmp/review-loop-codex.<runid>.log"; err="/tmp/review-loop-codex.<runid>.err"
  : >"$log"   # cumulative across rounds — for the tail -f watch pane only
  ```
```

with:

```
  log="/tmp/review-loop-codex.<runid>.log"; err="/tmp/review-loop-codex.<runid>.err"
  : >"$log"   # cumulative across rounds — for the tail -f watch pane only
  # Preflight once: can Codex's command sandbox build here? Routing hint only.
  sandbox=$("${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/sandbox-preflight.sh" 2>/dev/null) || true   # usable | broken | unknown
  ```
```

- [ ] **Step 3: Add routing + reachability + embedded-diff before the "First round" bullet**

Find the bullet that begins:

```
- **First round — map the loop's target to a `review` invocation, with `--json`.**
```

Insert this new bullet block **immediately before** it:

```
- **Route by sandbox state, not by target.** The preflight `$sandbox` decides which Codex form is primary:
  - `usable` → native `review` (below): it reads the local tree directly, correct for pushed *and* unpushed targets (no remote fallback happens).
  - `broken` / `unknown` → **embedded-diff form** (below): native would fall back to the connected GitHub repo, which for a local-only target silently false-cleans. Embedding the diff sidesteps the sandbox entirely, so it is safe for every target on such a host. This also skips the wasted false-clean round on the common docs-to-`main` (unpushed design-artifact) case.

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
    | xargs -0 -I{} sh -c 'git diff --no-index /dev/null "$1" || true' _ {})"
  # then embed "$unc" in the prompt. A genuinely empty new file yields no diff —
  # append `git ls-files --others --exclude-standard` if its mere existence matters.
  ```
  On a `usable` sandbox prefer native `review --uncommitted` instead (it covers all three directly).
```

- [ ] **Step 4: Verify the edits read coherently**

Run: `sed -n '63,150p' plugins/review-loop/skills/review-loop/SKILL.md`
Expected: the preflight `sandbox=$(…)` line is in the log block; the "Route by sandbox state" and "Embedded-diff form" bullets precede "First round"; no broken markdown fences.

- [ ] **Step 5: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): A2 routes by sandbox state with embedded-diff fallback

Preflight probe at loop start; usable -> native review, broken/unknown ->
embedded-diff (diff in the prompt, no sandbox subprocess). Per-mode local-only
detection as routing rationale. Implements spec 009 §a-d.

Refs #41."
```

---

## Task 4: SKILL.md A2 — post-round detector + sticky convergence (spec §e–f)

Implements spec **§(e) post-round detector** (the guarantee) and **§(f) sticky embedded-diff**.

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (Phase A2 "Three outcomes" + "Convergence rounds")

- [ ] **Step 1: Scope the `rc == 0` outcome with the detector**

Find the first "Three outcomes" bullet:

```
  - **`rc == 0` → read the review (NL judgment).** Read **this round's `$round`** (not the cumulative `$log`, which replays earlier rounds) — a JSON event stream on the first round (read the review text from the assistant/agent-message events), plain text on `resume` rounds. Either way Claude classifies it into T1/T2/T3 or judges "no remaining problems," exactly as it handles its own subagent review. (Only `thread_id` is parsed out of the JSON; the review itself is read, not grepped.)
```

Replace it with:

```
  - **`rc == 0` → first confirm Codex actually read the tree, *then* read the review.** Read **this round's `$round`** (not the cumulative `$log`). **Post-round detector (the guarantee) — native `review` rounds only:** a native round that ran **zero `command_execution` items** never executed a local command, so it never read the tree (a sandbox false-clean). `codex exec --json` nests item kinds under `.item.type`, not top-level `.type`, so test:
    ```bash
    # set -e-safe: `jq -e` exits non-zero on no match, so branch on it (never run it bare).
    if ! jq -e 'select(.type=="item.completed") | select(.item.type=="command_execution")' "$round" >/dev/null; then
      :  # zero command_execution items ⇒ non-review (handle per below)
    fi
    ```
    Corroborate with text markers `sandbox prevented reading|repository sandbox|filesystem sandbox failed|not available in the connected GitHub repository`; treat a bare `confidence is low` as a non-review **only** alongside one of those markers. **Embedded-diff rounds are exempt** — the diff is in the prompt, so zero `command_execution` is expected and *not* a failure; judge them by reading the review (text markers only as a sanity check). On a **non-review**, retry with the embedded-diff form; if that still can't produce a real review, **degrade to Claude-only with a surfaced note** ("Codex couldn't read the target locally — proceeding Claude-only for the Codex gate") — never a silent clean. Otherwise Claude reads the review and classifies it into T1/T2/T3 or judges "no remaining problems," exactly as for its own subagent review.
```

- [ ] **Step 2a: Switch native convergence to `--json` so the detector keeps working**

The existing convergence block resumes *plain, no `--json`*, which means the post-round detector (Step 1) cannot run after round 1 — a spec §f violation. Edit the existing block. First, replace the heading sentence. Find:

```
- **Convergence rounds — resume the same session (plain, no `--json`).** Use the `thread_id` captured from the first round (the `--json` stream's `thread_id` field — not `session_id`) and resume so Codex remembers its prior comments. No `--json` here — `resume` produces readable output and there's no new id to capture (`resume`'s trailing `-` for the follow-up prompt is valid — only `review` target flags conflict with a prompt):
```

Replace with:

```
- **Convergence rounds — resume the same session, with `--json`.** Use the `thread_id` captured from the first round (the `--json` stream's `thread_id` field — not `session_id`) and resume so Codex remembers its prior comments. **Keep `--json`** so the post-round detector (above) can still run on the resume round — read the review text from the assistant/agent-message events, exactly as on the first round (`resume`'s trailing `-` for the follow-up prompt is valid — only `review` target flags conflict with a prompt):
```

Then add `--json` to the resume command. Find:

```
    | codex exec --sandbox read-only resume "$thread_id" - >"$round" 2>"$err" || rc=$?
```

Replace with:

```
    | codex exec --json --sandbox read-only resume "$thread_id" - >"$round" 2>"$err" || rc=$?
```

- [ ] **Step 2b: Add the sticky-embedded-diff convergence bullet**

Find the fenced `resume` block's **Fallbacks** paragraph (`**Fallbacks, in order:**…review.`) and insert this new bullet **immediately after** it (before "Loop Codex until clean…"):

```
- **Sticky embedded-diff convergence.** If the run is on the embedded-diff path (routed there, or moved there by the detector), keep **all** convergence rounds on it — re-embed the *complete* current target diff each round (`git show <sha>` / `git diff "$base"...HEAD`), **not** just the latest fix commit (a delta would hide regressions in earlier hunks). Resume against `thread_id` is fine only when the full current diff is embedded. Keep `--json` for `thread_id` + parsing; the structural detector does not apply to embedded-diff rounds (their guarantee is inherent — the diff is in the prompt). Any unavoidably plain-text round falls back to text markers alone.
```

- [ ] **Step 3: Verify**

Run: `sed -n '110,170p' plugins/review-loop/skills/review-loop/SKILL.md`
Expected: the `rc == 0` bullet now leads with the detector + jq predicate; the sticky-convergence bullet follows the resume block; markdown fences balanced.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): A2 post-round detector + sticky embedded-diff convergence

Zero-command_execution native review round (jq at .item.type) => non-review,
not a clean pass; embedded-diff rounds exempt. Retry embedded-diff, else
degrade to Claude-only with a note. Sticky convergence re-embeds the full
current diff. Implements spec 009 §e-f.

Refs #41."
```

---

## Task 5: SKILL.md A2 — doc fixes (spec §g)

Implements spec **§(g)**: name the local-unpushed-on-`main` case, correct the stdin example, link the reference doc.

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md`

- [ ] **Step 1: Correct the stdin note in the "Resolve the target" bullet**

Find the **entire** parenthetical inside the "Resolve the target into the working tree first." bullet (replace all of it, not just the first sentence — otherwise the old "plain-exec fallback" text is left dangling):

```
(If checkout isn't possible, **don't** pipe `gh pr diff` into `review -` — `review`'s stdin is *instructions*, not the diff, so it would still review the current checkout. Use the plain-exec fallback below with the diff embedded in the prompt: `codex exec --sandbox read-only "Review this diff for correctness, design, and risk:\n$(gh pr diff <num>)"` — or tell the author the PR can't be reviewed without checkout.)
```

Replace it with:

```
(If checkout isn't possible, **don't** pipe a diff into `review -`: both `codex exec -` and `review -` read the *prompt / instructions* from stdin, **never** a diff or review target — so it would still review the current checkout. Instead use the embedded-diff form (A2): put the diff in the prompt, e.g. `codex exec --json --sandbox read-only "Review this diff for correctness, design, and risk:\n$(gh pr diff <num>)"` — or tell the author the PR can't be reviewed without checkout.)
```

- [ ] **Step 2: Add the local-unpushed-on-`main` note + reference pointer at the end of A2**

Find the "Freeform plain-exec fallback (rare)." bullet (the last bullet of A2, beginning `- **Freeform plain-exec fallback (rare).**`). Insert these two bullets **immediately after** it:

```
- **Local, unpushed commits on `main` are a first-class case, not an edge case.** Under the docs-to-`main` convention, design-artifact reviews routinely target a freshly-committed, unpushed commit on `main`. On a `broken`/`unknown` host that is exactly where native `review` silently false-cleans (it falls back to the remote, which lacks the commit) — which is why A2 routes these to the embedded-diff form and guards every native round with the post-round detector.
- **Host fixes (optional).** If you want the native `review` path back on a host where the preflight reports `broken`, see `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/references/codex-sandbox-host-fixes.md` — a menu (bwrap-userns-restrict, legacy-landlock, …). The skill never applies these; embedded-diff already works with no host change.
```

- [ ] **Step 3: Verify**

Run: `grep -n 'codex-sandbox-host-fixes.md\|first-class case\|read the \*prompt' plugins/review-loop/skills/review-loop/SKILL.md`
Expected: matches for the reference link, the first-class-case note, and the corrected stdin wording.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "docs(review-loop): A2 names local-unpushed case, fixes stdin note, links host-fix doc

Implements spec 009 §g: '-' reads the prompt not the diff; docs-to-main
unpushed commits are first-class; pointer to references/codex-sandbox-host-fixes.md.

Refs #41."
```

---

## Task 6: SKILL.md content-regression test

A small structural guard so the load-bearing A2 anchors can't be silently deleted later. Mirrors the `tools/old-react/` validator pattern.

**Files:**
- Create: `tools/review-loop/test-skill-content.sh`

- [ ] **Step 1: Write the test**

Create `tools/review-loop/test-skill-content.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$SCRIPT_DIR/../../plugins/review-loop/skills/review-loop/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

need() { # $1=regex, $2=description
  grep -Eq "$1" "$SKILL" || fail "SKILL.md missing: $2"
  pass "$2"
}

need 'sandbox-preflight\.sh'                              "preflight script reference"
need 'Route by sandbox state'                            "sandbox-state routing rule"
need 'Embedded-diff form'                                "embedded-diff form"
need '\.item\.type==\"command_execution\"'               "detector jq predicate (nested .item.type)"
need 'Embedded-diff rounds are exempt'                   "detector exemption for embedded-diff"
need 'references/codex-sandbox-host-fixes\.md'           "host-fix reference link"

echo "All SKILL.md content checks passed."
```

Then: `chmod +x tools/review-loop/test-skill-content.sh`

- [ ] **Step 2: Run it (should pass now that Tasks 3–5 are done)**

Run: `bash tools/review-loop/test-skill-content.sh`
Expected: PASS — all 6 checks, ending `All SKILL.md content checks passed.`
If any FAIL: the corresponding Task 3–5 edit is missing or worded differently — fix the SKILL.md edit, not the test (unless an anchor was deliberately reworded, in which case update the regex).

- [ ] **Step 3: Commit**

```bash
git add tools/review-loop/test-skill-content.sh
git commit -m "test(review-loop): assert A2 sandbox-fix anchors exist in SKILL.md

Refs #41."
```

---

## Task 7: Version bump

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Bump review-loop to 0.3.0**

In `.claude-plugin/marketplace.json`, find the `review-loop` block and change its version. Replace:

```
      "description": "Assisted multi-reviewer review loop — local Claude + Codex gate first, then GitHub Copilot for PRs; never merges autonomously",
      "version": "0.2.0"
```

with:

```
      "description": "Assisted multi-reviewer review loop — local Claude + Codex gate first, then GitHub Copilot for PRs; never merges autonomously",
      "version": "0.3.0"
```

- [ ] **Step 2: Verify**

Run: `jq -r '.plugins[] | select(.name=="review-loop") | .version' .claude-plugin/marketplace.json`
Expected: `0.3.0`

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "chore(review-loop): bump to 0.3.0 (codex sandbox false-clean fix)

Refs #41."
```

---

## Task 8: Full test-suite gate

- [ ] **Step 1: Run both test scripts**

Run:
```bash
bash tools/review-loop/test-sandbox-preflight.sh && bash tools/review-loop/test-skill-content.sh
```
Expected: both end with their "All … passed." lines, overall exit 0.

- [ ] **Step 2: Confirm no scratch/temp artifacts staged**

Run: `git status --short && git diff --cached --check`
Expected: clean tree (everything committed), and `--check` reports no conflict markers/whitespace errors.

---

## Task 9: End-to-end verification on this host (manual)

Confirms the whole chain against the real bug, per spec **Testing → End-to-end**. This host has `features.use_legacy_landlock=true`, so native review *bypasses* bwrap and works — disable it for the run to reproduce the original failure.

- [ ] **Step 1: Preflight reports broken**

Run: `plugins/review-loop/skills/review-loop/scripts/sandbox-preflight.sh; echo "exit=$?"`
Expected: `broken` / `exit=1` (bwrap can't build a namespace here regardless of the legacy-landlock setting).

- [ ] **Step 2: Reproduce the native false-clean with legacy-landlock disabled**

```bash
tmp=$(mktemp -d); git -C "$tmp" init -q; cd "$tmp"
printf 'def withdraw(b,a):\n    return b - a  # no balance check\n' > bank.py
git add bank.py && git commit -q -m "planted bug: unchecked withdrawal"
sha=$(git rev-parse HEAD)
codex exec --json --sandbox read-only -c features.use_legacy_landlock=false review --commit "$sha" 2>/dev/null \
  | jq -rc 'select(.type=="item.completed") | .item.type' | sort | uniq -c
cd - >/dev/null
```
Expected: **zero `command_execution` items** (only GitHub `mcp_tool_call` / `agent_message`) — i.e. the structural detector (Task 4) would correctly classify this native round as a **non-review**, not a clean pass.

- [ ] **Step 2b (optional): empirical detector check on the captured stream**

If you saved the stream to a file `$round`, run:
`jq -e 'select(.type=="item.completed") | select(.item.type=="command_execution")' "$round" >/dev/null; echo "exit=$? (non-zero ⇒ non-review)"`
Expected: non-zero exit (no `command_execution`) ⇒ non-review.

- [ ] **Step 3: Embedded-diff finds the planted bug (the fallback the skill uses)**

```bash
cd "$tmp"
printf '%s\n\n%s\n' "Review this diff for correctness and risk. List concrete defects:" "$(git show HEAD)" \
  | codex exec --json --sandbox read-only -c features.use_legacy_landlock=false - 2>/dev/null \
  | jq -r 'select(.type=="item.completed") | .item | select(.type=="agent_message") | .text' | tail -20
cd - >/dev/null
```
Expected: a real review naming the unchecked-withdrawal (and/or missing-balance) defect — proving the embedded-diff path produces a genuine review where native false-cleaned.

- [ ] **Step 4: Regression — a genuine native review must NOT be flagged a non-review**

With legacy-landlock **active** (this host's default — omit the `-c` flag), native `review` reads the tree via Landlock, so a clean/real review still emits `command_execution` items and the detector must not misfire:

```bash
cd "$tmp"
codex exec --json --sandbox read-only review --commit "$sha" 2>/dev/null \
  | jq -rc 'select(.type=="item.completed") | .item.type' | sort | uniq -c
cd - >/dev/null; rm -rf "$tmp"
```
Expected: a **non-zero `command_execution` count** (Codex read the tree via Landlock) — so the structural detector (Task 4) sees the tree was read and correctly treats the review as a real review, not a non-review. (This is the spec's regression case: usable / legacy-landlock-works host.)

- [ ] **Step 5: Record the result**

Note the outcomes of Steps 1–4 in the PR description (Task 10). No commit.

---

## Task 10: Open the PR

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/review-loop-codex-sandbox-fix
```

- [ ] **Step 2: Open a PR linking issue #41**

```bash
gh pr create --base main --head feat/review-loop-codex-sandbox-fix \
  --title "review-loop: fix Codex gate false-clean on local unpushed commits" \
  --body "$(cat <<'EOF'
Implements spec 009 (docs/superpowers/specs/009-review-loop-codex-sandbox-fix-design.md).

Closes #41.

## What
- New `sandbox-preflight.sh` probe (usable/broken/unknown) — routing hint.
- SKILL.md A2: route by sandbox state (usable → native review; broken/unknown →
  embedded-diff with the diff in the prompt); post-round structural detector
  (zero `command_execution` native round ⇒ non-review, not a clean pass; jq at
  `.item.type`); embedded-diff rounds exempt; sticky embedded-diff convergence;
  doc fixes (local-unpushed-on-main first-class, stdin `-` = prompt not diff).
- New `references/codex-sandbox-host-fixes.md` host-fix menu (skill never applies).
- Tests under `tools/review-loop/` (stubbed-bwrap unit test + SKILL content guard).
- review-loop 0.2.0 → 0.3.0.

## Verified (this host, Ubuntu 24.04, codex 0.139.0)
- preflight → `broken`.
- native `review --commit <unpushed>` (legacy-landlock disabled) → zero
  `command_execution` ⇒ detector classifies non-review.
- embedded-diff → real review, planted bug found.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Run the review-loop on the PR (optional but recommended)**

Per the project workflow, run `/review-loop <PR#>` to add the Copilot gate before merge. Never merge autonomously — the author decides.

---

## Self-Review (completed by plan author)

- **Spec coverage:** Component 1 → Task 1; Component 2 §a–d → Task 3; §e–f → Task 4; §g → Task 5; Component 3 → Task 2; Testing (unit) → Tasks 1 & 6; Testing (E2E reproduction) → Task 9 Steps 1–3; Testing (regression, usable / legacy-landlock-works host) → Task 9 Step 4; version bump → Task 7. All spec sections mapped. (Note: the *regression* — detector not misfiring on a genuine review — is behavioral and covered by Task 9 Step 4 + the `usable` branch of the Task 1 unit test, not by a standalone unit test.)
- **Placeholder scan:** no TBD/TODO; every code/edit step shows full content and exact anchors.
- **Name consistency:** `sandbox-preflight.sh`, statuses `usable`/`broken`/`unknown`, the jq predicate `.item.type=="command_execution"`, `$sandbox`/`$round`/`$err`/`$thread_id`, and `references/codex-sandbox-host-fixes.md` are used identically across script, SKILL edits, tests, and PR body.
- **Branch discipline:** all work on `feat/review-loop-codex-sandbox-fix` (implementation, not main).
