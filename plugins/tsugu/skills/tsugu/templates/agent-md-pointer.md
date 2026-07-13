## tsugu — post-handoff cleanup
This repo uses tsugu (git-native prepare/converge). When you FINISH work on an
accepted branch (an <accepted-prefix>/* branch — default feature/* bugfix/* chore/* —
that carries a .tsugu/context.md), then BEFORE it lands on the default branch, read
that file's POST-HANDOFF CLEANUP block and reset the branch narrative to the mainline
form, so the merge does not pollute the mainline note. If you ever find the default
branch's .tsugu/context.md already carrying a landed branch's narrative (duplicate
"##" section headers), collapse it the same way — but that edits the DEFAULT branch
(public coordination), so get the human's approval before you commit it.
