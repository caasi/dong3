# Spec 016 — Acceptance Sweep (Task 11)

Each acceptance criterion from spec 016 (lines 416–455) maps to a passing
test or a written document. Every item is met. No item is unmet.

Run the whole suite with `bash tools/review-loop/run-all.sh` → `ALL SUITES PASS`
(6 suites: test-logline, test-log-sh, test-object-sh, test-format-rules,
test-skill-content, and the pre-existing test-sandbox-preflight).

| # | Criterion (spec line) | Evidence |
|---|---|---|
| 1 | init states the hook, asks before `yes`, decline leaves roster working (416) | test-skill-content.sh anchors "init records the answer", "init discloses the hook" |
| 2 | hook reads both configs, writes only on `yes`, project overrides global, 3 states + override tested (419) | test-object-sh.sh: absent→silent, yes→writes, no→silent, project-no-overrides-global-yes, subdir-sees-project-no |
| 3 | Q1 (UserPromptSubmit in subagent, agent_type) answered in writing before code (421) | 016-harness-findings.md, Q1 section |
| 4 | hook detects markers with no model involvement (423) | object.sh uses awk/sed/grep only; test-object-sh.sh marker cases |
| 5 | neither writer exits non-zero; hook no stdout; log.sh stdout only the new-run token (424) | test-object-sh.sh "no stdout", "exit 0 on garbage"; test-log-sh.sh token-only |
| 6 | both writers refuse when the log dir is inside a git work tree (426) | test-logline.sh:60–62 "guard refuses inside work tree" |
| 7 | log file created mode 0600 (427) | test-logline.sh:50 `stat -c %a = 600` |
| 8 | concurrent appends never split a line (428) | test-logline.sh:63–66 two writers, 1000 lines each, 2000 whole lines |
| 9 | one `review` line per round from §A3, per-reviewer counts, model ids percent-encoded (429) | SKILL.md §A3 anchor "A3 logs review lines"; test-log-sh.sh review line; test-format-rules.sh id `%2F` end to end |
| 10 | every line carries `project`, both writers derive it identically, linked worktree yields main slug (431) | test-logline.sh:20–21 "worktree yields main checkout"; both writers source logline.sh |
| 11 | hook and log.sh both source logline.sh (433) | object.sh sources `../skills/review-loop/scripts/logline.sh`; log.sh sources `./logline.sh` |
| 12 | off switch stops both writers (435) | test-logline.sh:51–52 `REVIEW_LOOP_LOG=0` "off switch" |
| 13 | omission check documented with user-role and fence filters, not a bare grep (436) | spec 016 lines 311–313: extract from user-role content only, same fence and code-span rule as the hook. Manual offline procedure, named not shipped. |
| 14 | §A3 gains the round-logging instruction; init.md gains disclosure + recorded answer (437) | Task 8; test-skill-content.sh anchors |
| 15 | both edits gain anchors; harness grows 1→5 files with jq assertions (439) | Task 10; test-skill-content.sh all 60 PASS |
| 16 | hooks/hooks.json declares the hook command and 5-second timeout (445) | Task 7; `jq` shape check, timeout 5 |
| 17 | Q2 (plugin.json hooks key) answered in writing before code (447) | 016-harness-findings.md, Q2 section (resolved: no key needed) |
| 18 | review-loop is 0.7.0 in the plugins array, not the metadata header (450) | test-skill-content.sh jq "version 0.7.0" |
| 19 | marketplace + plugin descriptions both disclose the hook, README too, byte-identical per spec 014 (452) | Task 8; test-skill-content.sh "descriptions identical" + disclosure anchors |
| 20 | all tests above pass (455) | run-all.sh → ALL SUITES PASS |

## Remaining manual checks — named, not silently dropped

- **Hook-merge runtime check (plan Task 7 Step 3).** Not an acceptance-list
  item — §445 requires only that `hooks.json` declares the command and
  timeout, which is done. Auto-discovery is confirmed by docs and by the
  official superpowers plugin (016-harness-findings.md Q2). The one runtime
  observation — enable the plugin, send `#fix` in an opted-in repo, see one
  `object` line — still needs an installed or published build. Do it at
  publish time.
- **Omission-rate procedure (item 13).** An offline analysis over transcripts,
  documented in the spec, not a shipped writer. It has no automated test by
  design.
