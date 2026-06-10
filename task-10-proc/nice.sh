#!/usr/bin/env bash

set -euo pipefail

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

HASH_MB="${HASH_MB:-2048}"
CPU="${CPU:-0}"
NICE_A="${NICE_A:-0}"
NICE_B="${NICE_B:-19}"
LOG_FILE="${LOG_FILE:-./process_nice_$(date +%Y%m%d_%H%M%S).log}"

: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

for cmd in taskset nice dd sha256sum awk date ps nproc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: command not found: $cmd"
        exit 1
    fi
done

if (( CPU >= $(nproc) )); then
    echo "ERROR: CPU $CPU does not exist. Available CPUs: 0..$(( $(nproc) - 1 ))"
    exit 1
fi

run_workload() {
    local name="$1"
    local hash_mb="$2"
    local cpu="$3"

    local start_ns
    local end_ns
    local elapsed
    local rc
    local current_nice

    current_nice="$(ps -o ni= -p "$$" | tr -d ' ')"

    echo "[$(date '+%F %T')] START name=$name pid=$$ nice=$current_nice cpu=$cpu hash_mb=$hash_mb"

    start_ns="$(date +%s%N)"

    set +e
    set -o pipefail
    dd if=/dev/zero bs=1M count="$hash_mb" status=none | sha256sum >/dev/null
    rc=$?
    set -e

    end_ns="$(date +%s%N)"

    elapsed="$(awk -v s="$start_ns" -v e="$end_ns" 'BEGIN { printf "%.3f", (e - s) / 1000000000 }')"

    echo "[$(date '+%F %T')] END   name=$name pid=$$ nice=$current_nice rc=$rc elapsed=${elapsed}s"

    exit "$rc"
}

export -f run_workload

echo "=== CPU nice competition test ==="
echo "Date: $(date '+%F %T')"
echo "CPU count: $(nproc)"
echo "Forced CPU: $CPU"
echo "Workload size: ${HASH_MB} MiB per process"
echo "Process A nice: $NICE_A"
echo "Process B nice: $NICE_B"
echo "Log file: $LOG_FILE"
echo

taskset -c "$CPU" nice -n "$NICE_A" bash -c 'run_workload "$@"' _ "process_A" "$HASH_MB" "$CPU" &
PID_A=$!

taskset -c "$CPU" nice -n "$NICE_B" bash -c 'run_workload "$@"' _ "process_B" "$HASH_MB" "$CPU" &
PID_B=$!

echo "Started processes:"
echo "process_A pid=$PID_A nice=$NICE_A"
echo "process_B pid=$PID_B nice=$NICE_B"
echo

sleep 1

echo "Process state during execution:"
ps -o pid,ppid,ni,pri,stat,psr,pcpu,comm,args -p "$PID_A,$PID_B" || true
echo

RC_A=0
RC_B=0

wait "$PID_A" || RC_A=$?
wait "$PID_B" || RC_B=$?

echo
echo "=== Result ==="
echo "process_A rc=$RC_A nice=$NICE_A"
echo "process_B rc=$RC_B nice=$NICE_B"
echo "Log saved to: $LOG_FILE"

if (( RC_A != 0 || RC_B != 0 )); then
    exit 1
fi