#!/usr/bin/env bash
# usage.py: every source prints a value or N/A, and the script always exits 0.
# OpenRouter is replaced by a local fake server; no request leaves the host.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
PY="$LIBDIR/../../plugins/review-loop/skills/review-loop/scripts/usage.py"
fail() { echo "FAIL: $*" >&2; exit 1; }; pass() { echo "PASS: $*"; }
eq() { [ "$1" = "$2" ] || fail "$3: expected [$2] got [$1]"; pass "$3"; }
u() { python3 -I "$PY" "$@" 2>/dev/null; }   # stdout only; the exit status is checked by set -e
# Run a command in a group of its own, killed after 5 s, so a hang cannot outlive the test.
within5() { python3 -I -c 'import os, signal, subprocess, sys
p = subprocess.Popen(sys.argv[1:], start_new_session=True)
try: sys.exit(p.wait(5))
except subprocess.TimeoutExpired: os.killpg(p.pid, signal.SIGKILL); sys.exit(124)' "$@"; }

tmp="$(mktemp -d)"
# Every write of log.sh in this file goes under $tmp, never to the real files in ~/.claude.
export REVIEW_LOOP_USAGE_FILE="$tmp/u/u.tsv" REVIEW_LOOP_USAGE_PENDING="$tmp/u/pending" REVIEW_LOOP_LOG_FILE="$tmp/l.log"
trap '[ -n "${srv:-}" ] && kill "$srv" 2>/dev/null; rm -rf "$tmp"' EXIT

# codex-limits asks Codex first (codex app-server, account/rateLimits/read). A fake codex on PATH
# answers with $FAKE_RL, or fails when it is unset; then the session logs are read.
mkdir "$tmp/bin"; cat > "$tmp/bin/codex" <<'SH'
#!/bin/sh
if [ -n "$FAKE_HANG" ]; then sleep 30 & wait; fi   # a wrapper whose child holds stdout and never answers
[ -n "$FAKE_RL" ] || exit 1
while IFS= read -r l; do
  case "$l" in *rateLimits/read*) printf '{"id":2,"result":{"rateLimits":%s}}\n' "$FAKE_RL" ;; esac
done
SH
chmod +x "$tmp/bin/codex"; export PATH="$tmp/bin:$PATH"
later=$(( $(date +%s) + 3600 ))
w() { printf '{"usedPercent":%s,"windowDurationMins":%s,"resetsAt":%s}' "$1" "$2" "$later"; }
eq "$(FAKE_RL="{\"primary\":$(w 69 300),\"secondary\":$(w 11 10080)}" CODEX_HOME="$tmp/none" u codex-limits)" "69+11" "codex-limits: asks Codex"
eq "$(FAKE_RL="{\"primary\":$(w 11 10080),\"secondary\":$(w 69 300)}" CODEX_HOME="$tmp/none" u codex-limits)" "69+11" "codex-limits: a window is known by its length, not its place"
eq "$(FAKE_RL="{\"primary\":$(w 3 10080),\"secondary\":null}" CODEX_HOME="$tmp/none" u codex-limits)" "-+3" "codex-limits: a plan without a 5-hour window gives -"
SECONDS=0; FAKE_HANG=1 CODEX_HOME="$tmp/none" u codex-limits >/dev/null
[ "$SECONDS" -lt 20 ] && pass "codex-limits: a hung codex and its children end after 10 s" || fail "codex-limits: waited ${SECONDS}s on a hung codex"
eq "$(FAKE_RL="{\"primary\":$(w 0.00001 300),\"secondary\":$(w 12.346 10080)}" CODEX_HOME="$tmp/none" u codex-limits)" "0+12.35" "codex-limits: 2 decimals, never an exponent that log.sh refuses"
mkdir -p "$tmp/h1/sessions"; printf '{"payload":{"rate_limits":{"primary":{"used_percent":10,"window_minutes":300,"resets_at":%s}}}}\n' "$later" > "$tmp/h1/sessions/rollout-a.jsonl"
eq "$(FAKE_RL="{\"primary\":{\"usedPercent\":90,\"windowDurationMins\":300,\"resetsAt\":1}}" CODEX_HOME="$tmp/h1" u codex-limits)" "N/A" "codex-limits: a stale answer of Codex is N/A, not an older log value"

# Codex cannot answer: the newest session log, its last rate_limits event.
s="$tmp/sessions/2026/10/19"; mkdir -p "$s"
ev() { printf '{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":%s,"window_minutes":300,"resets_at":%s},"secondary":{"used_percent":%s,"window_minutes":10080,"resets_at":%s}}}}\n' "$1" "$later" "$2" "$later"; }
{ ev 9 9; } > "$s/rollout-old.jsonl"; touch -t 202601010000 "$s/rollout-old.jsonl"   # POSIX -t: BSD touch has no free-form -d
{ ev 1 0; echo '{"type":"other"}'; ev 52.5 7; } > "$s/rollout-new.jsonl"
eq "$(CODEX_HOME="$tmp" u codex-limits)" "52.5+7" "codex-limits: newest file, last event"
eq "$(CODEX_HOME="$tmp/none" u codex-limits)" "N/A" "codex-limits: no session log"
echo '{"type":"session_meta"}' > "$s/rollout-fresh.jsonl"   # a session that has no token_count event yet
eq "$(CODEX_HOME="$tmp" u codex-limits)" "52.5+7" "codex-limits: a newer log without rate_limits falls back to an older log"
rm "$s/rollout-fresh.jsonl"
echo '{"type":"event_msg","payload":{"type":"token_count","rate_limits":null}}' >> "$s/rollout-new.jsonl"
eq "$(CODEX_HOME="$tmp" u codex-limits)" "52.5+7" "codex-limits: a null rate_limits line falls back to an earlier one"
echo '{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":7,"secondary":7}}}' >> "$s/rollout-new.jsonl"
eq "$(CODEX_HOME="$tmp" u codex-limits)" "52.5+7" "codex-limits: a window that is not an object falls back to an earlier event"

printf '{"type":"x","text":"\xe4\xb8' >> "$s/rollout-new.jsonl"   # a live log can end inside a UTF-8 character
eq "$(CODEX_HOME="$tmp" u codex-limits)" "52.5+7" "codex-limits: a partial UTF-8 character at the end"
printf '\n{"type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":3,"window_minutes":10080,"resets_at":%s},"secondary":null}}}\n' "$later" >> "$s/rollout-new.jsonl"   # after the cut line
eq "$(CODEX_HOME="$tmp" u codex-limits)" "-+3" "codex-limits: a log of a plan without a 5-hour window gives -"
echo '{"type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":4,"window_minutes":10080},"secondary":null}}}' >> "$s/rollout-new.jsonl"
eq "$(CODEX_HOME="$tmp" u codex-limits)" "N/A" "codex-limits: a window without a reset time gives N/A, it can be months old"

# Two sessions: the newest event by its own timestamp wins, not the newest file. A later line of
# another kind can touch a session whose last measurement is older.
mkdir -p "$tmp/h2/sessions"; tv() { printf '{"timestamp":"%s","payload":{"rate_limits":{"primary":{"used_percent":%s,"window_minutes":300,"resets_at":%s},"secondary":{"used_percent":1,"window_minutes":10080,"resets_at":%s}}}}\n' "$1" "$2" "$later" "$later"; }
tv 2026-10-19T02:00:00Z 80 > "$tmp/h2/sessions/rollout-b.jsonl"; touch -t 202601010000 "$tmp/h2/sessions/rollout-b.jsonl"
{ tv 2026-10-19T01:00:00Z 10; echo '{"timestamp":"2026-10-19T03:00:00Z","type":"user_message"}'; } > "$tmp/h2/sessions/rollout-a.jsonl"
eq "$(CODEX_HOME="$tmp/h2" u codex-limits)" "80+1" "codex-limits: the newest measurement across sessions"
ln -s "$tmp/gone" "$tmp/h2/sessions/rollout-dead.jsonl"   # removed while the logs are read
eq "$(CODEX_HOME="$tmp/h2" u codex-limits)" "80+1" "codex-limits: a log that is gone is skipped"
mkfifo "$tmp/h2/sessions/rollout-fifo.jsonl"   # a FIFO waits for a writer that never comes
eq "$(PATH=/usr/bin:/bin CODEX_HOME="$tmp/h2" within5 python3 -I "$PY" codex-limits 2>/dev/null)" "80+1" "codex-limits: a session log that is a FIFO is skipped"
rm "$tmp/h2/sessions/rollout-fifo.jsonl"
cp -R "$tmp/h2" "$tmp/h[3]"
eq "$(CODEX_HOME="$tmp/h[3]" u codex-limits)" "80+1" "codex-limits: a CODEX_HOME with glob characters"
printf '{"timestamp":"2026-10-19T04:00:00Z","payload":{"rate_limits":{"limit_id":"other","primary":{"used_percent":5,"window_minutes":300,"resets_at":%s}}}}\n' "$later" > "$tmp/h2/sessions/rollout-c.jsonl"
eq "$(CODEX_HOME="$tmp/h2" u codex-limits)" "80+1" "codex-limits: only the codex bucket of the logs"
eq "$(FAKE_RL="{\"limitId\":\"other\",\"primary\":$(w 5 300)}" CODEX_HOME="$tmp/none" u codex-limits)" "N/A" "codex-limits: only the codex bucket of Codex"

# A window whose resets_at is past: the use since the reset is not in the log (other clients share
# the meter), so the value is N/A, not 0, and no older event is taken in its place.
printf '{"type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":60,"window_minutes":300,"resets_at":1000},"secondary":{"used_percent":7,"window_minutes":10080,"resets_at":%s}}}}\n' "$later" >> "$s/rollout-new.jsonl"
eq "$(CODEX_HOME="$tmp" u codex-limits)" "N/A" "codex-limits: a reset window gives N/A"

# A fake /api/v1 that knows some generations.
cat > "$tmp/fake.py" <<'EOF'
import http.server, json, sys, time
seen = {}
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/moved/"):  # a redirect must not carry the key
            self.send_response(302); self.send_header("Location", self.path[len("/moved"):]); self.end_headers(); return
        if self.headers.get("Authorization") != "Bearer k": return self.send_error(401)
        seen[self.path] = seen.get(self.path, 0) + 1
        # gen-slow*: 404 for the first 3 requests of each id, then found.
        if self.path.startswith("/api/v1/generation?id=gen-slow") and seen[self.path] <= 3: return self.send_error(404)
        if self.path.startswith("/api/v1/generation?id=gen-slow"): body = {"data": {"total_cost": 0.25}}
        elif self.path == "/api/v1/generation?id=gen-a%26b": body = {"data": {"total_cost": 0.5}}
        elif self.path == "/api/v1/generation?id=gen-drip":  # a byte each 0.3 s: no read times out
            b = json.dumps({"data": {"total_cost": 0.1}}).encode()
            self.send_response(200); self.send_header("Content-Length", str(len(b))); self.end_headers()
            for c in b:
                self.wfile.write(bytes([c])); self.wfile.flush(); time.sleep(0.3)
            return
        elif self.path == "/api/v1/generation?id=gen-sleep":
            time.sleep(2); body = {"data": {"total_cost": 0.1}}
        elif self.path == "/api/v1/generation?id=gen-null": body = {"data": {"total_cost": None}}
        elif self.path == "/api/v1/generation?id=gen-1": body = {"data": {"total_cost": 0.01, "model": "m"}}
        elif self.path == "/api/v1/generation?id=gen-2": body = {"data": {"total_cost": 0.0025, "model": "m"}}
        else: return self.send_error(404)
        b = json.dumps(body).encode(); self.send_response(200); self.end_headers(); self.wfile.write(b)
    def log_message(self, *a): pass
s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H); s.handle_error = lambda *a: None  # a client that gave up
print(s.server_port, flush=True); s.serve_forever()
EOF
python3 -I "$tmp/fake.py" > "$tmp/port" & srv=$!
for _ in $(seq 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
export OPENROUTER_API_URL="http://127.0.0.1:$(cat "$tmp/port")/api/v1" REVIEW_LOOP_RETRY_WAIT=0.01

printf '%s\n' '{"responseId":"gen-1"}' '{"responseId":"gen-2"}' '{"responseId":"gen-1"}' > "$tmp/ok.jsonl"
printf '%s\n' '{"responseId":"gen-1"}' '{"responseId":"gen-404"}' > "$tmp/miss.jsonl"
echo '{}' > "$tmp/none.jsonl"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/ok.jsonl")" "0.012500" "cost: sum of unique generations"
[ -z "$(OPENROUTER_API_KEY=k python3 -I "$PY" cost "$tmp/ok.jsonl" 2>&1 >/dev/null)" ] && pass "cost: a found cost prints nothing else" || fail "cost: extra output beside the value"
printf '%s\n' '{"responseId":"gen-1"}' '{"responseId" : "gen-2"}' > "$tmp/spaced.jsonl"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/spaced.jsonl")" "0.012500" "cost: JSON spacing does not hide a generation"
{ cat "$tmp/ok.jsonl"; printf '{"text":"\xe4\xb8'; } > "$tmp/partial.jsonl"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/partial.jsonl")" "0.012500" "cost: a partial UTF-8 character at the end"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/miss.jsonl")" "N/A" "cost: one generation not found → N/A, not a partial sum"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/none.jsonl")" "N/A" "cost: no generation id"
printf '%s\n' '{"responseId":"gen-1"}' '{"responseId":"msg_01X"}' > "$tmp/mixed.jsonl"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/mixed.jsonl")" "N/A" "cost: an id that is not a generation id → N/A, not a partial sum"
printf '%s\n' '{"responseId":"gen-1"}' '{"responseId":""}' > "$tmp/empty-id.jsonl"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/empty-id.jsonl")" "N/A" "cost: an empty id → N/A, not a partial sum"
echo '{"responseId":"gen-sleep"}' > "$tmp/sleep.jsonl"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/sleep.jsonl")" "0.100000" "cost: a slow answer within the time limit"
eq "$(REVIEW_LOOP_TIME_LIMIT=1 OPENROUTER_API_KEY=k u cost "$tmp/sleep.jsonl")" "N/A" "cost: REVIEW_LOOP_TIME_LIMIT bounds the whole call"
echo '{"responseId":"gen-drip"}' > "$tmp/drip.jsonl"
SECONDS=0; out="$(REVIEW_LOOP_TIME_LIMIT=2 OPENROUTER_API_KEY=k u cost "$tmp/drip.jsonl")"
[ "$out" = N/A ] && [ "$SECONDS" -lt 5 ] && pass "cost: a slow drip of bytes stops at the limit" || fail "cost: drip gave [$out] after ${SECONDS}s"
# The stdlib catches OSError per address when it connects, so the timer must not raise one: here the
# first address stalls and swallows it, then the drip of the second address would run on.
SECONDS=0; out="$(cd "$(dirname "$PY")" && REVIEW_LOOP_TIME_LIMIT=2 OPENROUTER_API_KEY=k python3 -B -I -c '
import socket, sys, time
sys.path.insert(0, ".")
import usage
real = socket.create_connection
def stalled_first(*a, **k):
    try:
        time.sleep(5)
    except OSError:
        pass  # what create_connection does with an error on one address
    return real(*a, **k)
socket.create_connection = stalled_first
print(usage.main(["cost", sys.argv[1]]))' "$tmp/drip.jsonl" 2>/dev/null)"
[ "$out" = N/A ] && [ "$SECONDS" -lt 5 ] && pass "cost: no library handler can catch the time limit" || fail "cost: gave [$out] after ${SECONDS}s"
( cd "$(dirname "$PY")" && python3 -B -I -c 'import sys; sys.path.insert(0, "."); import usage, os; os.environ.pop("REVIEW_LOOP_TIME_LIMIT", None); assert 59 < usage.time_left() <= 60' ) \
  && pass "cost: 60 s for the whole call by default" || fail "cost: no default time limit"
echo '{"responseId":"gen-slow9"}' > "$tmp/slow9.jsonl"   # 404 three times
SECONDS=0; REVIEW_LOOP_RETRY_WAIT=5 REVIEW_LOOP_TIME_LIMIT=1 OPENROUTER_API_KEY=k u cost "$tmp/slow9.jsonl" >/dev/null
[ "$SECONDS" -lt 3 ] && pass "cost: a 404 wait stops at the time limit" || fail "cost: waited ${SECONDS}s past a 1 s limit"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/absent.jsonl")" "N/A" "cost: unreadable file"
eq "$(env -u OPENROUTER_API_KEY python3 -I "$PY" cost "$tmp/ok.jsonl" 2>/dev/null)" "N/A" "cost: no key"
eq "$(OPENROUTER_API_KEY=bad u cost "$tmp/ok.jsonl")" "N/A" "cost: rejected key"
err="$(OPENROUTER_API_KEY=$'secret-key\n' python3 -I "$PY" cost "$tmp/ok.jsonl" 2>&1 >/dev/null)"
case "$err" in *secret*) fail "the key reached stderr: [$err]";; *) pass "the key never reaches stderr";; esac
echo '{"responseId":"gen-1"}{"responseId":"gen-null"}' > "$tmp/null.jsonl"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/null.jsonl")" "N/A" "cost: a null total_cost → N/A, not 0"
REVIEW_LOOP_RETRY_WAIT=x OPENROUTER_API_KEY=k python3 -I "$PY" cost "$tmp/ok.jsonl" >/dev/null 2>&1 || fail "a bad retry setting exits non-zero"
eq "$(REVIEW_LOOP_RETRY_WAIT=x OPENROUTER_API_KEY=k u cost "$tmp/ok.jsonl")" "0.012500" "cost: a bad retry setting does not break the exit-0 contract"
echo '{"responseId":"gen-a&b"}' > "$tmp/amp.jsonl"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/amp.jsonl")" "0.500000" "cost: the id is quoted in the URL"
echo '{"responseId":"gen-slow0"}' > "$tmp/slow0.jsonl"
eq "$(REVIEW_LOOP_RETRY_WAIT=0 OPENROUTER_API_KEY=k u cost "$tmp/slow0.jsonl")" "N/A" "cost: no wait, no retry (usage-retry asks once)"
echo '{"responseId":"gen-slow1"}' > "$tmp/slow1.jsonl"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/slow1.jsonl")" "0.250000" "cost: retries a new generation"
echo '{"responseId":"gen-slow2"}{"responseId":"gen-slow3"}' > "$tmp/slow2.jsonl"
eq "$(OPENROUTER_API_KEY=k u cost "$tmp/slow2.jsonl")" "N/A" "cost: one retry budget for the whole call"
eq "$(OPENROUTER_API_URL="${OPENROUTER_API_URL%/api/v1}/moved/api/v1" OPENROUTER_API_KEY=k u cost "$tmp/ok.jsonl")" "N/A" "a redirect does not carry the key"
eq "$(u nonsense)" "N/A" "unknown subcommand"

# A pending directory inside a work tree is not used: usage and usage-retry remove files there.
wt="$tmp/wt"; git init -q "$wt"; mkdir "$wt/p"; echo keep > "$wt/p/r-1-pi.jsonl"; touch -t 202601010000 "$wt/p/r-1-pi.jsonl"
REVIEW_LOOP_USAGE_FILE="$tmp/wt-u.tsv" REVIEW_LOOP_USAGE_PENDING="$wt/p" bash "$(dirname "$PY")/log.sh" usage run=r round=1 reviewer=pi cost=N/A pending="$tmp/ok.jsonl"
REVIEW_LOOP_USAGE_FILE="$tmp/wt-u.tsv" REVIEW_LOOP_USAGE_PENDING="$wt/p" bash "$(dirname "$PY")/log.sh" usage-retry
eq "$(cat "$wt/p/r-1-pi.jsonl")" keep "pending: a directory inside a work tree is left alone"

# A FIFO given as an events file is not read: no writer would come.
mkfifo "$tmp/ev.fifo"
within5 bash "$(dirname "$PY")/log.sh" usage run=r round=14 reviewer=pi output=5 pending="$tmp/ev.fifo" \
  && pass "pending: a FIFO events file is not read" || fail "pending: hung on a FIFO events file"
within5 python3 -I "$PY" cost "$tmp/ev.fifo" >/dev/null 2>&1 \
  && pass "cost: a FIFO events file is not read" || fail "cost: hung on a FIFO events file"

# A row whose cost is N/A keeps its generation ids; log.sh usage-retry looks them up again later.
LOG="$(dirname "$PY")/log.sh"; T=$'\t'
export OPENROUTER_API_KEY=k
row() { bash "$LOG" usage run=r round="$1" reviewer=pi model=z-ai/glm-5.3 output=5 pending="$2" ${3:+cost=$3}; }
row 1 "$tmp/partial.jsonl"                     # events hold more than ids
row 2 "$tmp/miss.jsonl"
row 3 "$tmp/mixed.jsonl"                       # a msg_ id never gets a cost
row 4 "$tmp/ok.jsonl" 0.5                      # the cost is known
{ echo '{"responseId":"bad id"}'; seq -f '{"responseId":"gen-%g"}' 100000 150000; } > "$tmp/big.jsonl"   # a long list fills the pipe
row 7 "$tmp/big.jsonl"
eq "$(ls "$tmp/u/pending" | tr '\n' ' ')" "r-1-pi.jsonl r-2-pi.jsonl " "pending: only an N/A row of gen- ids"
eq "$(file_mode "$tmp/u/pending/r-1-pi.jsonl")" 600 "pending: mode 600"
grep -q text "$tmp/u/pending/r-1-pi.jsonl" && fail "pending: holds more than the ids" || pass "pending: ids only"
printf '%s\n' '{"responseId":"gen-1"}' '{"responseId":' ' "gen-2"}' > "$tmp/split.jsonl"   # usage.py cost reads both
row 11 "$tmp/split.jsonl"
grep -q gen-2 "$tmp/u/pending/r-11-pi.jsonl" && pass "pending: an id after a line break is kept" || fail "pending: lost an id after a line break"
rm -f "$tmp/u/pending/r-11-pi.jsonl"
printf '{"responseId":"gen-1"}{"responseId":"gen-%s"}\n' "$(printf 'x%.0s' $(seq 1100))" > "$tmp/long.jsonl"   # ll_append refuses the long id
row 12 "$tmp/long.jsonl"
[ -e "$tmp/u/pending/r-12-pi.jsonl" ] && fail "pending: kept a file without all its ids" || pass "pending: all ids or no file"
printf '%s\n' '{"responseId":"gen-1"}' > "$tmp/u/pending/r-9-pi.jsonl"; touch -t 202601010000 "$tmp/u/pending/r-9-pi.jsonl"
printf '%s\n' "p${T}r${T}8${T}pi${T}m" '{"responseId":"gen-1"}' > "$tmp/u/pending/r-8-pi.jsonl"
python3 -c 'import os, sys, time; t = time.time() - 7 * 86400 - 3600; os.utime(sys.argv[1], (t, t))' "$tmp/u/pending/r-8-pi.jsonl"
bash "$LOG" usage-retry
eq "$(ls "$tmp/u/pending" | tr '\n' ' ')" "r-2-pi.jsonl " "retry: a found cost and a file older than 7 days go, a missing one stays"
eq "$(tail -1 "$tmp/u/u.tsv" | cut -f3-)" "r${T}1${T}pi${T}z-ai%2Fglm-5.3${T}${T}${T}${T}${T}${T}0.012500${T}provider-api-late${T}${T}" "retry: a late row carries the cost"
eq "$(tail -1 "$tmp/u/u.tsv" | awk -F'\t' '{print NF}')" 15 "retry: 15 columns"
eq "$(grep -c provider-api-late "$tmp/u/u.tsv")" 1 "retry: one late row"
row 6 "$tmp/partial.jsonl"
REVIEW_LOOP_RETRY_BUDGET=0 bash "$LOG" usage-retry
[ -f "$tmp/u/pending/r-6-pi.jsonl" ] && pass "retry: no time left, no lookup" || fail "retry: looked up past its time budget"
SECONDS=0; REVIEW_LOOP_RETRY_WAIT=5 bash "$LOG" usage-retry
[ "$SECONDS" -lt 5 ] && pass "retry: no 404 wait for an old generation" || fail "retry waited ${SECONDS}s"
row 1 "$tmp/partial.jsonl"
mv "$tmp/u/u.tsv" "$tmp/u/real.tsv"; ln -s "$tmp/u/real.tsv" "$tmp/u/u.tsv"   # ll_append refuses a symlink
bash "$LOG" usage-retry
[ -f "$tmp/u/pending/r-1-pi.jsonl" ] && pass "retry: a refused row keeps the ids" || fail "retry: ids lost without a row"
rm "$tmp/u/u.tsv"; mv "$tmp/u/real.tsv" "$tmp/u/u.tsv"
# A usage file that is a FIFO is refused by ll_append, and must not be read either: a read waits
# for a writer that never comes.
mv "$tmp/u/u.tsv" "$tmp/u/real.tsv"; mkfifo "$tmp/u/u.tsv"
within5 bash "$LOG" usage run=r round=13 reviewer=pi output=5 pending="$tmp/miss.jsonl" \
  && pass "usage: a FIFO usage file is not read" || fail "usage: hung on a FIFO usage file"
rm "$tmp/u/u.tsv"; mv "$tmp/u/real.tsv" "$tmp/u/u.tsv"

# ids are kept only for a row that was written: a late row needs an earlier row to match.
mv "$tmp/u/u.tsv" "$tmp/u/real.tsv"; ln -s "$tmp/u/real.tsv" "$tmp/u/u.tsv"
row 5 "$tmp/partial.jsonl"
rm "$tmp/u/u.tsv"; mv "$tmp/u/real.tsv" "$tmp/u/u.tsv"
[ -e "$tmp/u/pending/r-5-pi.jsonl" ] && fail "pending: ids kept for a refused row" || pass "pending: no ids for a refused row"
REVIEW_LOOP_LOG=0 row 2 "$tmp/partial.jsonl"
grep -q gen-404 "$tmp/u/pending/r-2-pi.jsonl" && pass "pending: the off switch keeps earlier ids" || fail "pending: the off switch removed earlier ids"
# The same row twice in one second: with the off switch, the second call must not take the first
# row as its own and replace the ids.
row 2 "$tmp/miss.jsonl"; REVIEW_LOOP_LOG=0 row 2 "$tmp/miss.jsonl"
[ -s "$tmp/u/pending/r-2-pi.jsonl" ] && pass "pending: the off switch never removes ids" || fail "pending: the off switch removed ids"
echo ALL PASS
