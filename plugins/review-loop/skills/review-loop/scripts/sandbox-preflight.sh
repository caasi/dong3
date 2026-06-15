#!/usr/bin/env bash
# sandbox-preflight.sh — probe whether Codex's local command sandbox (bubblewrap)
# can build on this host. Prints one status word + matching exit code:
#   usable  (0)  bwrap built the sandbox
#   broken  (1)  bwrap failed at userns/loopback setup with a permission error
#                (EPERM "Operation not permitted" or EACCES "Permission denied")
#   unknown (2)  bwrap absent on PATH, or any other (non-permission) failure — can't conclude
#
# This is a ROUTING HINT only. review-loop's post-round structural detector is the
# real guarantee. Caveat: if the user set features.use_legacy_landlock=true, Codex
# uses Landlock and never calls bwrap, so this may report `broken` while native
# `review` actually works — harmless, since the skill then routes to embedded-diff.
set -euo pipefail

if ! command -v bwrap >/dev/null 2>&1; then
  echo unknown
  exit 2
fi

# Match the namespaces Codex's own bwrap invocation creates (issue #41 strace):
# --unshare-user --unshare-net. Capture bwrap's stderr; discard its stdout.
rc=0
errout="$(bwrap --ro-bind / / --unshare-user --unshare-net --dev /dev true 2>&1 1>/dev/null)" || rc=$?

if [ "$rc" -eq 0 ]; then
  echo usable
  exit 0
fi

# Userns/loopback permission error (EPERM/EACCES) on a bwrap setup line (Ubuntu
# apparmor_restrict_unprivileged_userns) ⇒ broken. Scope to bwrap's own diagnostics
# (the `bwrap:` prefix) so an unrelated permission error from elsewhere stays
# `unknown`, per spec Component 1 ("in a bwrap setup line").
pat='bwrap:.*(Operation not permitted|Permission denied)'
if [[ "$errout" =~ $pat ]]; then
  echo broken
  exit 1
fi

# Non-EPERM failure (e.g. bad flags, other bwrap error) ⇒ can't conclude.
echo unknown
exit 2
