# Mandatory AI Engineering & Tech Stack Rules (Always-On)

> [!IMPORTANT]
> **BEFORE RESPONDING TO ANY PROMPT OR MODIFYING ANY CODE IN THIS REPOSITORY:**
> You **MUST** load and strictly follow the **TECHSTACK AI Guide** (`VIBE_CODING_RULES.md` and `MOBILE_TECHSTACK.md`).

## 1. Where to Load the TECHSTACK Rules (Local First, Remote Fallback)

On **every session/prompt**, check for the TECHSTACK rules in the following order:

1. **Local Path (Fastest if present on machine):**
   - `C:\GIT\TECHSTACK\VIBE_CODING_RULES.md` and `C:\GIT\TECHSTACK\MOBILE_TECHSTACK.md` (or `../techstack/` / `../TECHSTACK/`).
2. **Remote GitHub Repository (Mandatory fallback when local folder is not present):**
   - **Repository:** [https://github.com/AnhNTSE183225/techstack](https://github.com/AnhNTSE183225/techstack)
   - Fetch or read directly before writing code:
     - `https://raw.githubusercontent.com/AnhNTSE183225/techstack/main/VIBE_CODING_RULES.md`
     - `https://raw.githubusercontent.com/AnhNTSE183225/techstack/main/MOBILE_TECHSTACK.md`
   - Or clone into a temporary directory if skills/scripts are needed:
     ```bash
     git clone --depth 1 https://github.com/AnhNTSE183225/techstack.git
     ```

## 2. Core Non-Negotiable Architecture Invariants (Summary)

- **6-Script Lifecycle Mandate:** Keep `build.ps1`, `start.ps1`, `stop.ps1`, `build.sh`, `start.sh`, and `stop.sh` at the repository root. After any code change, run `.\build.ps1` (or `./build.sh`) and verify exit code `0`.
- **Fine-Grained Reactivity (`signals_flutter`):** Zero `setState` at page roots. Use `signal()`, `computed()`, and leaf `Watch(...)` / `RepaintBoundary` widgets.
- **Deterministic Finite State Machine (`EntityStatus`):** Every stateful entity uses `StatefulEntityController<T>` with a singular status discriminant (`disconnected | idle | loading | active | paused | error`), atomic teardown on resting/fault states, and `WidgetsBindingObserver` OS lifecycle reconciliation.
- **Zero Runtime Reflection & Background Isolate Persistence:** All JSON DTOs use `json_serializable` (`build_runner`), payloads > 10 KB decode via `Isolate.run`, and local SQLite persistence uses `Drift` (`NativeDatabase.createInBackground` in WAL mode).
- **Visual & Responsive Standards:** Minimum `11px` font size everywhere, `Cubic(0.16, 1.0, 0.3, 1.0)` (`300ms`) sliding active tab pills, 4px translucent scrollbars, and zero `RenderFlex` overflow across all viewports (`375x667`, `390x844`, `844x390`, `768x1024`, `1024x768`).
- **Release Notes Rule:** Every time a new user-facing feature is added, bump the version and add a new entry at the top of `kPatchNotes` in `lib/models/music_models.dart` (unless the user explicitly asks to update the current version entry in place).
