#!/bin/sh
# Start the Ollama server, then pull OLLAMA_PRELOAD_MODEL behind it.
#
# The pull runs in the background on purpose: `ollama serve` is listening within
# a second or two, so Open WebUI (or any sibling service) connects immediately
# and the model simply appears in the list when the download finishes. Blocking
# the server on a multi-gigabyte download instead would make the service look
# dead for the first few minutes of its life.
#
# Set OLLAMA_PRELOAD_MODEL to an empty string to skip the preload entirely.
set -eu

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
