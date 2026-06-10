## Private Git Space (agent may do freely)
create/commit/push `prepare/*` / `investigate/*` / `review/*` branches; worktrees; write `.tsugu/*`;
run tests; try reversible patches; dispatch own (built-in) review subagents
## Public Coordination (ask first)
open MR/PR; tracker comment / status change; assign reviewers; Slack;
public commitments; move findings into human-facing docs; irreversible cleanup
## Branch Prefixes
prepare/*  investigate/*  review/*  public/*
## Remote
remote: origin                   # authoritative remote for fetch + branch enumeration (multi-remote safety)
default-branch:                  # optional; if blank, resolved from <remote>/HEAD
## Coordination ref
coordination-ref: default        # where intake/ + context/shared/ are written.
<!-- `default` is a sentinel = the repo's default branch (resolves to <default>, not a
branch literally named "default"). Set to a branch (e.g. tsugu/coord) only if the
default branch is push-protected. -->
## Intake Sources
None by default (git-native only). Add human-bridge sources here only if needed
(e.g. gh issues, CI).
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
