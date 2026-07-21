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
2. There is no `agent_type` field to read even if the design wanted one. Any
   plan step that gates on `agent_type` rests on a field the harness does not
   send. Remove that step.
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

**Status: deferred.** This question is testable only when `hooks.json` reaches
the marketplace-installed version of the plugin. The worktree copy is not the
installed copy, so a local edit does not prove the load path. Resolve this when
the plugin is next published or when a local marketplace install of the branch
is available. Until then, follow the Claude Code plugin documentation: declare
the hook file in `plugin.json` if the docs require it, and verify the hook
fires from the installed plugin before closing the task.

## Cleanup

The temporary `UserPromptSubmit` diagnostic hook and its script are removed
after this investigation. The prior `~/.claude/settings.json` is restored from
`~/.claude/settings.json.016bak`.
