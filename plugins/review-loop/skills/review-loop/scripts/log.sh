#!/usr/bin/env bash
# log.sh — the loop's writer for the review-loop round log.
set -euo pipefail
trap 'exit 0' EXIT           # acceptance §424: neither writer ever exits non-zero, on any path --
                             # including a missing/unreadable logline.sh, which sourcing under
                             # set -e would otherwise turn into a non-zero exit that aborts callers.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 0

# Append one row to the usage file, after the header when the file is new.
# Limit: two writers that write the first row of a new file at the same time can both write
# the header. The loop writes the rows of a round one after another (SKILL.md § A3).
usage_append() { # $1=row
  local f; f="$(ll_usagefile)"
  [ -s "$f" ] || ll_append "$(printf '%s\t' date project run round reviewer model input_tokens output_tokens \
    cached_tokens reasoning_tokens total_tokens cost_usd cost_source rate_limit_before)rate_limit_after" "$f"
  ll_append "$1" "$f" || true
}
# ll_append returns 0 also when a guard or the off switch refuses a write: look at the file.
# Limit: a row that another writer appends in between makes this false, so the ids of the row are
# not kept, or a found late cost is looked up again. The loop writes one row at a time (§ A3).
# Only a regular file is read: ll_append refuses a FIFO, and reading one waits for a writer.
row_written() {
  local f; f="$(ll_usagefile)"
  [ -f "$f" ] && [ ! -h "$f" ] && [ "$(tail -n 1 "$f" 2>/dev/null)" = "$1" ]
}
# One side of a rate-limit value: a decimal number, or - for a window that the plan does not have.
rl_side() { case "$1" in -) ;; ''|.|*[!0-9.]*|*.*.*) return 1 ;; esac; }
# The pending files are removed as well as written. ll_append guards only the writes, so a pending
# directory inside a work tree is refused here, with the same nearest-existing-ancestor walk.
pending_ok() {
  local d; d="$(ll_pendingdir)"
  while [ ! -d "$d" ] && [ "$d" != / ] && [ "$d" != . ]; do d="$(dirname "$d")"; done
  [ "$(git -C "$d" rev-parse --is-inside-work-tree 2>/dev/null)" != true ]
}

case "${1:-}" in
  new-run)
    # Accumulate until at least 6 survivors: 96 filtered bytes usually suffice, but about
    # 0.7% of draws yield fewer than 6, so loop. No `head -c 6` on a live pipe — that would
    # SIGPIPE tr and fail the pipeline under `set -o pipefail`.
    s=""
    while [ "${#s}" -lt 6 ]; do s="$s$(head -c 96 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9')"; done
    printf '%s\n' "${s:0:6}"
    ;;
  review)
    shift
    # Only `review` needs the shared library; `new-run` is self-contained, so it does not source
    # (and cannot be broken by a missing library). If the library is absent, write nothing, exit 0.
    . "$DIR/logline.sh" 2>/dev/null || exit 0
    # Each reviewer is its OWN arg — `reviewer=<id>:<count>`. A model id can contain a
    # comma, so a comma-joined list cannot be split back; separate args remove the
    # ambiguity. Parse the fixed key set so the output order is project run round
    # reviewers end regardless of input order, and skip a malformed reviewer arg
    # (empty id or empty count) rather than write a broken field.
    # The value rule (drop whitespace, =, path separator) applies to every value, so run,
    # round, end and each count are scrubbed too — the reviewer id gets the stronger
    # percent-encoding. In practice the caller passes a clean run token, an integer round
    # and end=converged|stopped; scrubbing is defence, not an expected transform.
    run="" round="" endv="" revs="" pdir="$PWD"
    for kv in "$@"; do
      case "$kv" in
        dir=*)   pdir="${kv#dir=}" ;;
        run=*)   run="$(ll_scrub "${kv#run=}")" ;;
        round=*) round="$(ll_scrub "${kv#round=}")" ;;
        end=*)   endv="$(ll_scrub "${kv#end=}")" ;;
        reviewer=*)
          pair="${kv#reviewer=}"
          case "$pair" in
            *:*) id="${pair%:*}"; c="$(ll_scrub "${pair##*:}")"
                 [ -n "$id" ] && [ -n "$c" ] && revs="${revs:+$revs,}$(ll_encode_id "$id"):$c" ;;
          esac ;;
      esac
    done
    fields=("project=$(ll_project_slug "$pdir")")
    [ -n "$run" ]   && fields+=("run=$run")
    [ -n "$round" ] && fields+=("round=$round")
    [ -n "$revs" ]  && fields+=("reviewers=$revs")
    [ -n "$endv" ]  && fields+=("end=$endv")
    ll_append "$(ll_line review "${fields[@]}")" || true
    ;;
  usage)
    shift
    . "$DIR/logline.sh" 2>/dev/null || exit 0
    # One TSV row per reviewer per round. Columns are fixed and every cell is present, so a
    # reader splits on tab alone; an unreported value is an empty cell. Scrubbing drops every
    # whitespace byte, so a tab or newline in a value cannot add a cell or a row.
    # Plain variables, not an associative array: macOS still ships bash 3.2.
    cols=(run round reviewer model input output cached reasoning total cost cost_source rl_before rl_after)
    for c in "${cols[@]}"; do printf -v "u_$c" '%s' ""; done
    pdir="$PWD" pend=""
    for kv in "$@"; do
      k="${kv%%=*}"; [ "$k" = "$kv" ] && continue
      case "$k" in *[!a-z_]*) continue ;; esac   # the membership test below matches a substring
      case "$k" in
        dir)   pdir="${kv#dir=}" ;;
        pending) pend="${kv#pending=}" ;;
        # An id is encoded, as on the round log, so that two ids cannot give one cell. The encoding
        # would hide N/A from the rule below.
        model|reviewer) [ "${kv#*=}" = N/A ] || printf -v "u_$k" '%s' "$(ll_encode_id "${kv#*=}")" ;;
        # A number cell, and a rate-limit cell (<5h>+<7d>, each a number or -), takes the raw value or
        # nothing: the scrub would turn "12<tab>3" into 123.
        input|output|cached|reasoning|total) case "${kv#*=}" in ''|*[!0-9]*) ;; *) printf -v "u_$k" '%s' "${kv#*=}" ;; esac ;;
        rl_before|rl_after) v="${kv#*=}"; case "$v" in *+*) rl_side "${v%%+*}" && rl_side "${v#*+}" && printf -v "u_$k" '%s' "$v" ;; esac ;;
        cost)  case "${kv#cost=}" in ''|.|*[!0-9.]*|*.*.*) ;; *) u_cost="${kv#cost=}" ;; esac ;;
        *)     case " ${cols[*]} " in *" $k "*) [ "${kv#*=}" = N/A ] || printf -v "u_$k" '%s' "$(ll_scrub "${kv#*=}")" ;; esac ;;
      esac
    done
    # One spelling for "unknown" per column: N/A in the two cost cells, an empty cell everywhere
    # else. A given N/A is caught on the raw value above, so a name that is NA stays. N/A is
    # written here, after the scrub, because the scrub removes its '/'. Without a cost, a source
    # would name where a value came from that does not exist.
    [ -z "$u_cost" ] && { u_cost="N/A"; u_cost_source="N/A"; }
    proj="$(ll_project_slug "$pdir")"
    row="$(ll_ts)"$'\t'"$proj"
    for c in "${cols[@]}"; do n="u_$c"; row="$row"$'\t'"${!n}"; done
    usage_append "$row"
    # An N/A cost can still be found later: keep the generation ids, and nothing else of the
    # events, for usage-retry. A msg_ id never gets a cost, so such a file is not kept. Without
    # the row, a late row would have no row to match.
    # Only a regular events file is read: a FIFO waits for a writer that never comes.
    if [ "$u_cost" = N/A ] && [ -f "$pend" ] && [ -n "$u_run" ] && [ -n "$u_round" ] && [ -n "$u_reviewer" ] \
      && [ "${REVIEW_LOOP_LOG:-1}" != 0 ] && row_written "$row" && pending_ok; then
      # One line for grep, as usage.py cost reads across line breaks: both must find the same ids.
      ids="$({ tr '\n' ' ' < "$pend"; } 2>/dev/null | grep -o '"responseId"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' | sort -u)" || ids=""
      # A here-string, not a pipe: grep -q stops at the first bad id, a writer into the pipe then
      # gets SIGPIPE, and under pipefail the negated pipeline passed a list with a bad id.
      if [ -n "$ids" ] && ! grep -qv '^gen-[A-Za-z0-9_-]*$' <<<"$ids"; then
        pf="$(ll_pendingdir)/$u_run-$u_round-$u_reviewer.jsonl"; rm -f "$pf"
        # The first line names the row; read splits it on tabs, so only the last field may be empty.
        ll_append "$proj"$'\t'"$u_run"$'\t'"$u_round"$'\t'"$u_reviewer"$'\t'"$u_model" "$pf"
        for id in $ids; do ll_append "{\"responseId\":\"$id\"}" "$pf"; done
        # ll_append can refuse one line (the 1024-byte bound): a file without every id would give a
        # partial sum later, so it goes.
        [ "$(wc -l < "$pf" 2>/dev/null)" -eq $(( $(printf '%s\n' "$ids" | wc -l) + 1 )) ] 2>/dev/null || rm -f "$pf"
      fi
    fi
    ;;
  usage-retry)
    . "$DIR/logline.sh" 2>/dev/null || exit 0
    [ "${REVIEW_LOOP_LOG:-1}" = 0 ] && exit 0   # the files are removed only after a row is written
    pd="$(ll_pendingdir)"; [ -d "$pd" ] && pending_ok || exit 0
    # A generation still unknown after 7 days is not expected to appear. -mtime +6 is "7 full
    # days or more": find rounds the age down to whole days before it compares.
    find "$pd" -name '*.jsonl' -mtime +6 -exec rm -f {} + 2>/dev/null || true
    # The whole sweep gets one time budget, and each lookup gets what is left of it; the files that
    # it does not reach wait for the next run.
    budget="${REVIEW_LOOP_RETRY_BUDGET:-30}"; SECONDS=0
    for pf in "$pd"/*.jsonl; do
      [ "$SECONDS" -lt "$budget" ] 2>/dev/null || break
      [ -f "$pf" ] && [ ! -h "$pf" ] || continue
      # No 404 wait: these generations are old, so a 404 now means no record yet, and waiting for
      # each file would hold round 1 back by 25 s per file.
      c="$(REVIEW_LOOP_RETRY_WAIT=0 REVIEW_LOOP_TIME_LIMIT=$((budget - SECONDS)) python3 "$DIR/usage.py" cost "$pf" 2>/dev/null)" || c=""
      case "$c" in ''|*[!0-9.]*) continue ;; esac
      IFS=$'\t' read -r proj run round rev model < "$pf" || continue
      # Only the cost is new. A reader takes it for the earlier row with the same project, run,
      # round and reviewer (SKILL.md § A3). Limit: two sweeps at the same time can both write a
      # late row for one key, so a reader takes the last one.
      row="$(ll_ts)"$'\t'"$proj"$'\t'"$run"$'\t'"$round"$'\t'"$rev"$'\t'"$model"$'\t\t\t\t\t\t'"$c"$'\tprovider-api-late\t\t'
      usage_append "$row"
      row_written "$row" && rm -f "$pf"
    done
    ;;
  *) echo "usage: log.sh {new-run | review [dir=<path>] run=... [round=...] [reviewer=<id>:<count> ...] [end=...] | usage [dir=<path>] run=... round=... reviewer=<id> model=<id> [input= output= cached= reasoning= total= cost= cost_source= rl_before= rl_after= pending=<events file>] | usage-retry}" >&2; exit 0 ;;
  # exit 0, not 2: acceptance §424 makes non-zero exit forbidden for either writer.
esac
