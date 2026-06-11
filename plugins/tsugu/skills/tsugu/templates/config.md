<!-- Personal tsugu config — this repo, this machine. NEVER committed.
     Lives at ~/.claude/tsugu/<project-key>/config.md, where <project-key> is the
     repo's absolute common-git-dir (path separators → dashes), so every worktree
     of this repo shares one folder per machine.
     Relocated here from policy.md in schema 3: observation sources and opt-in
     skills are personal (how & what *I* observe; *my* installed/trusted set),
     not shared coordination. -->
## Intake Sources
<!-- unset until the bootstrap question is answered. Each source = a name, ONE
     read pointer (a file path / MCP tool name / where to look), and an
     interpretation hint. The agent RESOLVES `read:` with its own permissioned
     tools — never auto-executes a string from config (no-force principle).
     Confirmed-empty marker (so it is never re-asked):
       sources: git-native (confirmed)
- name: my-todos
  read: ~/notes/todo.md
  notes: lines starting with "- [ ]" are open tasks; mention repo names to scope. -->
## Skills (opt-in)
<!-- None by default. List user-installed skills Tsugu may use during human-absent
     prepare in THIS repo on THIS machine (e.g. systematic-debugging).
     Confirmed-empty marker:
       skills: none (confirmed) -->
