#!/usr/bin/env python3
"""usage.py — read the usage values of a review round from outside sources.

  usage.py codex-limits          5-hour and 7-day Codex usage percent, as <5h>+<7d>;
                                 - for a window that the plan does not have
  usage.py cost <file>...        net OpenRouter cost of the generations named in the files

Each command prints one value, or N/A when it cannot get the value, and exits 0: a missing
value never stops the loop. The script writes no file; log.sh is the only writer.
"""
import glob, json, os, re, signal, subprocess, sys, threading, time, urllib.error, urllib.parse, urllib.request

API = os.environ.get("OPENROUTER_API_URL", "https://openrouter.ai/api/v1")
# A new generation often returns 404 for some seconds, so a lookup tries again. One budget of
# retries covers the whole call, so a file of many new generations waits RETRIES * wait() at most.
RETRIES = 5
START = time.monotonic()


def wait():
    # Read here, not at import: a bad value must not stop the commands that never wait.
    try:
        return float(os.environ.get("REVIEW_LOOP_RETRY_WAIT", "5"))
    except ValueError:
        return 5.0


def time_left():
    # REVIEW_LOOP_TIME_LIMIT bounds the whole call: 60 s by default, so that many generations
    # cannot hold a round for long; log.sh usage-retry gives what is left of its own budget.
    try:
        limit = float(os.environ.get("REVIEW_LOOP_TIME_LIMIT", "60"))
    except ValueError:
        limit = 60.0
    return limit - (time.monotonic() - START)


def get(path):
    key = os.environ["OPENROUTER_API_KEY"]  # KeyError → N/A
    req = urllib.request.Request(API + path)
    # Unredirected: urllib copies normal headers to a redirect target, which can be another host.
    req.add_unredirected_header("Authorization", f"Bearer {key}")
    left = time_left()
    if left <= 0:
        raise TimeoutError
    with urllib.request.urlopen(req, timeout=min(30, left)) as r:
        return json.load(r)["data"]


class Stale(Exception):
    """A window has reset since the value was read; not a LookupError, so no older value is tried."""


def limits(windows, used, length, resets):
    # A window is known by its length, not its place: from 2026-07-12 to late August Plus had only
    # the weekly window, in "primary", and Pro still has no 5-hour window.
    by_length = {w[length]: w for w in windows if isinstance(w, dict)}
    if not by_length.keys() & {300, 10080}:
        raise LookupError

    def percent(w):
        if w is None:
            return "-"
        # A value can be older than its window. The use since the reset is not known (other
        # clients share the meter), and 0 would only be a lower bound that looks measured.
        # A window without a reset time cannot show its age, so it counts as stale too.
        if (w.get(resets) or 0) < time.time():
            raise Stale
        return f"{round(w[used], 2):g}"  # :g alone gives 1e-05, which log.sh refuses

    return f"{percent(by_length.get(300))}+{percent(by_length.get(10080))}"


def codex_ask():
    # The harness knows its own usage, so it is asked first. app-server is marked experimental.
    # A group of its own: codex can be a wrapper (an npm install) whose child holds stdout, and
    # killing only the wrapper would leave the read below waiting for that child.
    p = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, text=True, start_new_session=True)

    def kill():
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except OSError:
            pass  # already gone

    timer = threading.Timer(10, kill)
    timer.start()
    try:
        for m in ({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                   "params": {"clientInfo": {"name": "review-loop", "version": "0"}}},
                  {"jsonrpc": "2.0", "method": "initialized"},
                  {"jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read"}):
            p.stdin.write(json.dumps(m) + "\n")
        p.stdin.flush()  # stdin stays open: the server stops without an answer when it closes
        for line in p.stdout:
            m = json.loads(line)
            if m.get("id") == 2:
                # rateLimits is the single-bucket view; take the bucket of the codex meter.
                result = m["result"]
                rl = (result.get("rateLimitsByLimitId") or {}).get("codex") or result["rateLimits"]
                if rl.get("limitId") not in (None, "codex"):
                    raise LookupError
                return limits((rl.get("primary"), rl.get("secondary")), "usedPercent", "windowDurationMins", "resetsAt")
        raise LookupError
    finally:
        timer.cancel()
        kill()
        p.wait()


def mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return 0  # removed since the glob; the read below skips it


def codex_logs():
    home = os.environ.get("CODEX_HOME", os.path.expanduser("~/.codex"))
    logs = sorted(glob.glob(f"{glob.escape(home)}/sessions/**/rollout-*.jsonl", recursive=True), key=mtime)
    keys = ("used_percent", "window_minutes", "resets_at")
    # The value can be one call old. Only the codex meter counts (limit_id). Each log gives its last
    # usable event, and the newest by its own timestamp wins: the mtime of a log also moves with
    # lines of other kinds, and a session that has just started has no rate_limits event yet.
    best = None
    for log in reversed(logs):  # newest file first, so it wins a tie
        if not os.path.isfile(log):
            continue  # a FIFO waits for a writer that never comes
        try:
            lines = open(log, errors="replace").read().splitlines()
        except OSError:
            continue  # removed or renamed since the glob
        for line in reversed(lines):
            if '"rate_limits"' not in line:
                continue
            try:
                event = json.loads(line)
                rl = event["payload"]["rate_limits"]
                if rl.get("limit_id") not in (None, "codex"):
                    continue  # another meter
                windows = (rl.get("primary"), rl.get("secondary"))
                try:
                    limits(windows, *keys)
                except Stale:
                    pass  # usable; it gives N/A only if it is the newest
            except (AttributeError, KeyError, LookupError, TypeError, ValueError):
                continue  # a null or partial event; an earlier one can still hold the windows
            stamp = str(event.get("timestamp") or "")
            if best is None or stamp > best[0]:
                best = (stamp, windows)
            break
    if best is None:
        raise LookupError
    return limits(best[1], *keys)


def codex_limits():
    # Ask the harness; when it cannot answer, read its session logs; else N/A.
    try:
        return codex_ask()
    except Stale:
        raise  # the logs are older than this answer
    except Exception:
        return codex_logs()


class Deadline(BaseException):
    """The time limit of the call. Not an OSError: the stdlib catches OSError per address when it
    connects, and would go on to the next address with no limit left."""


def timed_out(*_):
    raise Deadline


def cost(files):
    # A timer for the whole call: the urlopen timeout covers each read, not a server that sends a
    # byte at a time, nor the DNS lookup.
    left = time_left()
    if left <= 0:
        raise TimeoutError
    signal.signal(signal.SIGALRM, timed_out)
    signal.setitimer(signal.ITIMER_REAL, left)
    try:
        return lookup(files)
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)


def lookup(files):
    if not all(os.path.isfile(f) for f in files):
        raise LookupError  # a FIFO waits for a writer that never comes
    ids = sorted({m for f in files for m in re.findall(r'"responseId"\s*:\s*"([^"]*)"', open(f, errors="replace").read())})
    # Only a gen- id has a generation record (an Anthropic model gives msg_ ids); a sum that
    # skips the others is a partial sum.
    if not ids or any(not i.startswith("gen-") for i in ids):
        raise LookupError
    total, retries = 0.0, RETRIES
    for gid in ids:
        while True:
            try:
                d = get(f"/generation?id={urllib.parse.quote(gid, safe='')}")
                break
            except urllib.error.HTTPError as e:
                if e.code != 404 or retries == 0 or wait() <= 0:  # asking again at once gets the same 404
                    raise  # a sum without one generation is a wrong number, not a lower one
                retries -= 1
                time.sleep(min(wait(), max(0, time_left())))  # get() then stops at the limit
        if d.get("total_cost") is None:
            raise LookupError(f"{gid} has no total_cost")
        total += d["total_cost"]
    return f"{total:.6f}"  # USD to a millionth; a smaller cost reads 0.000000


def main(argv):
    cmds = {"codex-limits": codex_limits}
    try:
        if argv[:1] == ["cost"]:
            return cost(argv[1:])
        return cmds[argv[0]]()
    except (Exception, Deadline) as e:
        # The type and the HTTP status only: the text of an error can hold the request header,
        # and with it the key (a key with a trailing newline gives "Invalid header value").
        print("usage.py:", type(e).__name__, getattr(e, "code", ""), file=sys.stderr)
        return "N/A"


if __name__ == "__main__":
    print(main(sys.argv[1:]))
