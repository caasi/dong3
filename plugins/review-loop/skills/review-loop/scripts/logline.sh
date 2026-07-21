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

# Percent-encode; % first so the mapping is injective
ll_encode_id() { # $1=model-id
  local v="$1"
  v="${v//%/%25}"
  v="${v// /%20}"; v="${v//$'\t'/%09}"; v="${v//$'\n'/%0A}"
  v="${v//$'\r'/%0D}"; v="${v//$'\f'/%0C}"; v="${v//$'\v'/%0B}"   # every whitespace byte
  v="${v//=/%3D}"; v="${v//\//%2F}"; v="${v//,/%2C}"; v="${v//:/%3A}"
  printf '%s' "$v"
}

# Current UTC timestamp, ISO-8601, trailing Z
ll_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Single log line joined by two spaces. Does not write.
ll_line() { # $1=event, rest = key=value tokens already formed by caller
  local event="$1"; shift
  local out; out="$(ll_ts)  $event"
  local kv; for kv in "$@"; do out="$out  $kv"; done
  printf '%s' "$out"
}
