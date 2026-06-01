#!/usr/bin/env bash
# Request / re-request a GitHub Copilot review on a PR for the review-loop skill.
#
# Subcommands:
#   status <pr>      print who is requested vs who has reviewed (JSON)
#   request <pr>     add Copilot as a reviewer via `gh pr edit --add-reviewer` (see the first-time note below)
#   rerequest <pr>   force a fresh Copilot review via the GraphQL requestReviews mutation
#
# First-time requests: the GraphQL re-request needs Copilot's bot node id, which is only
# discoverable from an EXISTING review by Copilot. So on repos where `gh pr edit --add-reviewer`
# returns 422 for the bot, the very first Copilot review must be requested once through the
# GitHub UI. After Copilot has reviewed once, `rerequest` works for every later round.
#
# Requires: the `gh` CLI, authenticated. Repo (owner/name) is inferred from the current directory.
set -euo pipefail

# Copilot shows up under THREE different login forms across GitHub's APIs — don't unify them:
#   - GraphQL review author / Bot node:  copilot-pull-request-reviewer        (used as BOT_LOGIN below)
#   - REST reviews endpoint .user.login: copilot-pull-request-reviewer[bot]   (note the [bot] suffix)
#   - REST requested_reviewers .login:   Copilot                              (display name)
# So match REST review logins by PREFIX (startswith BOT_LOGIN), and read pending requests from
# REST `requested_reviewers` (the GraphQL-backed `gh pr view --json reviewRequests` drops the bot).
BOT_LOGIN='copilot-pull-request-reviewer'

# Guard against non-numeric input — `pr` is interpolated into GraphQL queries.
require_pr_number() {
  case "$1" in
    ''|*[!0-9]*) echo "PR must be a number, got: '$1'" >&2; exit 2 ;;
  esac
}

repo_owner() { gh repo view --json owner --jq '.owner.login'; }
repo_name()  { gh repo view --json name  --jq '.name'; }

status() {
  local pr="$1" owner name pull reviews
  owner="$(repo_owner)"; name="$(repo_name)"
  # `requested` from REST `requested_reviewers` — it includes the Copilot bot (login "Copilot"),
  # which `gh pr view --json reviewRequests` (GraphQL union) drops. `reviewed` from paginated
  # REST reviews. NB: requested login is "Copilot"; reviewed login is the "[bot]" form — callers
  # comparing the two must normalize by prefix, not `==`.
  pull="$(gh api "repos/${owner}/${name}/pulls/${pr}")"
  reviews="$(gh api --paginate "repos/${owner}/${name}/pulls/${pr}/reviews" | jq -s 'add // []')"
  jq -n --argjson pull "$pull" --argjson reviews "$reviews" '{
    requested: [ $pull.requested_reviewers[]? | (.login // .name // empty),
                 $pull.requested_teams[]?     | (.slug  // .name // empty) ],
    reviewed:  [ $reviews[]? | (.user.login // empty) ] | unique
  }'
}

request() {
  local pr="$1" errf
  errf="$(mktemp "${TMPDIR:-/tmp}/copilot-request.XXXXXX")"
  if gh pr edit "${pr}" --add-reviewer "${BOT_LOGIN}" 2>"${errf}"; then
    rm -f "${errf}"
    echo "Copilot requested via 'gh pr edit'."
    return 0
  fi
  # Surface gh's actual stderr — a 422 for the bot is expected, but auth/network/validation
  # failures would otherwise be hidden behind the same message.
  echo "'gh pr edit --add-reviewer ${BOT_LOGIN}' failed (a 422 is expected for bots on some repos); gh said:" >&2
  sed -n '1,20p' "${errf}" >&2
  rm -f "${errf}"
  echo "  - If Copilot has already reviewed this PR once, run: copilot.sh rerequest ${pr}" >&2
  echo "  - If this is the FIRST request, ask for the initial Copilot review through the GitHub UI once." >&2
  return 1
}

rerequest() {
  local pr="$1" owner name pr_id bot_id
  owner="$(repo_owner)"
  name="$(repo_name)"

  # Resolve both node ids from REST (paginated reviews — no 100-review cap that a backward
  # GraphQL scan would impose). A bot review's REST `.user.node_id` is the same node as its
  # GraphQL `Bot.id` (verified), so it's a valid `botIds` argument for requestReviews.
  pr_id="$(gh api "repos/${owner}/${name}/pulls/${pr}" --jq '.node_id // ""')" \
    || { echo "Could not fetch PR #${pr} (auth/network?) — see the error above." >&2; return 1; }
  bot_id="$(gh api --paginate "repos/${owner}/${name}/pulls/${pr}/reviews" \
    | jq -r -s --arg login "${BOT_LOGIN}" '
        (add // [])
        | map(select((.user.login // "") | startswith($login)) | .user.node_id)
        | last // ""')"

  if [ -z "${pr_id}" ]; then
    echo "Could not resolve the PR node id for #${pr}." >&2
    return 1
  fi
  if [ -z "${bot_id}" ]; then
    echo "Copilot bot node id not found — Copilot hasn't reviewed PR #${pr} yet." >&2
    echo "Request the first Copilot review through the GitHub UI once, then retry." >&2
    return 1
  fi

  gh api graphql --raw-field query="mutation {
    requestReviews(input: { pullRequestId: \"${pr_id}\", botIds: [\"${bot_id}\"], union: true }) {
      pullRequest { reviewRequests(first: 5) { nodes { requestedReviewer { __typename ... on Bot { login } } } } }
    }
  }"
}

usage() { echo "usage: copilot.sh {status <pr> | request <pr> | rerequest <pr>}" >&2; exit 2; }

cmd="${1:-}"; shift || true
case "${cmd}" in
  status)    [ "$#" -ge 1 ] || usage; require_pr_number "$1"; status "$@" ;;
  request)   [ "$#" -ge 1 ] || usage; require_pr_number "$1"; request "$@" ;;
  rerequest) [ "$#" -ge 1 ] || usage; require_pr_number "$1"; rerequest "$@" ;;
  *)         usage ;;
esac
