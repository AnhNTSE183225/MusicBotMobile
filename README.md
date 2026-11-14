# MusicBotMobile

Ultra-low overhead 120Hz Impeller + Dart AOT mobile client for **MusicBot** (Backend) and **MusicBotUI** (Frontend).

## AI Engineering & Tech Stack Mandate

> [!IMPORTANT]
> Any AI assistant working in this repository **MUST** read and follow the **TECHSTACK AI Guide** (`VIBE_CODING_RULES.md` and `MOBILE_TECHSTACK.md`) on every prompt:
> - **Local Path (if available):** `C:\GIT\TECHSTACK\` (`../techstack/`)
> - **Canonical GitHub Repository (fallback):** [https://github.com/AnhNTSE183225/techstack](https://github.com/AnhNTSE183225/techstack)
>   - `https://raw.githubusercontent.com/AnhNTSE183225/techstack/main/VIBE_CODING_RULES.md`
>   - `https://raw.githubusercontent.com/AnhNTSE183225/techstack/main/MOBILE_TECHSTACK.md`

See [GEMINI.md](./GEMINI.md) and [CLAUDE.md](./CLAUDE.md) for the always-on workspace rule definitions.

## 6-Script Lifecycle

Configure the target environment in [.env](./.env) (`PROFILE=PROD` or `PROFILE=DEV`, defaults to `PROD`):

| Operation | Windows (PowerShell) | Linux / macOS (Bash) |
| :--- | :--- | :--- |
| **Build, Codegen, Analyze, Test & Package APK** | `.\build.ps1` | `./build.sh` |
| **Fast Codegen + Analyze + Test (Skip APK)** | `.\build.ps1 -SkipApk` | `./build.sh --skip-apk` |
| **Deploy & Launch on Connected Device / Emulator** | `.\start.ps1` | `./start.sh` |
| **Stop Active Runner Process Tree** | `.\stop.ps1` | `./stop.sh` |
