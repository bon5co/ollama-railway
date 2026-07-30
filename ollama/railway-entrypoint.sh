#!/bin/sh
# Start the Ollama server, sized for the container it is actually running in,
# then pull OLLAMA_PRELOAD_MODEL behind it.
#
# Thread sizing is the thing that matters most here. A container reports the
# HOST's core count, not its own CPU quota, so llama-server auto-detects dozens
# of threads and oversubscribes a small cgroup. Measured on Railway with
# llama3.2:1b (2026-07-31): 1.11 tok/s auto-detected vs 87 tok/s with the thread
# count capped at the plan's vCPU -- a ~78x difference, on every request, for
# every model. llama-server reads LLAMA_ARG_THREADS from the environment, and
# Ollama passes its own environment through to the runner, so setting it here
# fixes every model rather than only the preloaded one.
#
# The pull runs in the background on purpose: `ollama serve` is listening within
# a second or two, so Open WebUI (or any sibling service) connects immediately
# and the model appears in the list when the download finishes. Blocking the
# server on a multi-gigabyte download would make the service look dead for the
# first few minutes of its life.
#
# Set OLLAMA_PRELOAD_MODEL to an empty string to skip the preload entirely.
# Set LLAMA_ARG_THREADS explicitly to override the detection below.
set -eu

# vCPU actually available to this container, from the cgroup quota. cgroup v2
# first, then v1; `max`/`-1` mean unlimited, in which case fall back to the
# visible core count capped at 8 -- overshooting is what costs 78x, so the
# fallback errs low.
detect_threads() {
    quota="" period=""
    if [ -r /sys/fs/cgroup/cpu.max ]; then
        quota=$(cut -d' ' -f1 /sys/fs/cgroup/cpu.max)
        period=$(cut -d' ' -f2 /sys/fs/cgroup/cpu.max)
    elif [ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -r /sys/fs/cgroup/cpu/cpu.cfs_period_us ]; then
        quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)
        period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)
    fi

    case "$quota" in
        ''|max|-1|0)
            n=$(nproc 2>/dev/null || echo 4)
            [ "$n" -gt 8 ] && n=8
            echo "$n"
            return
            ;;
    esac

    [ -n "$period" ] && [ "$period" -gt 0 ] 2>/dev/null || period=100000
    n=$((quota / period))
    [ "$n" -lt 1 ] && n=1
    echo "$n"
}

if [ -z "${LLAMA_ARG_THREADS:-}" ]; then
    LLAMA_ARG_THREADS=$(detect_threads)
    export LLAMA_ARG_THREADS
fi
echo "railway-entrypoint: LLAMA_ARG_THREADS=$LLAMA_ARG_THREADS (inference threads)"

echo "railway-entrypoint: starting ollama serve (OLLAMA_HOST=${OLLAMA_HOST:-unset})"
/bin/ollama serve &
SERVE_PID=$!

preload() {
    model="$1"
    i=0
    until /bin/ollama list >/dev/null 2>&1; do
        i=$((i + 1))
        if [ "$i" -gt 120 ]; then
            echo "railway-entrypoint: server not ready after 120s, skipping preload of $model"
            return 0
        fi
        sleep 1
    done

    if /bin/ollama list | awk 'NR > 1 { print $1 }' | grep -qx "$model"; then
        echo "railway-entrypoint: $model already on the volume, skipping pull"
        return 0
    fi

    echo "railway-entrypoint: pulling $model"
    if /bin/ollama pull "$model"; then
        echo "railway-entrypoint: $model ready"
    else
        # A failed pull must not take the server down with it -- the deployer can
        # still pull any model by hand from the UI.
        echo "railway-entrypoint: pull of $model failed; server stays up, pull manually from the UI"
    fi
}

if [ -n "${OLLAMA_PRELOAD_MODEL:-}" ]; then
    preload "$OLLAMA_PRELOAD_MODEL" &
else
    echo "railway-entrypoint: OLLAMA_PRELOAD_MODEL is empty, no model preloaded"
fi

wait "$SERVE_PID"
