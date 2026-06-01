#!/usr/bin/env bash
# Fetch PR review state and detect Copilot's clean-pass stop signal for the review-loop skill.
#
# Subcommands:
#   fetch <pr>        dump reviews, top-level comments, and inline review comments (paginated)
#   clean-pass <pr>   exit 0 if Copilot's LATEST review is a clean pass, else 1
#
# `--paginate` is mandatory on list endpoints: page 1 holds only 30 items, and silent
# truncation can mask real review comments. clean-pass selects the newest Copilot review by
# submitted_at across all pages of the REST reviews endpoint (not `gh pr view --json reviews`,
# which is itself capped and whose ordering is not guaranteed).
#
# Requires: the `gh` CLI (authenticated) and `jq`.
set -euo pipefail

# Copilot prints this when it reviewed and found nothing to flag. A first review says
# "generated no comments."; a re-review says "generated no new comments." — match both.
CLEAN_SIGNAL_RE='generated no (new )?comments\.'
# The REST API returns the bot login WITH a "[bot]" suffix (copilot-pull-request-reviewer[bot]),
# unlike `gh pr view` which drops it — so match by prefix to accept either form.
BOT_LOGIN='copilot-pull-request-reviewer'

require_pr_number() {
  case "$1" in
    ''|*[!0-9]*) echo "PR must be a number, got: '$1'" >&2; exit 2 ;;
  esac
}

repo_owner() { gh repo view --json owner --jq '.owner.login'; }
repo_name()  { gh repo view --json name  --jq '.name'; }

fetch() {
  local pr="$1" owner name
  owner="$(repo_owner)"; name="$(repo_name)"
  # Paginate every list endpoint — page 1 caps at 30 items and silently truncates.
  echo '--- reviews ---'
  gh api --paginate "repos/${owner}/${name}/pulls/${pr}/reviews"
  echo '--- top-level (issue) comments ---'
  gh api --paginate "repos/${owner}/${name}/issues/${pr}/comments"
  echo '--- inline review comments ---'
  gh api --paginate "repos/${owner}/${name}/pulls/${pr}/comments"
}

clean_pass() {
  local pr="$1" owner name body
  owner="$(repo_owner)"; name="$(repo_name)"
  # gh --paginate emits one JSON array per page; `jq -s 'add'` merges them into a single
  # array regardless of how the pages are concatenated, then we take the newest Copilot review.
  body="$(gh api --paginate "repos/${owner}/${name}/pulls/${pr}/reviews" \
    | jq -r -s --arg login "${BOT_LOGIN}" '
        (add // [])
        | map(select((.user.login // "") | startswith($login)))
        | sort_by(.submitted_at)
        | last
        | .body // ""')"
  printf '%s' "${body}" | grep -Eq "${CLEAN_SIGNAL_RE}"
}

usage() { echo "usage: pr-comments.sh {fetch <pr> | clean-pass <pr>}" >&2; exit 2; }

cmd="${1:-}"; shift || true
case "${cmd}" in
  fetch)      [ "$#" -ge 1 ] || usage; require_pr_number "$1"; fetch "$@" ;;
  clean-pass) [ "$#" -ge 1 ] || usage; require_pr_number "$1"; clean_pass "$@" ;;
  *)          usage ;;
esac
