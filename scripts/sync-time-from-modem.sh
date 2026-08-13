#!/bin/sh
set -u

PORT="$(uci -q get vpnmode.main.modem_at_port || true)"
OUTPUT='/tmp/dualvpn-modem-clock.txt'
LOCK='/tmp/dualvpn-modem-clock.lock'

[ -n "$PORT" ] || { echo 'modem_at_port is not configured.' >&2; exit 1; }
mkdir "$LOCK" 2>/dev/null || exit 0
reader_pid=''

cleanup() {
    [ -z "$reader_pid" ] || kill "$reader_pid" 2>/dev/null || true
    [ -z "$reader_pid" ] || wait "$reader_pid" 2>/dev/null || true
    rm -f "$OUTPUT"
    rmdir "$LOCK" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

attempt=0
timestamp=''
while [ "$attempt" -lt 8 ]; do
    attempt=$((attempt + 1))
    [ -c "$PORT" ] || { sleep 3; continue; }
    stty -F "$PORT" raw -echo -echoe -echok -echoctl -echoke 2>/dev/null || { sleep 3; continue; }
    rm -f "$OUTPUT"
    cat "$PORT" >"$OUTPUT" &
    reader_pid=$!
    sleep 1
    printf 'AT+CCLK?\r' >"$PORT"
    sleep 2
    kill "$reader_pid" 2>/dev/null || true
    wait "$reader_pid" 2>/dev/null || true
    reader_pid=''
    clock_line="$(grep -m1 '^+CCLK:' "$OUTPUT" 2>/dev/null || true)"
    timestamp="$(printf '%s\n' "$clock_line" | sed -n 's/.*"\([0-9][0-9]\)\/\([0-9][0-9]\)\/\([0-9][0-9]\),\([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\).*/20\1-\2-\3 \4:\5:\6/p')"
    [ -n "$timestamp" ] && break
    sleep 3
done

[ -n "$timestamp" ] || { logger -t dualvpn-clock "Could not read AT+CCLK from $PORT"; exit 1; }
date -u -s "$timestamp" >/dev/null || exit 1
logger -t dualvpn-clock "System UTC initialized from modem clock on $PORT"
