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
  gh pr view "$1" --json reviewRequests,reviews \
    --jq '{requested: [.reviewRequests[].login], reviewed: [.reviews[].author.login]}'
}

request() {
  local pr="$1"
  if gh pr edit "${pr}" --add-reviewer "${BOT_LOGIN}" 2>/dev/null; then
    echo "Copilot requested via 'gh pr edit'."
    return 0
  fi
  echo "'gh pr edit --add-reviewer ${BOT_LOGIN}' failed (a 422 is expected for bots on some repos)." >&2
  echo "  - If Copilot has already reviewed this PR once, run: copilot.sh rerequest ${pr}" >&2
  echo "  - If this is the FIRST request, ask for the initial Copilot review through the GitHub UI once." >&2
  return 1
}

rerequest() {
  local pr="$1" owner name resp pr_id bot_id
  owner="$(repo_owner)"
  name="$(repo_name)"

  # Scan the 100 most recent reviews for Copilot's bot id. Practical cap: on an
  # extremely noisy PR where Copilot's reviews are all older than the last 100,
  # this would miss it — accept that bound rather than paginate backward.
  resp="$(gh api graphql --raw-field query="query {
    repository(owner: \"${owner}\", name: \"${name}\") {
      pullRequest(number: ${pr}) {
        id
        reviews(last: 100) { nodes { author { __typename login ... on Bot { id } } } }
      }
    }
  }")" || { echo "GraphQL query failed (auth/network?) — see the error above." >&2; return 1; }

  pr_id="$(printf '%s' "${resp}" | jq -r '.data.repository.pullRequest.id // ""')"
  bot_id="$(printf '%s' "${resp}" | jq -r --arg login "${BOT_LOGIN}" '
    [ .data.repository.pullRequest.reviews.nodes[]?
      | select(.author.__typename == "Bot" and .author.login == $login)
      | .author.id ][0] // ""')"

  if [ -z "${pr_id}" ]; then
    echo "Could not resolve the PR node id. GraphQL response:" >&2
    printf '%s\n' "${resp}" >&2
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
