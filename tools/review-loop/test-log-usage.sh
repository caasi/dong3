#!/usr/bin/env bash
# log.sh usage (the per-reviewer TSV row) and the dir= argument of both subcommands.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
LOG="$LIBDIR/../../plugins/review-loop/skills/review-loop/scripts/log.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }; pass() { echo "PASS: $*"; }
eq() { [ "$1" = "$2" ] || fail "$3: expected [$2] got [$1]"; pass "$3"; }

repo="$(mk_repo_with_origin https://github.com/caasi/dong3.git)"
tmp="$(mktemp -d)"; export REVIEW_LOOP_USAGE_FILE="$tmp/u.tsv" REVIEW_LOOP_LOG_FILE="$tmp/l.log"
T=$'\t'

# Header once, then a full row in column order.
( cd "$repo" && bash "$LOG" usage run=x7k2p9 round=1 reviewer=codex model=gpt-6-astra input=1200 output=300 \
    cached=800 reasoning=100 total=1500 cost=0.0123 cost_source=provider-api rl_before=1+0 rl_after=3+1 )
( cd "$repo" && bash "$LOG" usage run=x7k2p9 round=1 reviewer=or/glm model=z-ai/glm-5.3 output=5 )
eq "$(sed -n 1p "$tmp/u.tsv")" "date${T}project${T}run${T}round${T}reviewer${T}model${T}input_tokens${T}output_tokens${T}cached_tokens${T}reasoning_tokens${T}total_tokens${T}cost_usd${T}cost_source${T}rate_limit_before${T}rate_limit_after" "header"
eq "$(grep -c '^date' "$tmp/u.tsv")" 1 "header written once"
eq "$(sed -n 2p "$tmp/u.tsv" | cut -f2-)" "github.com-caasi-dong3${T}x7k2p9${T}1${T}codex${T}gpt-6-astra${T}1200${T}300${T}800${T}100${T}1500${T}0.0123${T}provider-api${T}1+0${T}3+1" "full row"
eq "$(sed -n 3p "$tmp/u.tsv" | cut -f2-)" "github.com-caasi-dong3${T}x7k2p9${T}1${T}or%2Fglm${T}z-ai%2Fglm-5.3${T}${T}5${T}${T}${T}${T}N/A${T}N/A${T}${T}" "empty token cells, cost N/A, reviewer and model encoded"
eq "$(sed -n 3p "$tmp/u.tsv" | awk -F'\t' '{print NF}')" 15 "15 columns on a sparse row"

# cost N/A forces cost_source N/A, also when the caller gave a source.
: > "$tmp/u.tsv"
( cd "$repo" && bash "$LOG" usage run=r round=1 reviewer=glm cost=N/A cost_source=provider-api )
eq "$(sed -n 2p "$tmp/u.tsv" | cut -f12-13)" "N/A${T}N/A" "cost N/A wins over a given source"

# N/A belongs to the two cost cells only; elsewhere it is an empty cell ("not reported").
: > "$tmp/u.tsv"
( cd "$repo" && bash "$LOG" usage run=r round=1 reviewer=codex model=N/A input=N/A rl_before=N/A rl_after=3+1 )
eq "$(sed -n 2p "$tmp/u.tsv" | cut -f6,7,14,15)" "${T}${T}${T}3+1" "N/A in a model, token or rate-limit cell → empty"

# A number cell takes a number only: removing the whitespace of "12<tab>3" would give a
# plausible 123. A token cell that is not a whole number is empty, a cost that is not a
# decimal number is N/A.
: > "$tmp/u.tsv"
( cd "$repo" && bash "$LOG" usage run=r round=1 reviewer=codex "input=12${T}3" output=7 total=1e3 cost=0.5x cost_source=provider-api )
eq "$(sed -n 2p "$tmp/u.tsv" | cut -f7,8,11,12,13)" "${T}7${T}${T}N/A${T}N/A" "a value that is not a number is not written as one"

# A rate-limit cell takes <5h>+<7d> (a number or -) or nothing: "1 2+3" would give a plausible 12+3.
: > "$tmp/u.tsv"
( cd "$repo" && bash "$LOG" usage run=r round=1 reviewer=codex "rl_before=1 2+3" rl_after=-+52.5 )
eq "$(sed -n 2p "$tmp/u.tsv" | cut -f14,15)" "${T}-+52.5" "a rate-limit value that is not <5h>+<7d> is not written"
: > "$tmp/u.tsv"
( cd "$repo" && bash "$LOG" usage run=r round=1 reviewer=codex rl_before=1-2+3 rl_after=..+.. )
eq "$(sed -n 2p "$tmp/u.tsv" | cut -f14,15)" "${T}" "each side of a rate-limit value is a number or -"

# NA is a name, not "unknown": only a given N/A empties a cell.
: > "$tmp/u.tsv"
( cd "$repo" && bash "$LOG" usage run=NA round=1 reviewer=NA model=NA )
eq "$(sed -n 2p "$tmp/u.tsv" | cut -f3,5,6)" "NA${T}NA${T}NA" "a run, reviewer or model named NA is kept"

# A tab or a newline in a value cannot split a cell or a row.
rm "$tmp/u.tsv"
( cd "$repo" && bash "$LOG" usage run=r round=1 "reviewer=a${T}b" "model=m${T}x"$'\n'"y" )
eq "$(wc -l < "$tmp/u.tsv" | tr -d ' ')" 2 "newline in a value adds no row"
eq "$(sed -n 2p "$tmp/u.tsv" | awk -F'\t' '{print NF}')" 15 "tab in a value adds no column"

# A key that is not a column name (here: two names joined by a space) is ignored; the row is kept.
rm "$tmp/u.tsv"
( cd "$repo" && bash "$LOG" usage "run round=5" run=r reviewer=opus ) 2>"$tmp/err"
eq "$(sed -n 2p "$tmp/u.tsv" | cut -f3,5)" "r${T}opus" "a malformed key does not lose the row"
[ -s "$tmp/err" ] && fail "stderr: $(cat "$tmp/err")" || pass "a malformed key writes no stderr"

# dir= sets the project, whatever the current directory is.
other="$(mk_repo_with_origin https://github.com/caasi/town-zero.git)"
rm "$tmp/u.tsv"
( cd "$repo" && bash "$LOG" usage dir="$other" run=r round=1 reviewer=opus )
eq "$(sed -n 2p "$tmp/u.tsv" | cut -f2)" "github.com-caasi-town-zero" "usage: dir= wins over PWD"
( cd "$repo" && bash "$LOG" review dir="$other" run=r round=1 reviewer=opus:0 )
case "$(cat "$tmp/l.log")" in
  *"  review  project=github.com-caasi-town-zero  run=r  round=1  reviewers=opus:0") pass "review: dir= wins over PWD" ;;
  *) fail "review dir=: [$(cat "$tmp/l.log")]" ;;
esac

# The guards of ll_append hold for the usage file: off switch, file inside a work tree.
rm "$tmp/u.tsv"
( cd "$repo" && REVIEW_LOOP_LOG=0 bash "$LOG" usage run=r reviewer=opus )
[ ! -e "$tmp/u.tsv" ] && pass "off switch" || fail "off switch wrote"
( cd "$repo" && REVIEW_LOOP_USAGE_FILE="$repo/u.tsv" bash "$LOG" usage run=r reviewer=opus )
[ ! -e "$repo/u.tsv" ] && pass "work-tree guard" || fail "wrote inside a work tree"
( cd "$repo" && bash "$LOG" usage run=r reviewer=opus ); eq "$(file_mode "$tmp/u.tsv")" 600 "mode 600"
echo ALL PASS
