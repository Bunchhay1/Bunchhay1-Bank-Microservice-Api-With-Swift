#!/usr/bin/env bash
# =============================================================================
# Titan Banking — Stop Local Stack
# =============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Stopping microservices running on Mac host..."

# Kill by PID if present
for pidfile in "$DIR/logs/"*.pid; do
    if [ -f "$pidfile" ]; then
        pid=$(cat "$pidfile")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Killing process $pid from $pidfile..."
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$pidfile"
    fi
done

# Also kill by listening port to ensure nothing hangs
for port in 8080 8084 8083 8088; do
    pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
    if [ -n "$pids" ]; then
        echo "Killing processes listening on port $port: $pids"
        kill -9 $pids 2>/dev/null || true
    fi
done

echo "Microservices stopped."

if [ "$1" == "--all" ]; then
    echo "Stopping Docker infrastructure..."
    docker stop titan-postgres titan-redis titan-kafka 2>/dev/null || true
    echo "Docker containers stopped."
fi
