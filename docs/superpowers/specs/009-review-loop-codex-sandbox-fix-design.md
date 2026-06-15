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
| **Upfront routing** | A `usable` sandbox uses native `review`; a `broken`/`unknown` sandbox uses the embedded-diff form as the primary Codex call | SKILL.md A2 |
| **Post-round detector** | The *guarantee* on the native `review` path: after a round, confirm Codex actually read the tree; if not, it's a non-review | SKILL.md A2 |

**Key invariant:** the preflight is only a hint. The **post-round structural detector** is the safety guarantee on the native path — it directly observes whether Codex ran any local command, so it catches a false-clean even if a `usable` probe is wrong and native Codex still fails to read the tree. **Embedded-diff** is always a safe landing because it places the diff *inside the prompt*, so no sandboxed subprocess is needed at all — which is also why a probe that wrongly reports `broken` on a host where Codex actually works via `use_legacy_landlock` is harmless (embedded-diff still produces a real review).

## Component 1 — `scripts/sandbox-preflight.sh`

A new executable helper alongside `copilot.sh` / `pr-comments.sh`, invoked via `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/sandbox-preflight.sh`.

**Sole job:** run one cheap probe of whether Codex's local command sandbox can build here, in the exact shape Codex uses (userns + net namespace):

```bash
bwrap --ro-bind / / --unshare-user --unshare-net --dev /dev true
```

(`--unshare-user --unshare-net` matches the namespaces Codex's own `bwrap` invocation creates, per the `strace` capture in issue #41 — `--unshare-user` is included explicitly rather than relying on non-setuid bwrap implying it.)

**Contract:**

| stdout | exit | Meaning | SKILL routing |
|--------|------|---------|---------------|
| `usable` | 0 | Probe built the sandbox | native `review` path OK |
| `broken` | 1 | Probe failed at bwrap's userns/loopback setup with an `EPERM` — match the **union** `Operation not permitted\|Permission denied` in a bwrap setup line. Observed variants (which differ even between runs on the same host): `loopback: Failed RTM_NEWADDR: Operation not permitted`, `loopback: Failed to create NETLINK_ROUTE socket: Operation not permitted`, `setting up uid map: Permission denied`. (Do **not** match `write failed /proc/self/uid_map` — that is an `unshare` diagnostic, not this bwrap probe.) | route to embedded-diff |
| `unknown` | 2 | `bwrap` not on `PATH`, or a non-EPERM failure — can't conclude | route conservatively (treat like `broken` for routing; the post-round detector still guards) |

**Conventions:** `set -euo pipefail`, full-length options, self-contained (resolve `bwrap` from `PATH`). The probe's own stderr is captured, not leaked.

**Documented caveat (in-script comment + reference doc):** if the user has set `features.use_legacy_landlock=true`, Codex uses the Landlock LSM and never calls `bwrap`, so this probe may report `broken` while native `review` actually works. That is **harmless** — the skill routes to embedded-diff, which still produces a real review. The probe is a hint, never a gate.

## Component 2 — SKILL.md Phase A2 changes

### (a) Preflight once at loop start
Next to the existing log setup, call `sandbox-preflight.sh` and record the result (`usable` / `broken` / `unknown`) for the run.

### (b) Target reachability check (issue proposal #2)
A broken sandbox is *silently* dangerous only when the target is **local-only** (on no remote the Codex connector can read) — that's when Codex's remote fallback reviews nothing yet reports clean. A *pushed* target survives the fallback (the remote has it); a *usable* sandbox never falls back at all. Detect local-only per mode:

- **`--commit <sha>` / single commit:** `git branch -r --contains <sha>` with empty stdout ⇒ local-only.
- **`--base <base>`:** local-only if any commit in `<base>..HEAD` is unreachable (`git branch -r --contains` empty for it); in practice an unpushed `HEAD` ⇒ treat the whole target as local-only.
- **`--uncommitted`:** inherently local-only (working-tree changes exist on no remote).

This is a **heuristic, not proof**: remote-tracking refs can be stale — a `git fetch` may be needed for fresh refs, and a force-push can drop a commit that still shows as contained. Its job is to (1) flag *when* a broken sandbox would false-clean and (2) sharpen the post-round detector (§e) — a non-review on a local-only target is unambiguously a false clean. It does **not** by itself force embedded-diff when the sandbox is `usable`.

### (c) Routing rule
The trigger is **sandbox state**, not the target:

- sandbox `usable` ⇒ native `review --base/--commit/--uncommitted` — it reads the local tree directly, so it is correct for pushed *and* unpushed targets alike (no remote fallback happens).
- sandbox `broken`/`unknown` ⇒ **embedded-diff form** — native would fall back to the remote, which for a local-only target silently false-cleans; embedding the diff sidesteps the sandbox entirely, so it is the safe form for every target on a broken host.

This still avoids the wasted false-clean round on the common docs-to-main case: a broken host routes straight to embedded-diff. The local-only check (§b) does **not** override a `usable` sandbox — it feeds the §e detector, which catches the rare case where a `usable` probe is wrong.

### (d) Embedded-diff form
Place the diff **into the prompt**, matching the skill's existing `$(gh pr diff <num>)` fallback pattern — no sandboxed subprocess is needed to read the tree, so the failure cannot occur:

```bash
codex exec --json --sandbox read-only \
  "Review this diff for correctness, design, and risk. List concrete defects:
$(git show "$sha")"
```

`--base` targets embed `$(git diff "$base"...HEAD)`. `--uncommitted` must embed the **complete** working-tree snapshot — staged, unstaged, **and** untracked — because plain `git diff` shows only unstaged tracked changes whereas `review --uncommitted` covers all three: embed `git diff HEAD` (staged + unstaged tracked) **plus the untracked files' contents rendered as diffs** — `git ls-files --others --exclude-standard -z | xargs -0 -I{} git diff --no-index /dev/null {}` (a bare filename list carries no contents, so it is not enough). Since `--uncommitted` only reaches embedded-diff on a **broken** sandbox (§c), this recipe is the broken-host fallback; on a `usable` sandbox native `review --uncommitted` covers all three directly. `--json` is kept so the first embedded-diff round still captures `thread_id` for resume.

**Large-diff / ARG_MAX note:** for very large diffs, feed the *prompt* via stdin instead — `printf '%s\n%s' "<instructions>" "$(git show "$sha")" | codex exec --json --sandbox read-only -`, where trailing `-` reads the **entire prompt** from stdin. Do **not** also pass a `[PROMPT]` argument alongside `-` — stdin replaces it. (Distinct behavior worth noting: plain `codex exec "<instructions>"` with piped stdin appends the pipe as a `<stdin>` block, so `git show | codex exec "<instructions>"` also validly puts the diff in context — but `review -` treats piped data as *instructions only*, never as a diff/target.) The diff still travels in the prompt; only the delivery channel changes.

### (e) Post-round detector — the guarantee
This detector guards the **native `review` path**, where reading the tree *requires* a local command, so a round that ran none never saw the content. **It does not apply to embedded-diff rounds:** there the diff is already in the prompt, so Codex legitimately runs **zero** `command_execution` items — applying the structural test there would wrongly degrade a perfectly good review. Judge embedded-diff rounds by reading the review, using only the text-marker check below as a cheap sanity check.

Before counting a **native-`review`** round clean, confirm Codex actually read the tree. Every inspected round runs with `--json` (see §f). The `codex exec --json` stream is JSONL whose item kinds are nested under `.item.type` (e.g. `command_execution`, `mcp_tool_call`, `agent_message`) — **not** top-level `.type` (only `thread.started` / `turn.*` / `item.completed` appear there). Treat a native-`review` round as a **non-review (not a clean pass)** if **either**:

- **Structural (primary):** the round ran **zero `command_execution` items** — Codex never executed a local command, so it never read the tree. Exact predicate:
  ```bash
  jq -e 'select(.type=="item.completed") | select(.item.type=="command_execution")' "$round" >/dev/null
  ```
  Zero matches (non-zero exit) ⇒ non-review. Do **not** condition on a positive "only GitHub MCP tools" match: a genuine review also emits `agent_message` / `reasoning` items, and the exact connector tool names are version-dependent. **Absence of `command_execution` is the robust signal**; any `github_*` `mcp_tool_call` names (`github_search_commits`, `github_list_repositories`, …) are illustrative only, not part of the predicate.
- **Text (corroborating):** the review text shows a sandbox / remote-fallback access marker — `sandbox prevented reading|repository sandbox|filesystem sandbox failed|not available in the connected GitHub repository`. Treat a bare `confidence is low` as a non-review **only in combination** with one of those access markers — a valid review can be low-confidence for unrelated reasons.

On a non-review: **retry with the embedded-diff form.** If embedded-diff still cannot produce a real review, **degrade to Claude-only with a surfaced note** (e.g. "Codex couldn't read the target locally — proceeding Claude-only for the Codex gate"). **Never a silent clean.**

This is consistent with the existing three-outcome model: a sandbox-failure `rc=0` is reclassified out of "outcome 1 (read the review)" into the degrade-with-note path, rather than being trusted.

### (f) Sticky embedded-diff
Once a run is on the embedded-diff path (by routing or by detector), **all** convergence rounds for that run stay on it. Two rules keep convergence safe:

- **Re-embed the complete current target each round** — embed the *full* corrected diff for the target (`git show <sha>` for a commit target; `git diff "$base"...HEAD` for a base target), **not** just the latest fix commit. A delta-only `git show <newsha>` would hide regressions or unaddressed findings in earlier hunks. Resume against the captured `thread_id` is permitted only when the full current diff is embedded in the follow-up prompt.
- **Keep `--json` on every round** — for `thread_id` capture and uniform parsing. Note (per §e) the structural detector does **not** apply to embedded-diff rounds: their guarantee is *inherent* (the diff is in the prompt, so there is no sandbox to fail), and a valid embedded-diff review legitimately runs zero `command_execution` items. The structural detector is for the **native** path; its plain-text `resume` convergence form must likewise be run with `--json` to stay inspectable, and any unavoidably plain-text round falls back to the text-marker check alone.

On the embedded-diff path this guarantees the sandbox failure cannot reappear mid-loop.

### (g) Documentation fixes (issue proposals #3, #4)
- **Name the case.** A short A2 subsection states that **local, unpushed commits on `main`** are the *default* for design-artifact reviews under the docs-to-main convention — a first-class scenario, not an edge case.
- **Correct the stdin example.** Clarify that `codex exec -` and `review -` read the **prompt / instructions** from stdin, **not** the diff. To feed Codex a diff, **embed it in the prompt** (per (d)). Remove any implication that piping a diff into `review -` reviews that diff.
- **One-line pointer** from A2 to the host-fix reference doc (Component 3).

## Component 3 — `references/codex-sandbox-host-fixes.md`

A pick-your-own menu of optional host-level fixes (the skill never applies these), distilled from issue #41's survey. Each entry lists: what it changes · sudo & scope · trade-off / residual risk · verify command · when to prefer.

1. **`bwrap-userns-restrict`** (Ubuntu `apparmor-profiles`; default in 25.04, backportable to 24.04) — restores bwrap's userns under an AppArmor profile **and** blocks a sandboxed child from creating *further* namespaces (closes the nested-escape gap). Needs sudo; affects all bwrap callers. **Recommended durable default** when a native `review` path is wanted.
2. **`features.use_legacy_landlock=true`** (`~/.codex/config.toml` or `-c`) — no sudo, scoped to codex, uses the already-active Landlock LSM, read-only sandbox preserved. Works today, but recent `codex` marks it **deprecated** — treat it as a **temporary compatibility workaround**, not a long-term default; if it is removed, fall back to #1 or the skill-side embedded-diff path.
3. **Hand-rolled `/etc/apparmor.d/bwrap` `flags=(unconfined) { userns }`** — works, but is the **least strict** variant (sandboxed children also get userns — the nested-escape hole that `bwrap-userns-restrict` closes). Documented as **inferior to `bwrap-userns-restrict`**; included for completeness.
4. **`sysctl kernel.apparmor_restrict_unprivileged_userns=0`** — global, last-resort; **drops the hardening for the whole system**. Not recommended.
5. **Skill-side embedded-diff** — no host change at all. This is what the skill now does automatically (Component 2); listed so the user knows the zero-config option exists.

Verification commands per entry mirror issue #41's verified table (`bwrap … --unshare-net … echo OK`, `sysctl …`, a `codex … review --commit <unpushed-sha>` real-review check).

## Testing & verification

**Script unit tests (TDD):** stub `bwrap` on `PATH` to force each outcome and assert `sandbox-preflight.sh` emits the right word + exit code:
- stub exits 0 ⇒ `usable` / 0;
- stub exits non-zero with a userns/loopback EPERM on stderr ⇒ `broken` / 1;
- `bwrap` absent (or non-EPERM failure) ⇒ `unknown` / 2.

Tests live under repo-level `tools/review-loop/` (dev tooling stays out of the install boundary `plugins/review-loop/`).

**End-to-end (this machine — Ubuntu 24.04.4, kernel 6.8, where bwrap fails to build):**

> Note: this machine has `features.use_legacy_landlock=true` in `~/.codex/config.toml`, so native `review` currently **bypasses bwrap and works** here. To reproduce the original bwrap false-clean, the E2E run must disable that feature — pass `-c features.use_legacy_landlock=false`, or point `CODEX_HOME` at an isolated config that omits it.

1. `sandbox-preflight.sh` reports `broken` (the bwrap probe fails regardless of the legacy-landlock setting).
2. With legacy-landlock disabled, a throwaway repo with an **unpushed** commit containing a planted bug: native `review --commit` is correctly detected as a non-review by the post-round detector (not counted clean), and the embedded-diff form finds the bug (real review).

**Regression:**
- On a host where the probe reports `usable`, the native `review` path runs and the structural detector does **not** misfire on a genuinely clean review — a clean review still emits `command_execution` items, so the detector sees the tree was read.
- On a host where the probe reports `broken` but Codex actually works via `use_legacy_landlock`, §c routes to embedded-diff, which still produces a real review (the documented harmless false-negative). No native round runs, so the structural detector does not apply — and that is correct, not a miss.

## Acceptance criteria

- [ ] A review-loop run whose target is a **local unpushed commit on `main`** produces a real Codex review **or** cleanly degrades to Claude-only with a surfaced note — never a silent false clean. (Issue #41 acceptance.)
- [ ] `sandbox-preflight.sh` returns the documented word/exit for `usable` / `broken` / `unknown`, verified by stubbed-`bwrap` unit tests.
- [ ] The post-round structural detector reclassifies a round with **zero `command_execution` items** (matched at `.item.type`, not top-level `.type`) as a non-review, regardless of MCP/GitHub tool activity.
- [ ] SKILL.md documents the local-unpushed-on-`main` case and the corrected stdin semantics (`-` = prompt, not diff).
- [ ] `references/codex-sandbox-host-fixes.md` lists the five options with trade-offs and verify commands; A2 links it.
- [ ] `review-loop` version bumped to 0.3.0 in `.claude-plugin/marketplace.json`.
