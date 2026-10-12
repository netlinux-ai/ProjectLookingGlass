#!/bin/bash
# Run the Java Looking Glass desktop in a nested Xephyr window on the current desktop.
# Usage: ./run-lg3d-nested-demo.sh [-s WxH] [-d :N] [app ...]
# Close the Xephyr window or press Ctrl+C to stop; only processes started here are killed.
set -u
cd "$(cd "$(dirname "$0")" && pwd)"
size=960x540
disp=""
while getopts "s:d:h" o; do
    case $o in
        s) size=$OPTARG ;;
        d) disp=$OPTARG ;;
        *) sed -n '2,4p' "$0"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))
apps=("$@")
[ ${#apps[@]} -eq 0 ] && apps=(xterm xclock xeyes)

export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}
[ -n "${DISPLAY:-}" ] || { echo "DISPLAY not set; run from your desktop"; exit 1; }
command -v Xephyr >/dev/null || { echo "Xephyr not installed"; exit 1; }
host=$DISPLAY

if [ -z "$disp" ]; then
    n=30
    while [ -e "/tmp/.X11-unix/X$n" ] || [ -e "/tmp/.X$n-lock" ]; do n=$((n + 1)); done
    disp=:$n
fi

pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; }
trap cleanup EXIT INT TERM

DISPLAY=$host Xephyr "$disp" -screen "$size" -glamor -ac -nolisten tcp -title lg3d-xephyr &
xpid=$!; pids+=("$xpid")
for _ in $(seq 50); do [ -e "/tmp/.X11-unix/X${disp#:}" ] && break; sleep 0.1; done

# Gradle's JVM must run against the host display's Java toolkit settings; the
# compositor itself is told which nested display to manage.
DISPLAY=$host ./run-lg3d.sh --nested "$disp" &
pids+=("$!")

echo "Waiting for the compositor (first run compiles; can take a minute)..."
for _ in $(seq 180); do
    DISPLAY=$disp xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q "window id" && break
    sleep 1
done
for a in "${apps[@]}"; do
    DISPLAY=$disp setsid $a >/dev/null 2>&1 &
    pids+=("$!")
    sleep 0.5
done
echo "Java Looking Glass running on $disp (close the Xephyr window or Ctrl+C to stop)"
wait "$xpid"
