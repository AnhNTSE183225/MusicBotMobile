#!/usr/bin/env bash
# ==============================================================================
# Zero-Assumption Production Build Script (Bash / Linux / macOS) — MusicBotMobile
# ==============================================================================
# Enforces VIBE_CODING_RULES.md & MOBILE_TECHSTACK.md:
#   1. Pre-build service stop via ./stop.sh
#   2. Zero-Assumption Environment & Toolchain Checklist (Git, Java JDK 17+,
#      Flutter SDK & Dart AOT Toolchain)
#   3. Full Production Build (pub get, build_runner codegen, flutter analyze,
#      flutter test, and Flutter AOT Release APK)
# ==============================================================================

set -euo pipefail

CLEAN=0
INCLUDE_MOBILE=0
SKIP_APK=0

for arg in "$@"; do
    case "$arg" in
        --clean)          CLEAN=1 ;;
        --include-mobile) INCLUDE_MOBILE=1 ;;
        --skip-apk)       SKIP_APK=1 ;;
    esac
done

# Default environment profile when neither PROFILE nor .env is set (DEV | PROD)
DEFAULT_PROFILE="PROD"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOP_SCRIPT="$ROOT_DIR/stop.sh"
ENV_FILE="$ROOT_DIR/.env"

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

throw_missing_dep() {
    local dep_name="$1"
    local purpose="$2"
    local download_url="$3"
    local install_cmd="$4"
    echo ""
    echo "=================================================================="
    echo " [✖] FATAL: MISSING REQUIRED BUILD ENVIRONMENT DEPENDENCY"
    echo "=================================================================="
    echo "  Missing Component : $dep_name"
    echo "  Required For      : $purpose"
    echo "  Download URL      : $download_url"
    echo "  Manual Command    : $install_cmd"
    echo "=================================================================="
    exit 1
}

echo ""
echo "=================================================================="
echo "     MUSICBOTMOBILE ZERO-ASSUMPTION PRODUCTION BUILD (LINUX)"
echo "=================================================================="
echo ""

echo "[Phase 0] Running Zero-Assumption Toolchain & Dependency Checklist..."

if ! command -v git &>/dev/null; then
    throw_missing_dep \
        "git" \
        "Fetching toolchains and repository dependencies" \
        "https://git-scm.com/downloads" \
        "sudo apt update && sudo apt install -y git curl"
fi
echo "  [✔] git verified: $(git --version)"

if ! command -v java &>/dev/null; then
    throw_missing_dep \
        "Java Development Kit (OpenJDK 17+)" \
        "Android Gradle build system and APK signing" \
        "https://adoptium.net/" \
        "sudo apt install -y openjdk-17-jdk"
fi
echo "  [✔] Java JDK verified"

if ! command -v flutter &>/dev/null; then
    if [ ! -d "$HOME/flutter" ]; then
        echo "  [⚙ AUTO-INSTALL] Cloning Flutter stable SDK to $HOME/flutter..."
        git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter" || true
        export PATH="$HOME/flutter/bin:$PATH"
    fi
    if ! command -v flutter &>/dev/null; then
        throw_missing_dep \
            "Flutter SDK & Dart AOT Toolchain" \
            "Compiling 120Hz Impeller ARM64 mobile binaries" \
            "https://docs.flutter.dev/get-started/install/linux" \
            "git clone https://github.com/flutter/flutter.git -b stable \$HOME/flutter && export PATH=\"\$PATH:\$HOME/flutter/bin\""
    fi
fi
echo "  [✔] Flutter SDK verified"
echo ""

echo "[Phase 1] Ensuring running services are stopped before compilation..."
if [ -f "$STOP_SCRIPT" ]; then
    bash "$STOP_SCRIPT" --quiet || true
fi

cd "$ROOT_DIR"

if [ "$CLEAN" -eq 1 ]; then
    echo "[Phase 2] Cleaning previous build artifacts..."
    flutter clean
fi

echo "[Phase 3] Resolving dependencies and running compile-time codegen..."
flutter pub get
dart run build_runner build --delete-conflicting-outputs

echo "[Phase 4] Running static analysis and automated tests..."
flutter analyze --no-pub
flutter test --no-pub

if [ "$SKIP_APK" -eq 0 ] && [ "$INCLUDE_MOBILE" -eq 1 ] && [ -d "$ROOT_DIR/android" ]; then
    echo "[Phase 5] Building Mobile (Flutter AOT Release APK, Profile: $RESOLVED_PROFILE -> $CONFIG_FILE)..."
    flutter build apk --release --split-per-abi --dart-define-from-file="$CONFIG_FILE"
    echo "  [✔] Mobile ARM64 Release APK built successfully!"
fi

echo "=================================================================="
echo "       PRODUCTION BUILD COMPLETED SUCCESSFULLY!"
echo "=================================================================="
echo "  Start Application : ./start.sh"
echo "  Stop Application  : ./stop.sh"
echo ""
