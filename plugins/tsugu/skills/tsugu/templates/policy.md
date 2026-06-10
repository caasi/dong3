tsugu-schema: 2
## Private Git Space (agent may do freely)
create/commit/push `prepare/*` / `investigate/*` / `review/*` branches; worktrees; write `.tsugu/*`;
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
<!-- include (default): the work branch is what merges; its .tsugu/ evidence
     lands on the default branch as durable shared memory.
     exclude: cut a clean public branch by path — no .tsugu/ in the PR diff. -->
## Merge method
Prefer merge commits — do not squash-merge tsugu-managed branches: derived
settlement depends on preserved history. If a human system forces a squash,
converge confirms the landing and records `landed: <sha>` in the intake note.
## Housekeeping
<!-- stale-after: 30 days -->
<!-- commented default — converge records the threshold here progressively on
     first use (ask once), then surfaces in-progress branches / open intake
     notes older than it for human-decided cleanup; a scheduled prepare never
     cleans. -->
## Remote
remote: origin                   # authoritative remote for fetch + branch enumeration (multi-remote safety)
default-branch:                  # optional; if blank, resolved from <remote>/HEAD
## Coordination ref
coordination-ref: default        # where intake/ + knowledge/ are written.
<!-- `default` is a sentinel = the repo's default branch (resolves to <default>, not a
branch literally named "default"). Set to a branch (e.g. tsugu/coord) only if the
default branch is push-protected. -->
## Intake Sources
default: git-native. Each additional source below is read on every prepare run.
<!-- a source = a name, ONE read instruction (shell command / file path / MCP
     tool name), and an interpretation hint. Not limited to task systems —
     RSS feeds, security watches (YARA/CVE), CI queries fit the same shape.
- name: my-todos
  read: `cat ~/notes/todo.md`
  notes: lines starting with "- [ ]" are open tasks; mention repo names to scope.
-->
## Skill use
Tsugu invokes no user-installed skill by default; it uses native git + its own
built-in capabilities. Humans trigger workflow skills (planning, review-loop, …)
by keyword.
## Skills Tsugu may use (this repo, opt-in)
None by default. List user-installed skills Tsugu may use during human-absent
prepare in THIS repo (e.g. systematic-debugging). Repo-local only — the shipped
SKILL.md never names skills.
## Recursion
Recurse into submodules / child repos only when relevant to the current goal /
intake / branch.
