#!/usr/bin/env bash
# log.sh — the loop's writer for the review-loop observation log.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/logline.sh"

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
    # Each reviewer is its OWN arg — `reviewer=<id>:<count>`. A model id can contain a
    # comma, so a comma-joined list cannot be split back; separate args remove the
    # ambiguity. Parse the fixed key set so the output order is project run round
    # reviewers end regardless of input order, and skip a malformed reviewer arg
    # (empty id or empty count) rather than write a broken field.
    # The value rule (drop whitespace, =, path separator) applies to every value, so run,
    # round, end and each count are scrubbed too — the reviewer id gets the stronger
    # percent-encoding. In practice the caller passes a clean run token, an integer round
    # and end=converged|stopped; scrubbing is defence, not an expected transform.
    run="" round="" endv="" revs=""
    for kv in "$@"; do
      case "$kv" in
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
    fields=("project=$(ll_project_slug "$PWD")")
    [ -n "$run" ]   && fields+=("run=$run")
    [ -n "$round" ] && fields+=("round=$round")
    [ -n "$revs" ]  && fields+=("reviewers=$revs")
    [ -n "$endv" ]  && fields+=("end=$endv")
    ll_append "$(ll_line review "${fields[@]}")" || true
    ;;
  *) echo "usage: log.sh {new-run | review run=... [round=...] [reviewer=<id>:<count> ...] [end=...]}" >&2; exit 0 ;;
  # exit 0, not 2: acceptance §424 makes non-zero exit forbidden for either writer.
esac
