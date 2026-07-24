#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
SKILL="$ROOT/plugins/tsugu/skills/tsugu/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

need()   { grep -Eq -- "$1" "$SKILL" || fail "SKILL.md missing: $2"; pass "$2"; }
refute() { ! grep -Eq -- "$1" "$SKILL" || fail "SKILL.md still contains (should be gone): $2"; pass "no longer present: $2"; }
need_in()   { grep -Eq -- "$2" "$ROOT/$1" || fail "$1 missing: $3"; pass "$3"; }
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

# --- Task 11: version + descriptions (superseded by Task 8 spec 012 bump to 0.7.0, then Task 9 spec 013 bump to 0.8.0) ---
# jq is primary (portable; grep -Pz is GNU-only and can leak across plugin blocks):
jq -e '.plugins[]|select(.name=="tsugu")|.version=="0.9.0"' "$ROOT/.claude-plugin/marketplace.json" >/dev/null \
  && pass "marketplace: tsugu version 0.9.0 (bumped by spec 015)" || fail "marketplace.json: tsugu not at 0.9.0"
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
need 'tsugu-schema: 7|tsugu-schema. 7|schema . 7'     "init stamps schema 7 (spec 015: 6->7)"
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
need_in "$GR" 'tsugu-schema. 7'                       "git-recipes init-skeleton stamps schema 7 (spec 015, was 6)"

# --- Task 5 (spec 012): 4->5 migration + template push default (the template schema stamp is now 6, asserted in the Spec 013 block below) ---
TP='plugins/tsugu/skills/tsugu/templates/policy.md'
MG='plugins/tsugu/skills/tsugu/references/migrations.md'
grep -Eq '^push-prepare-branches: no' "$ROOT/$TP" && pass "template push default no" || fail "templates/policy.md push default not 'no'"
need_in "$MG" '## Migration 4.5|Migration 4→5'        "migrations has a 4->5 section"
need_in "$MG" 'push-prepare-branches: yes'            "4->5 pins explicit old default yes"
need_in "$MG" 'tsugu-schema: 5|tsugu-schema. 5'       "4->5 stamps schema 5"
need_in 'plugins/tsugu/commands/init.md' '1.2.3.4.5|tsugu-schema. 5' "init.md updated to schema 5 / 1->...->5"
need_in 'plugins/tsugu/skills/tsugu/references/policy-and-intake.md' '1.2.3.4.5|schema . 5' "policy-and-intake updated to 1->...->5 / schema 5"

# --- Task 6: prune taken-over category + command descriptions ---
NP='plugins/tsugu/skills/tsugu/references/notes-and-packet.md'
need_in "$NP" 'taken-over|redundant prepare'          "notes-and-packet documents the taken-over prune category"
need_in 'plugins/tsugu/commands/prune.md' 'taken-over|redundant prepare' "prune command notes taken-over"
need_in 'plugins/tsugu/commands/prepare.md' 'local-first|local by default' "prepare command notes local-first"

# --- Task 7: README local-first ---
RM='plugins/tsugu/skills/tsugu/README.md'
need_in "$RM" 'local-first|local by default'          "README explains local-first prepare"
need_in "$RM" 'cross-machine opt-in'                  "README notes the cross-machine push opt-in (bigram — bare tokens already present in README)"

# --- Task 8: version 0.7.0 + descriptions (superseded by Task 9 spec 013 bump to 0.8.0) ---
jq -e '.plugins[]|select(.name=="tsugu")|.version=="0.9.0"' "$ROOT/.claude-plugin/marketplace.json" >/dev/null \
  && pass "marketplace: tsugu 0.9.0" || fail "marketplace.json: tsugu not at 0.9.0"
jq -e '.plugins[]|select(.name=="tsugu")|.description|test("local-first|local by default")' "$ROOT/.claude-plugin/marketplace.json" >/dev/null \
  && pass "marketplace desc notes local-first" || fail "marketplace.json: tsugu description missing local-first"
jq -e '.description|test("local-first|local by default")' "$ROOT/plugins/tsugu/.claude-plugin/plugin.json" >/dev/null \
  && pass "plugin.json desc notes local-first" || fail "plugin.json: description missing local-first"

# --- Review fixes (spec 012 PR #53): takeover-model reconciliation + local-first labels ---
# These guard spots the earlier `need`/`refute` set (SKILL.md-only) and the per-file
# checks did not reach, so a green run no longer hides them (F1-F4/F6).
PI='plugins/tsugu/skills/tsugu/references/policy-and-intake.md'
CV='plugins/tsugu/commands/converge.md'
# F2: the old "takeover = containment OUTSIDE accepted prefixes" carve-out must be gone from SKILL.md.
refute 'outside\* the configured accepted prefixes is the'  "old pending-vs-takeover carve-out removed (F2)"
# F1: git-recipes §6 partition echoes taken-over, never the pre-reconcile `pending`.
grep -Eq 'echo +pending\b' "$ROOT/$GR" && fail "git-recipes §6 still echoes 'pending' (pre-reconcile model)" || pass "git-recipes §6 partition echoes taken-over (F1)"
# F3: policy-and-intake §Push documents schema-5 local-first, not the schema-4 default-yes.
need_in "$PI" 'local-first'   "policy-and-intake §Push is local-first (F3)"
need_in "$PI" 'schema-aware'  "policy-and-intake §Push: schema-aware absent read (F3)"
grep -Eiq 'default is \*\*.yes' "$ROOT/$PI" && fail "policy-and-intake §Push still says 'default is yes' (schema-4 stale, F3)" || pass "policy-and-intake §Push no longer defaults yes (F3)"
# F4: converge reads local + remote, not remote-tracking-only.
need_in "$CV" 'local . remote|local-first'  "converge reads local + remote work refs (F4)"
grep -Eiq 'remote-tracking refs after fetch' "$ROOT/$CV" && fail "converge.md still frames discovery as remote-tracking-only (F4)" || pass "converge.md reframed local+remote (F4)"

# --- Review round 2 (PR #53): executable §6 takeover + init default + pending propagation ---
# R2-1: §6 partition must actually CONSUME §4b containment (a human's own branch ⇒ taken-over,
# not in-progress) — guarding the table/code mismatch, not just the absent `echo pending`.
need_in "$GR" 'foreign_contains'  "§6 partition consumes §4b containment (human's own branch ⇒ taken-over)"
# the foreign_contains pipeline ends in grep -v, which exits 1 on the common no-foreign-ref
# path — must be set-e-safe (|| true) or it aborts the documented recipe under pipefail.
grep -A6 'foreign_contains=' "$ROOT/$GR" | grep -Eq '\|\| true' \
  && pass "§6 foreign_contains pipeline is set-e-safe (|| true)" \
  || fail "§6 foreign_contains grep -v not guarded — aborts under set -euo pipefail on the in-progress path"
# Read-the-queue enumeration greps must also be set-e-safe — an empty queue is valid, but grep
# exits 1 on no match and would abort the copy/pasted recipe under the documented set -euo pipefail.
if grep -nE 'grep --extended-regexp' "$ROOT/$GR" | grep -qv '|| true'; then
  fail "a 'grep --extended-regexp' enumeration line lacks '|| true' (aborts under set -euo pipefail on an empty queue)"
else
  pass "Read-the-queue enumeration greps are set-e-safe (|| true)"
fi
# R2-2: init prep-branch push question defaults no (schema-5 local-first), not yes.
need 'prep branches automatically \(\*\*default: no'    "init push question defaults no (schema 5)"
refute 'prep branches automatically \(\*\*default: yes' "old init 'default: yes' push question removed"
# R2-3: the retired partition label must be gone everywhere in the skill (not just SKILL.md/git-recipes).
grep -rIn 'decided, awaiting merge' "$ROOT/plugins/tsugu/skills/" >/dev/null 2>&1 \
  && fail "stale partition label 'decided, awaiting merge' survives (use taken-over)" \
  || pass "no stale 'decided, awaiting merge' partition label"
grep -Eiq '^- \*\*pending\*\*' "$ROOT/$RM" \
  && fail "README still lists 'pending' as a partition state" \
  || pass "README partition uses taken-over, not pending"
# the canonical state name is "taken over"; the hybrid "decided / taken over" label is retired.
refute 'decided / taken over'  "SKILL.md partition row uses 'taken over', not the hybrid 'decided / taken over'"

# --- Review round 4 (PR #53): prune taken-over bucket scoped git-derivable, squash→possibly-landed ---
# The prune "taken-over (redundant prepare)" bucket is the git-containment-derivable take only;
# the non-git-derivable squash/rewrite handoff must be pointed at possibly-landed, not this bucket.
# prune taken-over bucket = the foreign-containment source of the broad partition state only.
need    'source enters this'        "SKILL.md scopes prune taken-over to the foreign-containment source"
need_in "$GR" 'source enters this'  "git-recipes scopes prune taken-over to the foreign-containment source"
need_in "$NP" 'git-containment-derivable'               "notes-and-packet taken-over scoped to git-derivable"
need_in 'plugins/tsugu/commands/prune.md' 'squash/rewrite handoff is .possibly-landed' "prune.md points squash/rewrite at possibly-landed"
# possibly-landed owns cleanup of the paired stale prepare/<slug> for the non-derivable squash/rewrite take.
need    'paired stale'        "SKILL.md possibly-landed cleans the paired stale prepare ref"
need_in "$GR" 'paired stale'  "git-recipes possibly-landed cleans the paired stale prepare ref"

# --- Review round 7 (PR #53): retire residual "decided" partition leftovers + grammar ---
# No partition-state "decided" leftover (state-list "/ decided / settled", "→ decided", "decided/landed").
grep -rInE '/ decided / settled|→ decided|decided/landed' "$ROOT/plugins/tsugu/" >/dev/null 2>&1 \
  && fail "residual 'decided' partition-state label survives (use taken-over)" \
  || pass "no residual 'decided' partition-state label"
# Handoff-rename grammar: "renames prepare/<slug> into for ..." (missing target) must be gone.
grep -rIn 'into for ' "$ROOT/plugins/tsugu/" >/dev/null 2>&1 \
  && fail "handoff-rename grammar 'into for ...' (missing target) survives" \
  || pass "handoff-rename names its target (no 'into for')"
# CLAUDE.md prune list must include the taken-over bucket.
grep -q 'orphaned-accepted / taken-over (redundant prepare)' "$ROOT/CLAUDE.md" \
  && pass "CLAUDE.md prune list includes taken-over (redundant prepare)" \
  || fail "CLAUDE.md prune list omits the taken-over bucket"

# --- Spec 013 ---
need_in 'plugins/tsugu/skills/tsugu/templates/policy.md' 'tsugu-schema: 7'                 "policy template stamps schema 7"
need_in 'plugins/tsugu/skills/tsugu/templates/policy.md' '## Freshness'                     "policy template has Freshness section"
need_in 'plugins/tsugu/skills/tsugu/templates/policy.md' 'rebase-prepare-onto-default: yes' "policy template defaults the flag yes"
need_file 'plugins/tsugu/skills/tsugu/templates/gitattributes'                              "gitattributes template shipped"
need_in 'plugins/tsugu/skills/tsugu/templates/gitattributes' 'context\.md merge=union'      "gitattributes unions context.md"
grep -Eq 'git push --force-with-lease *$' "$ROOT/plugins/tsugu/skills/tsugu/references/git-recipes.md" && fail "git-recipes still has a BARE force-with-lease push" || pass "no bare force-with-lease in git-recipes"
need_in 'plugins/tsugu/skills/tsugu/references/git-recipes.md' 'gitattributes'  "init skeleton ships .tsugu/.gitattributes"
need_in 'CLAUDE.md' 'gitattributes'                                     "CLAUDE.md notes .tsugu/.gitattributes"
need_in 'plugins/tsugu/skills/tsugu/README.md' 'gitattributes'         "README .tsugu/ tree includes .gitattributes"
need 'gitattributes'                                                    "SKILL.md spine notes .tsugu/.gitattributes"

# --- Spec 013 Task 2: prepare freshness-rebase step (Changes A-D) + author-date recency ---
need 'rebase-prepare-onto-default'                          "prepare reads the freshness flag"
need 'git rebase --merge'                                   "forced merge backend"
need 'absent .*→ .*no|fail-safe'                            "flag absent reads no (fail-safe)"
need '--force-with-lease=<branch>:'                         "pinned force-with-lease"
need 'author-date|--sort=-authordate|%aI'                   "recency keys off author-date"
need 'skip working (the|that) branch this run'              "abort => skip working this run"
need 'bare-submodule'                                       "bare-submodule pairs excluded"
refute '--sort=-committerdate|committer-date .*claim'       "no committer-date recency read"

# --- Spec 013 Task 3: converge surfaces behind-default + offers refresh first (Change E) ---
need 'behind default by N|behind-default'                   "converge surfaces behind-default"
need 'Refresh onto current default first'                   "refresh is the first per-branch decision (matches the real prompt casing)"
need 'git switch --create prepare/'                         "cold-start materializes the WORK branch"
need 'refresh-created|pre-existing divergence'              "reconcile-push gated by divergence origin"
refute 'git switch --create <accepted-prefix>/'             "cold-start never mints the accepted name"

# --- Spec 013 Task 4: git-recipes Freshness mode-table + divergence/first-push guards + author-date ---
need_in "$GR" 'merge-base --is-ancestor'   "divergence ancestor-guard in recipe"
need_in "$GR" '--force-with-lease=<branch>:' "pinned lease in recipe"
need_in "$GR" 'git rebase --merge'          "recipe forces merge backend"
need_in "$GR" 'authordate|%aI'              "recipe recency keys off author-date"

# --- Spec 013 Task 5: migrations.md 5->6 step ---
need_in "$MG" '5 ?(→|->|to) ?6'                 "migrations has a 5->6 step"
need_in "$MG" 'rebase-prepare-onto-default: no'  "5->6 pins the flag no"
need_in "$MG" 'gitattributes'                    "5->6 adds the gitattributes"

# --- Spec 013 Task 6: policy-and-intake documents the Freshness field ---
need_in 'plugins/tsugu/skills/tsugu/references/policy-and-intake.md' 'rebase-prepare-onto-default' "policy-and-intake documents the Freshness field"
# --- Spec 013 Task 10: stale-stamp guard — init.md and README illustration stamp the CURRENT schema (6) ---
need_in 'plugins/tsugu/commands/init.md' 'tsugu-schema: 7'                    "init.md command states schema 7 (no stale schema-6)"
need_in 'plugins/tsugu/skills/tsugu/README.md' 'tsugu-schema: 7'              "README policy illustration stamps schema 7"
need_in 'plugins/tsugu/commands/init.md' '1→2→3→4→5→6'                        "init.md migration chain includes schema 6"

# --- Spec 013 Task 9: version bump 0.7.0 -> 0.8.0 (marketplace only; plugin.json has no version field) ---
[ "$(jq -r '.plugins[]|select(.name=="tsugu")|.version' "$ROOT/.claude-plugin/marketplace.json")" = "0.9.0" ] \
  || fail "marketplace tsugu entry not at 0.9.0"; pass "marketplace tsugu == 0.9.0"

# --- Spec 015 ---
need_in 'plugins/tsugu/skills/tsugu/README.md' 'POST-HANDOFF|post-handoff cleanup' "README explains the post-handoff cleanup"
need_in 'plugins/tsugu/skills/tsugu/README.md' 'matching pointer'                  "README notes the agent-md routing pointer (specific phrase)"
need_in 'CLAUDE.md' 'post-handoff|POST-HANDOFF'                                     "dong3 CLAUDE.md notes the post-handoff block"

CTX='plugins/tsugu/skills/tsugu/templates/context.md'
# NOTE: the block is hard-wrapped verbatim from the spec — every anchor below is a phrase
# that lands WITHIN a single wrapped line (grep is line-oriented; cross-line phrases never match).
need_in "$CTX" '<!-- POST-HANDOFF CLEANUP'                 "block is an HTML comment carrying the marker (not a ## section)"
need_in "$CTX" 'keep this block verbatim; never'          "block self-protection: keep verbatim (end of line 1)"
need_in "$CTX" 'delete it, never retype it'               "block forbids retyping (line 2, byte-identity)"
need_in "$CTX" 'diff against the merge-base'              "knowledge/ reconcile is merge-base-scoped"
need_in "$CTX" 'human.s approval'                         "backstop/promotion needs human approval (single-line phrase)"
grep -Eq '^## tsugu — post-handoff cleanup' "$ROOT/$CTX" && fail "context.md template must NOT contain the agent-md pointer section" || pass "context.md has no agent-md pointer (that belongs in the agent-md template)"

PTR='plugins/tsugu/skills/tsugu/templates/agent-md-pointer.md'
need_file "$PTR"                                          "agent-md pointer template shipped"
need_in "$PTR" '^## tsugu — post-handoff cleanup'        "pointer carries its section-heading marker"
need_in "$PTR" 'BEFORE it lands'                         "pointer names the moment: before landing"
need_in "$PTR" 'POST-HANDOFF CLEANUP block'             "pointer routes the agent to the context.md block"
need_in "$PTR" 'public coordination.*approv'            "pointer gates the default-branch collapse on approval (requires both words, not a loose 'approval' anywhere)"

# git-recipes init-skeleton clause for agent-md pointer
need_in "$GR" 'agent-md-pointer|## tsugu — post-handoff cleanup|agent md.*pointer' "git-recipes init-skeleton writes the agent-md pointer"

# specific-to-015 phrases (avoid bare "agent md" / "CLAUDE.md" — those pre-exist in the spine and would false-pass):
need 'always-loaded channel that routes|routes any finishing agent' "init writes the agent-md pointer (Change E)"
need 'never rewrites existing agent.?md'                 "agent-md pointer is append-only, no clobber"
need 'offers to create a minimal'                        "init offers a minimal CLAUDE.md when none exists"

# --- Spec 015 Task 3: prepare step 8 preserves the POST-HANDOFF block ---
need 'do not delete it, and do not retype it|carry the trailing standing block through .*verbatim' "prepare step 8 preserves the block verbatim (Change B)"
# NB: the marker in SKILL prose is backtick-wrapped (`POST-HANDOFF CLEANUP`), so grep for a phrase WITHOUT the marker:
need 'standing instruction, HTML comment'                "prepare step 8 names the standing block (backtick-safe phrase)"

# --- Spec 015 Task 5: spine + converge B4 + prune (Change C) ---
# NB: the marker is backtick-wrapped in SKILL prose; anchor on phrases WITHOUT the marker:
need 'standing, byte-immutable'                          "spine names the byte-immutable standing block (phrase precedes the backtick-wrapped marker)"
need 'converge .*prepares .*never .*collaps|does not collapse .context.md' "converge prepares the block, never collapses"
need 'active detect-and-collapse step'                   "no prepare/converge/prune gains an active detect-and-collapse step (backtick-safe alt)"

# --- Spec 015 Task 6: notes-and-packet.md reconciled to the 011 model (Change C) ---
NP='plugins/tsugu/skills/tsugu/references/notes-and-packet.md'
grep -Eq 'there is no state line to clean up afterwards' "$ROOT/$NP" && fail "notes-and-packet still has the stale pre-011 'no state line to clean up' claim" || pass "stale 'Rewrite on merge-back' claim removed"
grep -Eq 'converge. rewrites .context.md. into the .*ready-to-merge mainline narrative' "$ROOT/$NP" && fail "notes-and-packet still says converge rewrites context.md before merge (pre-011)" || pass "notes-and-packet no longer claims converge pre-collapses the mainline"
need_in "$NP" 'finishing agent'                          "notes-and-packet: finishing agent resets before landing"
# notes-and-packet.md is hard-wrapped ~72 cols — keep "POST-HANDOFF CLEANUP" and "inert in `exclude`" each unbroken on one line when authoring:
need_in "$NP" 'POST-HANDOFF CLEANUP'                     "notes-and-packet structure note names the standing block"
need_in "$NP" 'inert.*exclude|exclude.*inert'           "notes-and-packet: block inert in exclude mode"

# --- Spec 015 Task 7: migrations.md — new 6->7 step (normalize + pointer) (Change D) ---
MG='plugins/tsugu/skills/tsugu/references/migrations.md'
need_in "$MG" '6 ?(→|->|to) ?7'                          "migrations has a 6->7 step"
# keep these phrases each on a single line when authoring the section (grep is line-oriented):
need_in "$MG" 're-append one canonical'                  "6->7 normalizes the block (re-append one canonical copy)"
need_in "$MG" 'reserved'                                 "6->7 relies on the reserved marker (no curated-comment collision)"
need_in "$MG" 'agent-md-pointer|agent md.*pointer|## tsugu — post-handoff cleanup' "6->7 adds the agent-md pointer"
need_in "$MG" 'tsugu-schema: 7|tsugu-schema. 7'         "6->7 stamps schema 7 last"

# --- Spec 015 Task 10: stamp schema 6->7 + version 0.9.0 everywhere (stale-stamp guard) ---
need_in 'plugins/tsugu/skills/tsugu/templates/policy.md' 'tsugu-schema: 7'    "policy template stamps schema 7"
need_in 'plugins/tsugu/skills/tsugu/references/policy-and-intake.md' 'current: .7.|schema . 7' "policy-and-intake current schema 7"
need_in 'plugins/tsugu/commands/init.md' '1→2→3→4→5→6→7'                       "init.md migration chain includes schema 7"
need_in 'plugins/tsugu/commands/init.md' 'pointer|agent md'                    "init.md notes init writes the agent-md pointer (spec Files-touched; Opus/Sonnet F4)"
need_in 'plugins/tsugu/skills/tsugu/SKILL.md' 'schema 6→7|migrate .tsugu/ schema 6→7' "SKILL.md migrate-message example says schema 6→7 (not stale 5→6)"
need_in 'plugins/tsugu/skills/tsugu/SKILL.md' '1→2→3→4→5→6→7'                   "SKILL.md init-migrate chain includes schema 7"
need_in 'plugins/tsugu/skills/tsugu/references/policy-and-intake.md' '1→2→3→4→5→6→7' "policy-and-intake chain includes schema 7"
need_in 'plugins/tsugu/skills/tsugu/references/migrations.md' '1→2→3→4→5→6→7'  "migrations chain includes schema 7"
need_in 'CLAUDE.md' '015-tsugu'                                                "dong3 CLAUDE.md references spec 015"
jq -e '.plugins[]|select(.name=="tsugu")|.version=="0.9.0"' "$ROOT/.claude-plugin/marketplace.json" >/dev/null && pass "marketplace tsugu 0.9.0" || fail "marketplace.json: tsugu not at 0.9.0"
jq -e '.plugins[]|select(.name=="tsugu")|.description|test("post-handoff|POST-HANDOFF")' "$ROOT/.claude-plugin/marketplace.json" >/dev/null && pass "marketplace desc notes post-handoff" || fail "marketplace.json: tsugu description missing post-handoff"
jq -e '.description|test("schema 7")' "$ROOT/plugins/tsugu/.claude-plugin/plugin.json" >/dev/null && pass "plugin.json description stamps schema 7" || fail "plugin.json description not at schema 7"

# --- Spec 017 Task 1: ## Blindspots section in context.md template (Change A) ---
need_in 'plugins/tsugu/skills/tsugu/templates/context.md' '^## Blindspots'  "context.md template has ## Blindspots"
need_in 'plugins/tsugu/skills/tsugu/templates/context.md' 'material \+ grounded'  "Blindspots filter comment (single-line phrase)"

# --- Spec 017 Task 2: prepare blindspot sweep + decision-free probe (Change B) ---
need 'blindspot sweep|blindspot intent'                 "prepare step 7 names the blindspot sweep"
need 'material \+ grounded'                              "step 8 material+grounded filter bar (SKILL.md)"
need 'the code is the evidence'                          "prepare keeps the probe as evidence"
need 'Cleanup is deferred to the human-present'          "prepare-probe cleanup deferred to converge/finishing"
need 'flagged and routed'                                "taste-questions flagged and routed, not mined"

echo "All tsugu SKILL.md content checks passed."
