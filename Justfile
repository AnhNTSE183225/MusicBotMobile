# Full Zero-Assumption build (includes mobile AOT release APK)
build:
    powershell -ExecutionPolicy Bypass -File ./build.ps1 -IncludeMobile

# Run in Profile mode (AOT native performance + 120Hz DevTools frame tracing)
profile:
    flutter run --profile --dart-define-from-file=config/default.json

# Run in full Release mode on connected device (true production performance)
run-release:
    flutter run --release --dart-define-from-file=config/default.json

# Compile-time code generation (Drift SQLite + JSON DTOs)
codegen:
    dart run build_runner build --delete-conflicting-outputs

# Build ultra-compact, ABI-split, symbol-stripped ARM64 production APK
build-apk: codegen
    flutter build apk --release \
      --split-per-abi \
      --obfuscate \
      --split-debug-info=build/symbols \
      --dart-define-from-file=config/prod.json

# Build production Android App Bundle (AAB) for Play Store
build-aab: codegen
    flutter build appbundle --release \
      --obfuscate \
      --split-debug-info=build/symbols \
      --dart-define-from-file=config/prod.json
