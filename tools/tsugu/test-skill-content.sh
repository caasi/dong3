#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
SKILL="$ROOT/plugins/tsugu/skills/tsugu/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

need()   { grep -Eq "$1" "$SKILL" || fail "SKILL.md missing: $2"; pass "$2"; }
refute() { ! grep -Eq "$1" "$SKILL" || fail "SKILL.md still contains (should be gone): $2"; pass "no longer present: $2"; }
need_in()   { grep -Eq "$2" "$ROOT/$1" || fail "$1 missing: $3"; pass "$3"; }
need_file() { [ -f "$ROOT/$1" ] || fail "missing file: $1"; pass "file exists: $1"; }

# --- Task 1: frontmatter routing + rename-invariant supersession ---
need 'tsugu:prune'                          "frontmatter/routing names prune"
need 'never renames the slug'               "rename invariant narrowed to slug"

# --- Task 2: prepare intent (Change A) ---
need 'gather understanding'                 "prepare framed as gather, not finalize"
need 'scope-only'                           "scope-only branch is first-class"
need 'proof-of-feasibility'                 "reference code optional/partial"
need 'decision-free'                        "decision-free vs needs-the-human split"

# --- Task 3: converge accept = handoff (Change B) ---
need 'git branch -m prepare/'               "handoff rename command"
need 'move, not (a )?copy'                  "handoff is a move not a copy"
need 'prints these'                         "B3 remote reconcile is print-only"
need '/tsugu:prune'                         "B4 prune reminder in converge"
need 'handoff-pending window|two-fact partition'  "B1a window guarded by partition"
# superseded default-accept recipe must be gone as the DEFAULT path. NOTE: this exact
# arrow-chain is the OLD include-mode default accept (current SKILL.md line ~166). Change C
# (Task 4) re-scopes a rebase/verify recipe to the maintenance path, but per spec 011 that
# recipe lives in git-recipes.md — so Task 4's SKILL.md maintenance prose MUST NOT reproduce
# this literal "freshness-rebase onto the fetched default → verify … → rewrite" chain, or this
# refute will break. Describe the maintenance path in different words (see Task 4 Step 3).
refute 'freshness-rebase onto the fetched default → verify .*→ rewrite'  "old default completion-tail accept"
# The housekeeping block is a SUB-BULLET ("- a **housekeeping section** —"), not a heading,
# so refute the actual prose, not a '##' heading (a heading refute is a no-op — passes today):
refute 'housekeeping section'               "dedicated converge housekeeping block removed"

# --- Task 4: maintenance exception (Change C) ---
need 'human-marked maintenance'             "maintenance exception is human-marked"
need 'never self-classif'                   "agent never self-classifies maintenance"
need 'never auto-merges'                    "public-coordination boundary intact"
need 'Provenance fallback|ambiguous provenance'  "ambiguous provenance defaults to handoff"

# --- Task 5: curation + knowledge<->agent-md boundary (Change D) ---
# NOTE: do NOT use a bare `need 'curat'` — "curated wiki" already exists in SKILL.md, so it
# passes without the real change. Anchor on phrases unique to Change D's new prose:
need 'one place|exactly one place'          "a finding lives in exactly one place"
need 'promote = move|promote-as-move|move, not copy' "promote is move not copy"
need 'orthogonal .*(curation|checklist)|curation .*(orthogonal|checklist item)' "curation is an orthogonal checklist item"
need 'knowledge/.{0,3}(↔|<->|to|→).{0,3}agent.?md|agent.?md .*boundary' "knowledge/ <-> agent-md boundary stated"

# --- Task 6: prune routine (Change E) + submodule handoff ---
need '^### .*prune'                         "prune routine section (heading)"
need 'human-present'                        "prune is human-present"
need 'read-only until'                      "prune read-only until confirmation"
need 'possibly-landed'                      "prune possibly-landed bucket"
need 'never deletes .*in-progress|stale in-progress' "prune never deletes unfinished work"
need 'renamed to a human work branch'       "submodule converge = handoff rename"
need 'meta repo no longer manages'          "meta no longer manages submodule handoff"
# force the routing prose off "three routines" (both headings + the inline routing line):
refute 'one lifecycle, three routines'      "routing prose no longer says three routines"
refute '^## The three routines'             "the-three-routines heading updated to four"

# --- Task 7: command files ---
need_file 'plugins/tsugu/commands/prune.md'                                  "prune command file"
need_in 'plugins/tsugu/commands/prune.md' 'prune'                            "prune command invokes prune routine"
need_in 'plugins/tsugu/commands/prune.md' 'read-only|human-present|approve'  "prune command states the invariants"
need_in 'plugins/tsugu/commands/converge.md' 'handoff'                       "converge command says handoff"
need_in 'plugins/tsugu/commands/converge.md' 'prune'                         "converge command points to prune"

# --- Task 8: git-recipes ---
GR='plugins/tsugu/skills/tsugu/references/git-recipes.md'
need_in "$GR" 'git branch -m prepare/'           "handoff rename recipe"
# 'prune' alone matches 'git fetch --prune' (already in the file) — anchor on a prune SWEEP heading/phrase:
need_in "$GR" '[Pp]rune sweep|^## .*[Pp]rune'    "prune sweep recipe (heading/phrase)"
need_in "$GR" 'local \+ remote|local and remote'  "accepted enumerated across local+remote"
# old recipes/heading gone (inline greps because refute is SKILL-scoped); each: present => fail, absent => pass:
grep -Eq '^## Completion tail' "$ROOT/$GR"        && fail "git-recipes still has '## Completion tail' heading"        || pass "completion-tail heading removed"
grep -Eq '^## Hand off for merge' "$ROOT/$GR"     && fail "git-recipes still has '## Hand off for merge' (old default accept)" || pass "old include-mode accept recipe removed"
grep -Eq 'Cut a clean public branch' "$ROOT/$GR"  && fail "git-recipes still has 'Cut a clean public branch' (old exclude clean-cut)" || pass "old exclude clean-cut removed"
# coordination-gate: the partition cell + the in-file cross-ref must point at prune, not the dissolved completion tail:
grep -Eq 'completion-tail / cleanup candidate' "$ROOT/$GR" && fail "git-recipes still has 'completion-tail / cleanup candidate' (dangling)" || pass "git-recipes partition cell points at prune"
grep -Eq '\(#completion-tail\)' "$ROOT/$GR"       && fail "git-recipes still links the removed #completion-tail anchor" || pass "git-recipes completion-tail cross-ref swept to prune"

# --- Task 9: advanced.md submodule handoff ---
AD='plugins/tsugu/skills/tsugu/references/advanced.md'
need_in "$AD" 'hand off|handoff'  "bare-submodule landing reduced to handoff"
# the reduced section heading must be the handoff name, not the old two-repo landing title:
grep -Eq '^## Bare-submodule handoff' "$ROOT/$AD" && pass "advanced.md heading renamed to Bare-submodule handoff" || fail "advanced.md heading not renamed to '## Bare-submodule handoff'"
# the old agent-driven transaction must be gone (present => fail, absent => pass):
grep -Eq 'ordered.{0,4}two-repo (landing )?transaction' "$ROOT/$AD" && fail "advanced.md still describes the ordered two-repo transaction" || pass "old two-repo transaction removed"
# coordination-gate: NO SKILL.md cross-ref may still dangle to the old "two-repo landing" section title:
grep -Eq 'Bare-submodule two-repo landing' "$SKILL" && fail "SKILL.md still cross-refs '§ Bare-submodule two-repo landing' (dangling)" || pass "SKILL.md cross-refs Bare-submodule handoff (no dangling)"

# --- Task 10: notes-and-packet curation discipline ---
NP='plugins/tsugu/skills/tsugu/references/notes-and-packet.md'
need_in "$NP" 'write-gate|do not record what'      "knowledge/ write-gate"
need_in "$NP" 'one place|move, not copy|promote-as-move' "promote-as-move / one place"

# --- Task 10a: housekeeping field reframed to prune + converge-flag consumers ---
PI='plugins/tsugu/skills/tsugu/references/policy-and-intake.md'
TP='plugins/tsugu/skills/tsugu/templates/policy.md'
need_in "$PI" 'prune'                              "policy-and-intake housekeeping mentions prune"
# the old "converge ... housekeeping cleanup" framing must be gone in BOTH files (present => fail):
grep -Eiq 'converge[^.]*housekeeping (section|cleanup|surfac)' "$ROOT/$PI" \
  && fail "policy-and-intake still frames housekeeping as a converge cleanup block" \
  || pass "policy-and-intake: housekeeping not framed as converge cleanup"
grep -Eiq 'converge[^.]*housekeeping (section|cleanup|surfac)' "$ROOT/$TP" \
  && fail "templates/policy still frames housekeeping as a converge cleanup block" \
  || pass "templates/policy: housekeeping not framed as converge cleanup"
# the stale-after field itself must SURVIVE in the template (it's still consumed by prune + converge flag):
need_in "$TP" 'stale-after'                        "templates/policy keeps the stale-after field"

# --- Task 10b: README four routines + handoff ---
RM='plugins/tsugu/skills/tsugu/README.md'
need_in "$RM" '/tsugu:prune|four routines'   "README lists prune / four routines"
need_in "$RM" 'hand off|handoff'             "README says converge hands off"
grep -Eiq 'one lifecycle, three routines|three routines' "$ROOT/$RM" \
  && fail "README still says three routines" || pass "README no longer says three routines"

# --- Cross-ref integrity: the section was renamed to "§ Bare-submodule handoff" ---
# No file anywhere in the plugin may still reference the old section name (a dangling cross-ref).
grep -rE '§ Bare-submodule two-repo landing' "$ROOT/plugins/tsugu/" >/dev/null 2>&1 \
  && fail "dangling cross-ref to renamed section '§ Bare-submodule two-repo landing'" \
  || pass "no dangling 'Bare-submodule two-repo landing' cross-ref"
# The completion tail was dissolved (spec §B5): no '## Completion tail' heading may survive, and
# nothing should be described as "swept by ... completion tail" (intentional "is dissolved" prose is fine).
grep -rEn '^## Completion tail|swept .{0,30}completion tail|completion tail[^.]{0,20}sweep' "$ROOT/plugins/tsugu/skills/" >/dev/null 2>&1 \
  && fail "a live 'completion tail' sweep reference survives (should be prune)" \
  || pass "no live completion-tail sweep reference"

# --- Task 11: version + descriptions ---
# jq is primary (portable; grep -Pz is GNU-only and can leak across plugin blocks):
jq -e '.plugins[]|select(.name=="tsugu")|.version=="0.6.0"' "$ROOT/.claude-plugin/marketplace.json" >/dev/null \
  && pass "marketplace: tsugu version 0.6.0" || fail "marketplace.json: tsugu not at 0.6.0"
# guard the DESCRIPTION content too (a stale description with the new version would otherwise pass):
jq -e '.plugins[]|select(.name=="tsugu")|.description|test("prune")' "$ROOT/.claude-plugin/marketplace.json" >/dev/null \
  && pass "marketplace: tsugu description names prune" || fail "marketplace.json: tsugu description missing prune"
jq -e '.description|test("prune")' "$ROOT/plugins/tsugu/.claude-plugin/plugin.json" >/dev/null \
  && pass "plugin.json description names prune" || fail "plugin.json: description missing prune"

# --- Task 12: project CLAUDE.md ---
need_in 'CLAUDE.md' '/tsugu:prune'   "CLAUDE.md lists the prune command"
need_in 'CLAUDE.md' '011-tsugu'      "CLAUDE.md references spec 011"
grep -Eiq 'Three routines|/tsugu:init., ./tsugu:prepare., ./tsugu:converge.[^,]*$' "$ROOT/CLAUDE.md" \
  && fail "CLAUDE.md tsugu summary still says three routines" || pass "CLAUDE.md updated past three routines"

# --- Exclude-mode reconciliation (spec 011 §B2 + Option A): settlement is mode-agnostic;
#     converge no longer cuts a by-path public branch. None of the old exclude prose may survive. ---
grep -rIF "work branch never merges"     "$ROOT/plugins/tsugu/skills/" >/dev/null 2>&1 && fail "stale exclude prose: 'work branch never merges'"     || pass "no stale exclude prose: work branch never merges"
grep -rIF "public branch's tip"          "$ROOT/plugins/tsugu/skills/" >/dev/null 2>&1 && fail "stale exclude prose: \"public branch's tip\""        || pass "no stale exclude prose: public branch's tip"
grep -rIF "by-path application breaks"   "$ROOT/plugins/tsugu/skills/" >/dev/null 2>&1 && fail "stale exclude prose: 'by-path application breaks'"   || pass "no stale exclude prose: by-path application breaks"
grep -rIF "cut a clean public branch"    "$ROOT/plugins/tsugu/skills/" >/dev/null 2>&1 && fail "stale exclude prose: 'cut a clean public branch'"    || pass "no stale exclude prose: cut a clean public branch"
# old-model "converge cuts an accepted branch" phrasing (handoff RENAMES, never cuts):
grep -rIF "will cut under"           "$ROOT/plugins/tsugu/skills/" >/dev/null 2>&1 && fail "stale old-model: 'will cut under <Accepted Prefix>'"     || pass "no stale old-model: will cut under"
grep -rIF "cut fresh from default"   "$ROOT/plugins/tsugu/skills/" >/dev/null 2>&1 && fail "stale old-model: 'cut fresh from default'"               || pass "no stale old-model: cut fresh from default"
grep -rIF "applied by path"          "$ROOT/plugins/tsugu/skills/" >/dev/null 2>&1 && fail "stale old-model: 'applied by path'"                        || pass "no stale old-model: applied by path"
# converge RENAMES, never cuts an accepted branch:
grep -rIE "converge cuts?|converge cut hands|a converge cut" "$ROOT/plugins/tsugu/skills/" >/dev/null 2>&1 && fail "stale old-model: 'converge cut(s)' (handoff renames, never cuts)" || pass "no stale old-model: converge cuts"

# --- Task 1: local-first prepare + schema-aware push read + schema 5 ---
# (dropped bare `need 'push-prepare-branches'` — pre-satisfied by the old default-yes prose)
need 'local-first|stays on local|keep work .*local'   "prepare is local-first by default"
need 'schema 4 else|tsugu-schema: 4.*yes|absent.*schema' "schema-aware push default read"
need 'tsugu-schema: 5|tsugu-schema. 5|schema . 5'     "init stamps schema 5"
need 'cross-machine opt-in'                           "remote push is a cross-machine opt-in (bigram — bare 'opt-in' appears 5x in SKILL already)"
# the OLD unconditional framing must be gone:
refute 'default .yes. when the section is absent'     "old flat 'default yes when absent' removed"
refute 'enumerates only remote-tracking refs'         "old 'only remote-tracking refs' framing removed"

# --- Task 2: human-takeover detection by containment (Change B) ---
need 'taken over|taken-over'                          "takeover state named"
need 'human.?s own branch|own-named|human-named'      "recognizes a human's own-named branch (the #52 gap; 'for-each-ref --contains' alone is a no-op — it already exists at SKILL.md:124)"
need 'non-default.*non-work|non-work.*non-default'    "filter: non-default, non-work ref"
need 'generaliz'                                      "containment generalizes slug-pairing"
need 'script-free|ships no script|not a shipped'      "git-native, no shipped script note"
need 'classification is per-ref|each ref by its own tip|union.{0,12}display' "per-ref/per-tip classification — a divergent local in-progress tip is not suppressed by a stale remote tip's containment (spec A2)"

# --- Task 3: taken-over disposition (C) + auto-push invariant (D) ---
need 'suppress|suppressed from auto-work'             "taken-over suppresses auto-work"
need 'both human-confirmed|local and remote, both'    "cleanup is local AND remote, both human-confirmed (bare 'human-confirmed' is pre-satisfied by 011 prose)"
need 'never auto-push|auto-push .*work-prefix|only .*work-prefix' "auto-push invariant: only work-prefix"
need 'redundant prepare|taken-over.*prune|prune.*taken-over' "prune taken-over category"
# the disposition must NEVER auto-delete the prepare/redundant ref (the load-bearing safety fix).
# NB: must NOT trip the legit forge 'auto-delete-head-branch' (hyphen) or 011's 'never auto-deletes on a guess'.
refute 'auto-delete[sd]?( the| a| its)?( local| redundant| stale)? (prepare|work branch)|auto-delete[sd]?( the| a)?( local| redundant) ref\b' "no auto-delete of the prepare/redundant ref"

# --- Task 4: git-recipes local-default read + takeover recipe ---
GR='plugins/tsugu/skills/tsugu/references/git-recipes.md'
need_in "$GR" 'local-first .default.'                 "no-push mode relabeled local-first default ('local.*default' fallback dropped — it matches the pre-existing 'stale local default' Freshness line)"
need_in "$GR" 'cross-machine opt-in'                  "pushed mode relabeled cross-machine opt-in"
need_in "$GR" 'for-each-ref --contains'               "takeover containment recipe present (absent in git-recipes today)"
need_in "$GR" 'taken over|takeover'                   "git-recipes has the takeover recipe (replaces the 'fetch --prune' no-op, which already exists at git-recipes.md:41)"
need_in "$GR" 'refs/heads refs/remotes|refs/heads .refs/remotes' "takeover scoped to branch namespaces"
# the work queue must no longer be framed as remote-tracking-only (012 unions local+remote).
# git-recipes.md:98 currently reads "...unlike the work queue, which is remote-tracking" — that must go
# (the naive 'work queue.*local' need is a no-op: it matches that very line 98):
grep -Eiq 'work queue, which is remote-tracking' "$ROOT/$GR" \
  && fail "git-recipes still frames the work queue as remote-tracking-only (012 unions local+remote)" \
  || pass "work queue reframed off remote-tracking-only"
need_in "$GR" 'per-ref|each ref by its own tip'      "git-recipes notes per-ref/per-tip classification"
need_in "$GR" 'tsugu-schema. 5'                       "git-recipes init-skeleton stamps schema 5 (was 4 at :536)"

echo "All tsugu SKILL.md content checks passed."
