#!/usr/bin/env bash
# ==============================================================================
# Fast Production Runner (Bash / Linux / macOS) — MusicBotMobile
# ==============================================================================
# Launches pre-compiled release target and persists PID in .pids for ./stop.sh.
# ==============================================================================

set -euo pipefail

# Default environment profile when neither PROFILE nor .env is set (DEV | PROD)
DEFAULT_PROFILE="PROD"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$ROOT_DIR/.pids"
STOP_SCRIPT="$ROOT_DIR/stop.sh"
BUILD_SCRIPT="$ROOT_DIR/build.sh"
ENV_FILE="$ROOT_DIR/.env"
MOBILE_PORT="${MOBILE_PORT:-8090}"

RESOLVED_PROFILE="${PROFILE:-}"
if [ -z "$RESOLVED_PROFILE" ] && [ -f "$ENV_FILE" ]; then
    RESOLVED_PROFILE=$(grep -E '^\s*PROFILE\s*=' "$ENV_FILE" | head -n 1 | sed -E 's/^\s*PROFILE\s*=\s*([^[:space:]#]+).*/\1/' | tr '[:lower:]' '[:upper:]' || true)
fi
RESOLVED_PROFILE="${RESOLVED_PROFILE:-$DEFAULT_PROFILE}"

if [ "$RESOLVED_PROFILE" = "PROD" ] || [ "$RESOLVED_PROFILE" = "PRODUCTION" ]; then
    CONFIG_FILE="config/prod.json"
else
    CONFIG_FILE="config/default.json"
fi

export PATH="$HOME/flutter/bin:$PATH"

if [ -f "$STOP_SCRIPT" ]; then
    bash "$STOP_SCRIPT" --quiet || true
fi

if [ ! -f "$ROOT_DIR/lib/core/database/app_database.g.dart" ]; then
    echo "Generated artifacts missing. Running ./build.sh --skip-apk first..."
    bash "$BUILD_SCRIPT" --skip-apk
fi

echo "Starting MusicBotMobile in 100% Optimized Release Mode (Profile: $RESOLVED_PROFILE -> $CONFIG_FILE)..."
(cd "$ROOT_DIR" && nohup flutter run --release --dart-define-from-file="$CONFIG_FILE" > "$ROOT_DIR/.mobile.log" 2>&1 &)
sleep 0.2
MOBILE_PID=$(pgrep -f "flutter_tools" | head -n 1 || echo "")

cat > "$PID_FILE" <<EOF
MOBILE_PID=$MOBILE_PID
MOBILE_PORT=$MOBILE_PORT
STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "  [PID State] Stored PID in $PID_FILE (Mobile PID: $MOBILE_PID)"
echo "  Run ./stop.sh to stop the runner process tree."
