#!/bin/sh
set -e

# Create runtime directories
mkdir -p /cognitiveos/run /cognitiveos/logs

# 1. Start cograw (raw model guardrail)
# If the raw model file is missing, we start in mock mode to allow the system to boot in degraded mode
if [ ! -f /cognitiveos/models/raw/raw-model.gguf ]; then
    echo "WARN: Raw model GGUF not found at /cognitiveos/models/raw/raw-model.gguf"
    echo "Starting cograw in mock mode (degraded mode)"
    /usr/local/bin/cograw --backend mock --socket /cognitiveos/run/raw.sock &
else
    /usr/local/bin/cograw --model /cognitiveos/models/raw/raw-model.gguf --socket /cognitiveos/run/raw.sock &
fi
COGRAW_PID=$!

# Wait for raw.sock to appear
for i in $(seq 1 30); do
    if [ -S /cognitiveos/run/raw.sock ]; then
        break
    fi
    sleep 0.2
done

if [ ! -S /cognitiveos/run/raw.sock ]; then
    echo "FATAL: cograw failed to start or raw.sock not created after 6s"
    exit 1
fi

# 2. Start coginfer (wide model inference)
/usr/local/bin/coginfer --backend cgo --models /cognitiveos/models &
COGINFER_PID=$!

# Wait for HTTP :11434/health to respond
for i in $(seq 1 30); do
    if wget -q --spider http://127.0.0.1:11434/health 2>/dev/null; then
        break
    fi
    sleep 0.2
done

if ! wget -q --spider http://127.0.0.1:11434/health 2>/dev/null; then
    echo "WARN: coginfer healthcheck failed after 6s, continuing in degraded mode"
fi

# 3. Start cognitiveosd (main daemon)
/usr/local/bin/cognitiveosd &
DAEMON_PID=$!

# Wait for daemon.sock to appear
for i in $(seq 1 30); do
    if [ -S /cognitiveos/run/daemon.sock ]; then
        break
    fi
    sleep 0.2
done

if [ ! -S /cognitiveos/run/daemon.sock ]; then
    echo "FATAL: cognitiveosd failed to start or daemon.sock not created after 6s"
    exit 1
fi

# 4. Exec CLI (replaces shell, becomes direct child of tini)
echo "CognitiveOS starting..."
exec /usr/local/bin/cognitiveos-cli
