#!/usr/bin/env bash
# Manage a local Codex reviewer pane inside tmux for the review-loop skill.
#
# Subcommands:
#   find                    print an existing Codex pane id (empty + exit 0 if none)
#   ensure                  find-or-create a Codex pane (splits the current window), print its id.
#                           exit 0  = ready to receive a review
#                           exit 10 = a trust/onboarding prompt is showing; approve it yourself in
#                                     the pane, then re-run (the skill never auto-approves these)
#                           exit 1  = Codex failed to start (not on PATH, or pane never came up)
#   send <pane> <message>   paste a (possibly multi-line) message into the pane and submit it
#   capture <pane>          dump the pane's visible content to stdout
#   usage-limited <pane>    exit 0 if the pane shows a rate/usage-limit message, else 1
#
# Requires: tmux (must be run inside a tmux session) and the `codex` CLI on PATH.
# Uses POSIX-friendly short options so it runs on both BSD (macOS) and GNU systems.
set -euo pipefail

# tmux truncates pane_current_command, and the codex binary may be named e.g.
# "codex-x86_64-apple-darwin" — so match the command field on a leading "codex", and
# match ONLY the command, never the pane title (matching the title gave false positives,
# e.g. an editor open on codex-pane.sh, or a pane titled after this skill).
find_pane() {
  tmux list-panes -a -F '#{pane_current_command}|#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null \
    | awk -F'|' 'tolower($1) ~ /^codex/ { print $2; exit }'
}

pane_command() {
  tmux display-message -t "$1" -p '#{pane_current_command}' 2>/dev/null
}

# Heuristic: is the visible pane a trust / first-run prompt awaiting a choice?
looks_like_approval_prompt() {
  capture_pane "$1" | grep -iE 'yes, continue|no, quit|trust|press enter to continue|allow this folder' > /dev/null
}

ensure_pane() {
  local pane
  pane="$(find_pane)"
  if [ -n "${pane}" ]; then
    printf '%s\n' "${pane}"
    # An already-open pane can still be parked on a trust/onboarding prompt — check it too.
    if looks_like_approval_prompt "${pane}"; then
      echo "review-loop: Codex pane ${pane} is showing a trust/onboarding prompt." >&2
      echo "Approve it yourself in that pane, then re-run the Codex step." >&2
      return 10
    fi
    return 0
  fi

  if ! command -v codex > /dev/null 2>&1; then
    echo "review-loop: 'codex' not found on PATH — cannot start a Codex pane." >&2
    return 1
  fi

  # No Codex pane yet — split the current window and launch Codex beside it.
  pane="$(tmux split-window -h -P -F '#{session_name}:#{window_index}.#{pane_index}')"
  tmux send-keys -t "${pane}" 'codex' Enter

  # Wait (bounded) for one of: ready, awaiting-approval, or failed-to-start.
  # Gate on a positive signal (the codex process is the pane's foreground command),
  # not just "output stopped changing" — a static error/onboarding screen is also "stable".
  local i=0 cmd
  while [ "${i}" -lt 60 ]; do
    sleep 0.5
    i=$((i + 1))
    cmd="$(printf '%s' "$(pane_command "${pane}")" | tr '[:upper:]' '[:lower:]')"
    case "${cmd}" in
      codex*) : ;;       # Codex is up — decide between ready vs awaiting-approval below
      *) continue ;;     # still a shell / starting — keep waiting
    esac
    if looks_like_approval_prompt "${pane}"; then
      printf '%s\n' "${pane}"
      echo "review-loop: Codex is showing a trust/onboarding prompt in pane ${pane}." >&2
      echo "Approve it yourself in that pane, then re-run the Codex step." >&2
      return 10
    fi
    printf '%s\n' "${pane}"   # Codex running, no approval prompt → ready
    return 0
  done

  printf '%s\n' "${pane}"
  echo "review-loop: Codex pane ${pane} did not become ready within the timeout." >&2
  return 1
}

# Paste arbitrary (multi-line) text faithfully via a tmux buffer, then submit with a
# separate Enter. Going through a buffer avoids send-keys interpreting key names and
# collapsing/mangling whitespace in the message.
send_review() {
  local pane="$1"; shift
  local buf='review-loop-msg'
  printf '%s' "$*" | tmux load-buffer -b "${buf}" -
  tmux paste-buffer -t "${pane}" -b "${buf}" -d
  sleep 0.3                          # let the TUI ingest the paste before submitting
  tmux send-keys -t "${pane}" Enter
}

capture_pane() {
  tmux capture-pane -t "$1" -p
}

usage_limited() {
  capture_pane "$1" \
    | grep -iE 'usage limit|rate limit|quota|too many requests|try again later' \
    > /dev/null
}

usage() {
  echo "usage: codex-pane.sh {find | ensure | send <pane> <message> | capture <pane> | usage-limited <pane>}" >&2
  exit 2
}

cmd="${1:-}"; shift || true
case "${cmd}" in
  find)          find_pane ;;
  ensure)        ensure_pane ;;
  send)          [ "$#" -ge 2 ] || usage; send_review "$@" ;;
  capture)       [ "$#" -ge 1 ] || usage; capture_pane "$@" ;;
  usage-limited) [ "$#" -ge 1 ] || usage; usage_limited "$@" ;;
  *)             usage ;;
esac
