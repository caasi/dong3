tsugu-schema: 3
## Private Git Space (agent may do freely)
create/commit (push per `## Push`) `prepare/*` / `investigate/*` / `review/*` branches; worktrees; write `.tsugu/*`;
run tests; try reversible patches; dispatch own (built-in) review subagents
## Public Coordination (ask first)
open MR/PR; tracker comment / status change; assign reviewers; Slack;
public commitments; move findings into human-facing docs; irreversible cleanup
## Branch Prefixes
prepare/*  investigate/*  review/*
<!-- work prefixes (the queue). Must be DISJOINT from Handoff Prefixes — init
     and migration validate this. -->
## Push
push-prepare-branches: yes
<!-- init's default answer to "may agents create/commit/push preparation
     branches automatically?". Pushing makes the branch a message (cross-
     machine handoff reads remote refs). Set no to keep work local —
     prepare then commits locally and stops for approval. -->
## Handoff Prefixes
feat/*  fix/*
<!-- human-workflow branches converge cuts for PRs. A branch here with the
     same slug as a work branch = that work is decided, awaiting merge. -->
## Public branch
public-branch-tsugu: include
<!-- include (default): the work branch's prep commit DAG plus its context.md
     narrative land on the public/default branch as committed WIP knowledge.
     knowledge/ lands on the coordination ref regardless of mode.
     exclude: cut a clean public branch by path — no .tsugu/ in the PR diff;
     knowledge/ still lands on the coordination ref. -->
## Merge method
Prefer merge commits — do not squash-merge tsugu-managed branches: settlement
depends on containment-preserved history. If a forge nonetheless forces a
squash, also disable the forge's auto-delete-head-branch for tsugu handoff
branches so the slug pairing survives the merge and carries the
"awaiting merge" state until the human's completion tail deletes both branches.
## Housekeeping
<!-- stale-after: 30 days -->
<!-- commented default — converge records the threshold here progressively on
     first use (ask once), then surfaces stale in-progress branches older than
     it for human-decided cleanup; a scheduled prepare never cleans. -->
## Remote
remote: origin                   # authoritative remote for fetch + branch enumeration (multi-remote safety)
default-branch:                  # optional; if blank, resolved from <remote>/HEAD
## Coordination ref
coordination-ref: default        # where `knowledge/` is written.
<!-- `default` is a sentinel = the repo's default branch (resolves to <default>, not a
branch literally named "default"). Set to a branch (e.g. tsugu/coord) only if the
default branch is push-protected. -->
## Skill use
Tsugu invokes no user-installed skill by default; it uses native git + its own
built-in capabilities. Humans trigger workflow skills (planning, review-loop, …)
by keyword.
## Recursion
Recurse into submodules / child repos only when relevant to the current goal /
branch.
