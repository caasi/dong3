<!-- context.md — this ref's situation and origin, in pure narrative.
     No status, no claim fields, no recorded lineage: live state is derived
     from refs and the DAG (see SKILL.md). On the default branch this file
     describes the mainline (what this repo is, where the mainline stands,
     what recently landed — init writes the first version). A new work branch
     inherits the mainline form; rewriting it into the branch's own story is
     the first act of real work, and that rewrite commit is the claim. The
     `## Blindspots` section records the prepare sweep's unknown unknowns and is a
     branch-working section (reset with the branch story on handoff). The
     trailing POST-HANDOFF CLEANUP block is a standing instruction, not part
     of the narrative skeleton; carry it through when you rewrite the rest. -->
## Why this ref exists
## Current understanding
## Open questions
## Blindspots
<!-- unknown unknowns the territory sweep surfaced (convention traps, historical
     pitfalls, unnamed consumers, patterns to follow).
     Filter: material + grounded — it changes architecture/data/security/scope
     AND is rooted in observed source, not a generic preference.
     Runnable evidence lives in evidence/; a line here only indexes it.
     A branch-working section. If you are the finishing agent resetting this
     file to the mainline form before landing, collapse THIS section too, with
     the rest of the branch's story.
     (Not a question list — that is Open questions.) -->
## Next actions
## Verification
<!-- prefer runnable evidence — a committed repro script, a failing test, a
     probe — over prose claims; the next inheritor re-runs instead of
     re-trusting. The artifacts themselves live in .tsugu/evidence/. -->

<!-- POST-HANDOFF CLEANUP (a standing instruction — keep it here for the next work).
     After tsugu hands a work branch off (converge accept renames prepare/<slug> to an
     accepted branch and stops), a human takes over and finishes the feature with an
     agent — OUTSIDE tsugu's prepare → converge → prune lifecycle, so no tsugu routine
     runs there. If you are that finishing agent: when you and the human are DONE, and
     BEFORE the branch lands on the default branch, do two things.

     ONE — reset this context.md back to the mainline form: collapse this branch's own
     story ("Why this ref exists" / "Open questions" / "Blindspots" / "Next actions")
     into a one-line "what recently landed" note under "Current understanding", so what
     lands on default is clean and the mainline note does not accumulate a dead branch's
     narrative.

     TWO — dispose of the evidence/ files THIS branch added (diff against the merge-base
     to find them — never touch inherited ones). Ask one question of each file: does
     anything after this branch still need it? If yes, MOVE it to the place that keeps
     it — a convention this repo follows goes to CLAUDE.md / AGENTS.md, an explanation a
     person reads goes to docs/, a behaviour the code must keep goes to the test suite.
     If no, DELETE it. Most files are deleted; that is the normal outcome, not a
     failure. Moving anything into CLAUDE.md / AGENTS.md or docs/ is public
     coordination — draft it, then get the human's approval before committing. The
     directory ends holding .gitkeep and nothing else.

     BACKSTOP: if this reset was missed and the default branch's .tsugu/context.md
     already tells one branch's story instead of the mainline's, the next agent that
     reads it collapses it the same way — but that edits .tsugu/context.md ON THE
     DEFAULT BRANCH, which is public coordination, so get the human's approval first. -->
