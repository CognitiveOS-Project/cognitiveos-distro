#!/bin/sh
set -eu

# Log helper
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S')] $1"
}

log "Starting CognitiveOS entrypoint..."

# Create runtime directories
mkdir -p /cognitiveos/run /cognitiveos/logs
log "Created runtime directories"

# 1. Start cograw (raw model guardrail)
if [ ! -f /cognitiveos/models/raw/raw-model.gguf ]; then
    log "Raw model GGUF not found. Starting cograw in mock mode (degraded)."
    /usr/local/bin/cograw --backend mock --socket /cognitiveos/run/raw.sock &
else
    log "Raw model GGUF found. Starting cograw in production mode."
    /usr/local/bin/cograw --model /cognitiveos/models/raw/raw-model.gguf --socket /cognitiveos/run/raw.sock &
fi
COGRAW_PID=$!

# Wait for raw.sock to appear
log "Waiting for raw.sock..."
COUNT=0
while [ ! -S /cognitiveos/run/raw.sock ] && [ $COUNT -lt 30 ]; do
    sleep 0.2
    COUNT=$((COUNT+1))
done

if [ ! -S /cognitiveos/run/raw.sock ]; then
    log "FATAL: cograw failed to start or raw.sock not created after 6s"
    exit 1
fi
log "raw.sock is ready"

# 2. Start coginfer (wide model inference)
log "Starting coginfer..."
/usr/local/bin/coginfer --backend cgo --models /cognitiveos/models &
COGINFER_PID=$!

# Wait for HTTP :11434/health to respond
log "Waiting for coginfer health check..."
COUNT=0
while true; do
    if wget -q --spider http://127.0.0.1:11434/health 2>/dev/null; then
        break
    fi
    if [ $COUNT -ge 30 ]; then
        log "WARN: coginfer healthcheck failed after 6s, continuing in degraded mode"
        break
    fi
    sleep 0.2
    COUNT=$((COUNT+1))
done
log "coginfer is ready (or timed out)"

# 3. Start cognitiveosd (main daemon)
log "Starting cognitiveosd..."
/usr/local/bin/cognitiveosd &
DAEMON_PID=$!

# Wait for daemon.sock to appear
log "Waiting for daemon.sock..."
COUNT=0
while [ ! -S /cognitiveos/run/daemon.sock ] && [ $COUNT -lt 30 ]; do
    sleep 0.2
    COUNT=$((COUNT+1))
done

if [ ! -S /cognitiveos/run/daemon.sock ]; then
    log "FATAL: cognitiveosd failed to start or daemon.sock not created after 6s"
    exit 1
fi
log "daemon.sock is ready"

# 4. Exec CLI (replaces shell, becomes direct child of tini)
log "Launching cognitiveos-cli..."
exec /usr/local/bin/cognitiveos-cli
