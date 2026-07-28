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
     of the narrative skeleton; keep it verbatim. -->
## Why this ref exists
## Current understanding
## Open questions
## Blindspots
<!-- unknown unknowns the territory sweep surfaced (convention traps, historical
     pitfalls, unnamed consumers, patterns to follow).
     Filter: material + grounded — it changes architecture/data/security/scope
     AND is rooted in observed source, not a generic preference.
     Runnable evidence lives in knowledge/; a line here only indexes it.
     A branch-working section. If you are the finishing agent resetting this
     file to the mainline form before landing, collapse THIS section too, with
     the rest of the branch's story — the standing block below cannot name it.
     (Not a question list — that is Open questions.) -->
## Next actions
## Verification
<!-- prefer runnable evidence — a committed repro script, a failing test, a
     probe — over prose claims; the next inheritor re-runs instead of
     re-trusting -->
## Promotion candidates

<!-- POST-HANDOFF CLEANUP (standing instruction — keep this block verbatim; never
     delete it, never retype it). After tsugu hands a work branch off (converge
     accept renames prepare/<slug> to an accepted branch and stops), a human takes
     over and finishes the feature with an agent — OUTSIDE tsugu's prepare → converge
     → prune lifecycle, so no tsugu routine runs there. If you are that finishing
     agent: when you and the human are DONE, and BEFORE the branch lands on the
     default branch, reset this context.md back to the mainline form — collapse this
     branch's own story ("Why this ref exists" / "Open questions" / "Next actions")
     into a one-line "what recently landed" note under "Current understanding" — so
     what lands on default is clean and the mainline note does not accumulate a dead
     branch's narrative on merge. Then reconcile the knowledge/ entries THIS branch
     added (diff against the merge-base to find them — never touch inherited mainline
     entries): prune the transient ones; a durable one is promoted to the agent md
     (CLAUDE.md / AGENTS.md) only with the human's approval (that promotion is public
     coordination). BACKSTOP: if this reset was missed and the mainline context.md on
     the default branch already shows a landed branch's story (duplicate "##" section
     headers), the next agent that reads it collapses it the same way — but that edits
     .tsugu/context.md ON THE DEFAULT BRANCH, which is public coordination, so get the
     human's approval first. Leave THIS block in place — it must survive the reset for
     the next work. -->
