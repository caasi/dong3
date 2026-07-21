# Spec 016 — Harness Findings (Task 1)

This file records the two blocking pre-code verifications from the spec 016
implementation plan. Task 1 must answer them before `object.sh` (the
`UserPromptSubmit` hook) is written, because the hook design depends on what
the harness delivers.

## Q1 — Does `UserPromptSubmit` fire in a subagent, and is `agent_type` present?

**Method.** A temporary `UserPromptSubmit` hook appended the raw hook payload
(stdin JSON) to one file. The hook used an absolute output path, so a subagent
with any working directory writes to the same file. The observation had two
parts: (a) read the payload from a real main-session prompt; (b) dispatch a
throwaway Task subagent, then check the same file for a new line.

**Result — main session.** The hook fired on the human prompt. The payload
carried these fields and no others:

```
session_id, transcript_path, cwd, prompt_id, permission_mode,
hook_event_name, prompt
```

There is no `agent_type` field. The `prompt` field is present and holds the
raw prompt text.

**Result — subagent.** The dispatched subagent completed and returned its
value. The dump file gained no new line. A search for a stray `hookdump*.jsonl`
under the repo, the worktree, and the scratch tree found only the one canonical
file. Because the hook writes to an absolute path, a different subagent working
directory cannot explain the absence. Therefore a Task subagent dispatch does
not fire `UserPromptSubmit` at all.

**Conclusion.** The `UserPromptSubmit` hook fires only for real prompts to the
main session. It never fires from subagent activity (reviewers, implementers,
or any other dispatched agent).

**Design consequences for `object.sh`.**

1. The hook does not need an `agent_type` gate to avoid double-counting from
   subagents. Subagents never trigger the event, so there is nothing to
   exclude.
2. There is no `agent_type` field in the payload today, so the hook's
   `agent_type` gate (rule 1 in `object.sh`, `[ -n "$agent_type" ] && exit 0`)
   is currently a no-op. The shipped hook KEEPS it deliberately, as a
   forward-compatibility, defense-in-depth guard: if a future harness both
   fires `UserPromptSubmit` inside subagents and adds an `agent_type` field,
   the gate suppresses those subagent prompts. It costs nothing while the field
   is absent, and objection detection does not depend on it. So the gate is
   retained, not removed — the earlier draft that said "remove that step" was
   wrong about the shipped behavior.
3. Objection detection must use the prompt text. The hook reads the `prompt`
   field and matches the objection markers (`#redo`, `#again`, `#fix`). It has
   no other signal to separate an objection from an ordinary prompt.

**Scope of the evidence.** This is a single-observation result on this host and
this Claude Code version. It is strong for the main-session payload (the field
list is exact) and for the subagent no-fire result (absolute path rules out the
main false-negative cause). If a future harness version starts to fire
`UserPromptSubmit` inside subagents, the objection log would gain entries from
reviewer prompts. A cheap guard against that regression: the hook can ignore
any prompt that does not contain an objection marker, which it already must do.

## Q2 — Does `plugin.json` need a `hooks` key for `hooks.json` to load?

**Answer: no. Hooks load by auto-discovery.** A plugin's `hooks/hooks.json`
at the default `hooks/` location loads when the plugin is enabled. The plugin
manifest (`.claude-plugin/plugin.json`) does not need a `hooks` key.

**Evidence — official documentation.** The Claude Code plugin docs state the
manifest is optional when components use default locations, and `hooks/` is a
default location (https://code.claude.com/docs/en/plugins.md, plugin structure).

**Evidence — a working official plugin.** The installed `superpowers` plugin
(`.../claude-plugins-official/superpowers/6.1.1/`) ships `hooks/hooks.json`
and its `.claude-plugin/plugin.json` has no `hooks` key at all. It declares
only `skills` as an explicit component path; commands and hooks are
auto-discovered. This proves that a manifest can declare some components
explicitly and still auto-discover hooks — which is exactly the review-loop
manifest's situation (it declares `skills` and `commands`, not `hooks`).

**Consequence for Task 7.** Write `hooks/hooks.json` and change nothing in
`plugin.json`. The `hooks.json` shape follows the same official plugin:
`{"hooks": {"<Event>": [ { "hooks": [ { "type": "command", "command": "...",
"timeout": <seconds> } ] } ] }}`. `UserPromptSubmit` carries no `matcher`
(matchers filter tool events, not lifecycle events). The `command` value
quotes `${CLAUDE_PLUGIN_ROOT}` so an install path with a space still works,
matching the official `hooks.json`.

**Still to verify at runtime.** Auto-discovery is confirmed by docs and by a
working plugin, but the review-loop hook itself was not yet observed firing
from an installed build (the worktree is not an installed plugin). When the
branch is published or installed locally, do the one runtime check from the
plan's Task 7 Step 3: enable the plugin, send a prompt with `#fix` in an
opted-in repo, and confirm one `object` line appears.

## Cleanup

The temporary `UserPromptSubmit` diagnostic hook and its script are removed
after this investigation. The prior `~/.claude/settings.json` is restored from
`~/.claude/settings.json.016bak`.
