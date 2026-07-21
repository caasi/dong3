# tools/review-loop/lib.bash — sourced by every test-*.sh in this dir.
set -euo pipefail
LIBDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGLINE="$LIBDIR/../../plugins/review-loop/skills/review-loop/scripts/logline.sh"

# Build a throwaway clone with a given origin URL; echo its path.
# Local identity so --allow-empty commits work in a clean environment (no global git config).
git_id=(-c user.name=t -c user.email=t@t)
mk_repo_with_origin() { # $1=origin-url
  local d; d="$(mktemp -d)"; git -C "$d" init -q
  git -C "$d" remote add origin "$1"
  git "${git_id[@]}" -C "$d" commit -q --allow-empty -m x
  echo "$d"
}
# Plain clone, no remote.
mk_plain_repo() {
  local d; d="$(mktemp -d)"; git -C "$d" init -q
  git "${git_id[@]}" -C "$d" commit -q --allow-empty -m x
  echo "$d"
}
# A linked worktree of $1; echo the worktree path.
mk_worktree() { # $1=repo
  local w="$1-wt"; git -C "$1" worktree add -q "$w" -b wt-branch >/dev/null 2>&1
  echo "$w"
}
# Portable octal permission bits of a file (e.g. 600), so the suite runs on macOS too.
# GNU coreutils uses `stat -c %a`; BSD/macOS uses `stat -f %Lp`. The script under test
# already avoids GNU-only stat for the same reason; the tests must match.
file_mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }
