#!/usr/bin/env bash
# logline.sh — shared writer library for the review-loop observation log.
# Sourced by log.sh and object.sh. Defines ll_* functions; runs nothing on its own.

# ll_scrub drops the characters a value may not contain. Defined here because the
# slug (below) routes its result through it; the value-rule tests live in Task 3.
ll_scrub() { local v="$1"; v="${v//[[:space:]]/}"; v="${v//=/}"; v="${v//\//}"; printf '%s' "$v"; }

# Derive the project slug for a directory. Never fails; prints `none` outside a repo.
ll_project_slug() { # $1=dir
  local dir="$1" url b cd
  if url=$(git -C "$dir" remote get-url origin 2>/dev/null); then
    url="${url#*://}"        # drop scheme
    url="${url#*@}"          # drop whole userinfo@ (token included)
    url="${url%.git}"        # drop trailing .git
    ll_scrub "${url//[\/:]/-}"   # a value-rule-forbidden char in a path is removed (spec line 105)
    return
  fi
  if cd=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    b=$(basename "$cd")
    if [ "$b" = ".git" ]; then ll_scrub "$(basename "$(dirname "$cd")")"; else ll_scrub "${b%.git}"; fi
    return
  fi
  printf 'none'
}
