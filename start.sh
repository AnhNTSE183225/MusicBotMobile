#!/usr/bin/env bash
# ==============================================================================
# Fast Production Runner (Bash / Linux / macOS) — MusicBotMobile
# ==============================================================================
# Launches pre-compiled release target and persists PID in .pids for ./stop.sh.
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$ROOT_DIR/.pids"
STOP_SCRIPT="$ROOT_DIR/stop.sh"
BUILD_SCRIPT="$ROOT_DIR/build.sh"
MOBILE_PORT="${MOBILE_PORT:-8090}"

export PATH="$HOME/flutter/bin:$PATH"

if [ -f "$STOP_SCRIPT" ]; then
    bash "$STOP_SCRIPT" --quiet || true
fi

if [ ! -f "$ROOT_DIR/lib/core/database/app_database.g.dart" ]; then
    echo "Generated artifacts missing. Running ./build.sh --skip-apk first..."
    bash "$BUILD_SCRIPT" --skip-apk
fi

echo "Starting MusicBotMobile in 100% Optimized Release Mode..."
(cd "$ROOT_DIR" && nohup flutter run --release --dart-define-from-file=config/prod.json > "$ROOT_DIR/.mobile.log" 2>&1 &)
sleep 0.2
MOBILE_PID=$(pgrep -f "flutter_tools" | head -n 1 || echo "")

cat > "$PID_FILE" <<EOF
MOBILE_PID=$MOBILE_PID
MOBILE_PORT=$MOBILE_PORT
STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "  [PID State] Stored PID in $PID_FILE (Mobile PID: $MOBILE_PID)"
echo "  Run ./stop.sh to stop the runner process tree."
