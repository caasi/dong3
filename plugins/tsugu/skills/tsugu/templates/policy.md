tsugu-schema: 8
## Private Git Space (agent may do freely)
create/commit (push per `## Push`) `prepare/*` branches; worktrees; write `.tsugu/*`;
run tests; try reversible patches; dispatch own (built-in) review subagents
## Public Coordination (ask first)
open MR/PR; tracker comment / status change; assign reviewers; Slack;
public commitments; move findings into human-facing docs; irreversible cleanup
## Branch Prefixes
prepare/*
<!-- work prefixes (the queue). Must be DISJOINT from Accepted Prefixes — init
     and migration validate this. -->
## Push
push-prepare-branches: no
<!-- prepare is LOCAL-FIRST by default (no): work stays on local prepare/*
     branches — prepare commits locally and does not push. Set yes for the
     CROSS-MACHINE OPT-IN: pushing makes the branch a message that a second
     machine's agent can inherit (cross-machine handoff reads remote refs), and restores
     the remote backup of in-flight work. Tradeoff: local-first means no remote
     backup until the human pushes (an accepted trade on a single provisioned
     machine; the opt-in restores the backup for anyone who wants it). -->
## Freshness
rebase-prepare-onto-default: yes
<!-- Should an UNATTENDED `prepare` rebase in-progress work branches onto the current
     default, to keep the whole queue mergeable while you're away? `yes` = rebase every
     run (history rewrite; force-with-lease on pushed branches); `no` = pre-013 behavior,
     no rebase. Absent reads as `no` (fail-safe). Converge's human-present refresh offer is
     independent of this flag. Costs of `yes`: churn, and a narrative conflict you
     must resolve yourself on long-idle branches (see specs 013 and 022). -->
## Accepted Prefixes
feature/*  bugfix/*  chore/*
<!-- human-workflow branches the handoff RENAMES prepare/<slug> into —
     <accepted-prefix>/<slug> — for PRs
     (converge renames, never cuts). A branch here with the same slug as a work
     branch = that work is taken over (a handoff the human owns; converge
     surfaces it as awaiting-merge). -->
## Public branch
public-branch-tsugu: include
<!-- include (default): the work branch's prep commit DAG plus its context.md
     narrative and evidence/ land on the public/default branch as committed
     work-in-progress.
     exclude: keep .tsugu/ off the default branch — accept is the same handoff
     rename, and the human strips .tsugu/ when opening the public PR (converge no
     longer cuts a by-path public branch). Either way the disposal of evidence/ at
     landing is the same: what is still needed moves to CLAUDE.md / AGENTS.md, docs/
     or the test suite, and the rest is deleted. -->
## Merge method
Prefer merge commits — settlement depends on containment-preserved history.
Non-containment landings (squash / rebase / force-push) are an advanced path — see
the tsugu skill's advanced reference (`${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/advanced.md`;
this committed file does not ship that reference).
Disable the forge's auto-delete-head-branch for the slug-paired **accepted
branch** (not `prepare/*`) so the slug pairing survives the merge — settlement
reads off the accepted branch's containment in both `include` and `exclude` mode,
and where the landing rewrites history (or an `exclude`-mode human strips `.tsugu/`
into a fresh branch before merging) the accepted ref must survive to be confirmed
at `prune`.
## Housekeeping
<!-- stale-after: 30 days -->
<!-- commented default — converge records the threshold here progressively on
     first use (ask once). Consumed by `prune` (surfaces stale in-progress
     branches read-only, never deletes them) + converge's stale candidate flag;
     a scheduled prepare never cleans. -->
## Remote
remote: origin                   # authoritative remote for fetch + branch enumeration (multi-remote safety)
default-branch:                  # optional; if blank, resolved from <remote>/HEAD
## Skill use
Tsugu invokes no user-installed skill by default; it uses native git + its own
built-in capabilities. Humans trigger workflow skills (planning, review-loop, …)
by keyword.
## Recursion
Recurse into submodules / child repos only when relevant to the current goal /
branch.
