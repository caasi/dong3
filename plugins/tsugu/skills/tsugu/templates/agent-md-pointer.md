## tsugu — post-handoff cleanup
This repo uses tsugu (git-native prepare/converge). When you FINISH work on an
accepted branch (an <accepted-prefix>/* branch — default feature/* bugfix/* chore/* —
that carries a .tsugu/context.md), then BEFORE it lands on the default branch, read
that file's POST-HANDOFF CLEANUP block AND the comments under its section headers — a
section added after that block was written carries its own reset instruction there —
then do both things it asks: reset the branch narrative to the mainline form, so the
merge does not pollute the mainline note, and dispose of the .tsugu/evidence/ files
that branch added, moving anything still needed afterwards to CLAUDE.md / AGENTS.md,
docs/ or the test suite and deleting the rest. Moving anything into a human-facing doc
needs the human's approval first. If you ever find the default branch's
.tsugu/context.md already telling one branch's story instead of the mainline's,
collapse it the same way — but that edits the DEFAULT branch (public coordination), so
get approval from the human before you commit it.
