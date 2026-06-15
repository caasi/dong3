# 009 — review-loop: Codex gate false-clean hardening (sandbox / unpushed-target)

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [002 review-loop plugin design](002-review-loop-plugin-design.md), [003 review-loop headless Codex design](003-review-loop-headless-codex-design.md)
**Source issue:** [#41](https://github.com/caasi/dong3/issues/41)
**Target version:** `review-loop` 0.2.0 → 0.3.0 (new script + behavior change)

## Problem

In Phase A2 (the local Codex gate), `review-loop` runs `codex exec review --commit <sha>` / `--base <base>` / `--uncommitted`. The `review` subcommand asks Codex to **execute** sandboxed shell commands (`git show`, `git status`) to read the diff. On Linux those commands run inside **bubblewrap** (`bwrap`), which must build an unprivileged user namespace.

On Ubuntu 23.10+/24.04 the default `kernel.apparmor_restrict_unprivileged_userns=1` transitions unconfined userns-creating processes into a cap-stripping AppArmor stub, so `bwrap` cannot configure loopback / write `uid_map` and exits non-zero **before** the `git` command runs. Codex then silently **falls back to the connected GitHub repository**. When the target is a **local, unpushed commit** — the default case for a **design artifact committed directly to `main`** under the docs-to-main convention — the remote can't see it: empty diff → `rc=0` → **false clean pass**.

```
rc=0
"No findings identified. Confidence is low because the local filesystem sandbox
 failed, and commit c183727 is not available in the connected GitHub repository."
```

The loop treats this as "outcome 1 → read the review" (clean Codex gate) when in fact Codex **never saw the content**. This is silently wrong: an unreviewed target is counted as reviewed.

Root cause was reproduced and pinned via `strace` on Ubuntu 24.04.4 / kernel 6.8 / `codex-cli 0.139.0` (issue #41 comments). It is **not** a git, remote, or file-permission problem — Codex *can* read the tree as the user when the sandbox is bypassed. The trigger is purely: a sandboxed subprocess that cannot be built.

## Goals

1. **A broken sandbox must never read as a clean gate.** A `rc=0` round in which Codex never read the local tree is a **non-review**, not a clean pass.
2. **The common case works by default.** A local unpushed commit on `main` (design-artifact-to-main) produces a **real** Codex review, or cleanly degrades to Claude-only **with a surfaced note** — never a silent false clean. (Issue acceptance criterion.)
3. **Platform-independent in the skill.** The skill's correctness must not depend on any host configuration; host fixes are offered as an optional menu the user picks from.
4. **Stay light.** Keep the existing "light / few scripts" character of the plugin — one narrow new script, the rest is SKILL.md narrative.

## Non-goals

- The skill does **not** modify host configuration (no sudo, no writing AppArmor profiles, no editing `~/.codex/config.toml`). Host fixes are documented for the user to apply by choice.
- No change to the Claude subagent reviewer (A1), the Copilot phase (B), or the tier/convergence model.
- Not a general Codex-wrapper script. The new script does the **preflight probe only**.

## Design overview

Three layers, in order of authority:

| Layer | Role | Where |
|-------|------|-------|
| **Preflight probe** | Cheap *routing hint*, run once at loop start: can Codex's command sandbox build here? | new `scripts/sandbox-preflight.sh` |
| **Upfront routing** | For `broken` sandbox **or** local/unpushed targets, use the embedded-diff form as the primary Codex call | SKILL.md A2 |
| **Post-round detector** | The *guarantee*: after any `rc=0` round, confirm Codex actually read the tree; if not, it's a non-review | SKILL.md A2 |

**Key invariant:** the preflight is only a hint. The **post-round structural detector** is the safety guarantee — it directly observes whether Codex ran any local command, so it catches a false-clean even when the preflight guessed wrong (e.g. the user configured `use_legacy_landlock`, so bwrap is never used). **Embedded-diff** is always a safe landing because it places the diff *inside the prompt*, so no sandboxed subprocess is needed at all.

## Component 1 — `scripts/sandbox-preflight.sh`

A new executable helper alongside `copilot.sh` / `pr-comments.sh`, invoked via `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/sandbox-preflight.sh`.

**Sole job:** run one cheap probe of whether Codex's local command sandbox can build here, in the exact shape Codex uses (userns + net namespace):

```bash
bwrap --ro-bind / / --unshare-net --dev /dev true
```

**Contract:**

| stdout | exit | Meaning | SKILL routing |
|--------|------|---------|---------------|
| `usable` | 0 | Probe built the sandbox | native `review` path OK |
| `broken` | 1 | Probe failed with a userns/loopback EPERM (`setting up uid map: Permission denied`, `loopback: Failed RTM_NEWADDR`, `write failed /proc/self/uid_map`) | route to embedded-diff |
| `unknown` | 2 | `bwrap` not on `PATH`, or a non-EPERM failure — can't conclude | route conservatively (treat like `broken` for routing; the post-round detector still guards) |

**Conventions:** `set -euo pipefail`, full-length options, self-contained (resolve `bwrap` from `PATH`). The probe's own stderr is captured, not leaked.

**Documented caveat (in-script comment + reference doc):** if the user has set `features.use_legacy_landlock=true`, Codex uses the Landlock LSM and never calls `bwrap`, so this probe may report `broken` while native `review` actually works. That is **harmless** — the skill routes to embedded-diff, which still produces a real review. The probe is a hint, never a gate.

## Component 2 — SKILL.md Phase A2 changes

### (a) Preflight once at loop start
Next to the existing log setup, call `sandbox-preflight.sh` and record the result (`usable` / `broken` / `unknown`) for the run.

### (b) Target reachability check (issue proposal #2)
Determine whether the target is local-only / unpushed: `git branch -r --contains <sha>` returning empty ⇒ no remote Codex could see has it.

### (c) Routing rule
- preflight `broken`/`unknown` **OR** target is local/unpushed ⇒ **embedded-diff form** is the primary Codex call;
- otherwise ⇒ the existing `review --base/--commit/--uncommitted` form (unchanged).

This avoids spending a wasted false-clean round on the common docs-to-main case.

### (d) Embedded-diff form
Place the diff **into the prompt**, matching the skill's existing `$(gh pr diff <num>)` fallback pattern — no sandboxed subprocess is needed to read the tree, so the failure cannot occur:

```bash
codex exec --json --sandbox read-only \
  "Review this diff for correctness, design, and risk. List concrete defects:
$(git show "$sha")"
```

(`--base` targets use `$(git diff "$base"...HEAD)`; `--uncommitted` uses `$(git diff)`.) `--json` is kept so the first embedded-diff round still captures `thread_id` for resume.

**Large-diff / ARG_MAX note:** for very large diffs, feed the *prompt* via stdin instead — `printf '%s\n%s' "<instructions>" "$(git show "$sha")" | codex exec --json --sandbox read-only -`, where trailing `-` reads the **prompt** from stdin. The diff still travels in the prompt; only the delivery channel changes.

### (e) Post-round detector — the guarantee
Before counting **any** `rc=0` Codex round as clean, confirm Codex actually read the tree. Treat the round as a **non-review (not a clean pass)** if **either**:

- **Structural** (from `--json`): the round ran **zero `command_execution` items** and only GitHub `mcp_tool_call`s (e.g. `github_search_commits`, `github_list_repositories`) — Codex never touched the local tree; **or**
- **Text markers:** the review text matches `sandbox prevented reading|repository sandbox|filesystem sandbox failed|not available in the connected GitHub repository|confidence is low`.

On a non-review: **retry with the embedded-diff form.** If embedded-diff still cannot produce a real review, **degrade to Claude-only with a surfaced note** (e.g. "Codex couldn't read the target locally — proceeding Claude-only for the Codex gate"). **Never a silent clean.**

This is consistent with the existing three-outcome model: a sandbox-failure `rc=0` is reclassified out of "outcome 1 (read the review)" into the degrade-with-note path, rather than being trusted.

### (f) Sticky embedded-diff
Once a run is on the embedded-diff path (by routing or by detector), **all** convergence rounds for that run stay on it — re-embed the new changes each round (`$(git show <newsha>)` / updated `git diff`) rather than `resume` against the sandboxed `review`. This guarantees the sandbox failure cannot reappear mid-loop. Resume against the captured `thread_id` is permitted as long as the new diff is embedded in the follow-up prompt.

### (g) Documentation fixes (issue proposals #3, #4)
- **Name the case.** A short A2 subsection states that **local, unpushed commits on `main`** are the *default* for design-artifact reviews under the docs-to-main convention — a first-class scenario, not an edge case.
- **Correct the stdin example.** Clarify that `codex exec -` and `review -` read the **prompt / instructions** from stdin, **not** the diff. To feed Codex a diff, **embed it in the prompt** (per (d)). Remove any implication that piping a diff into `review -` reviews that diff.
- **One-line pointer** from A2 to the host-fix reference doc (Component 3).

## Component 3 — `references/codex-sandbox-host-fixes.md`

A pick-your-own menu of optional host-level fixes (the skill never applies these), distilled from issue #41's survey. Each entry lists: what it changes · sudo & scope · trade-off / residual risk · verify command · when to prefer.

1. **`features.use_legacy_landlock=true`** (`~/.codex/config.toml` or `-c`) — no sudo, scoped to codex, uses the already-active Landlock LSM, read-only sandbox preserved. **Recommended default.** Caveat: the `legacy` name suggests OpenAI may retire it.
2. **`bwrap-userns-restrict`** (Ubuntu `apparmor-profiles`; default in 25.04, backportable to 24.04) — durable native answer; also blocks a sandboxed child from creating *further* namespaces (closes the nested-escape gap). Needs sudo; affects all bwrap callers.
3. **Hand-rolled `/etc/apparmor.d/bwrap` `flags=(unconfined) { userns }`** — works, but is the **least strict** variant (nested-escape hole). Documented as **inferior to #2**; included for completeness.
4. **`sysctl kernel.apparmor_restrict_unprivileged_userns=0`** — global, last-resort; **drops the hardening for the whole system**. Not recommended.
5. **Skill-side embedded-diff** — no host change at all. This is what the skill now does automatically (Component 2); listed so the user knows the zero-config option exists.

Verification commands per entry mirror issue #41's verified table (`bwrap … --unshare-net … echo OK`, `sysctl …`, a `codex … review --commit <unpushed-sha>` real-review check).

## Testing & verification

**Script unit tests (TDD):** stub `bwrap` on `PATH` to force each outcome and assert `sandbox-preflight.sh` emits the right word + exit code:
- stub exits 0 ⇒ `usable` / 0;
- stub exits non-zero with a userns/loopback EPERM on stderr ⇒ `broken` / 1;
- `bwrap` absent (or non-EPERM failure) ⇒ `unknown` / 2.

Tests live under repo-level `tools/review-loop/` (dev tooling stays out of the install boundary `plugins/review-loop/`).

**End-to-end (this machine — Ubuntu 24.04.4, kernel 6.8, where the bug reproduces):**
1. `sandbox-preflight.sh` reports `broken` (no host fix applied).
2. A throwaway repo with an **unpushed** commit containing a planted bug: the embedded-diff Codex review finds the bug (real review), and the native `review --commit` path is correctly detected as a non-review by the post-round detector rather than counted clean.

**Regression:** on a machine where the sandbox is `usable` (or `use_legacy_landlock` is set), the native `review` path still runs and the detector does not misfire on a genuinely clean review.

## Acceptance criteria

- [ ] A review-loop run whose target is a **local unpushed commit on `main`** produces a real Codex review **or** cleanly degrades to Claude-only with a surfaced note — never a silent false clean. (Issue #41 acceptance.)
- [ ] `sandbox-preflight.sh` returns the documented word/exit for `usable` / `broken` / `unknown`, verified by stubbed-`bwrap` unit tests.
- [ ] The post-round structural detector reclassifies a zero-`command_execution`, GitHub-tools-only `rc=0` round as a non-review.
- [ ] SKILL.md documents the local-unpushed-on-`main` case and the corrected stdin semantics (`-` = prompt, not diff).
- [ ] `references/codex-sandbox-host-fixes.md` lists the five options with trade-offs and verify commands; A2 links it.
- [ ] `review-loop` version bumped to 0.3.0 in `.claude-plugin/marketplace.json`.
