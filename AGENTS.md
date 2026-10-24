# AVIS Mobile Project Guidelines & AI Agent Rules

## 1. Mandatory Version Backup Protocol
- **Rule**: Whenever any new feature, redesign, or code change is planned and approved, the AI agent **MUST ALWAYS** archive a complete snapshot backup of the current stable mobile version before modifying project code.
- **Backup Location**: `backups/v<CURRENT_VERSION>_mobile/` (e.g. `backups/v3.5.0_mobile/`).
- **Files/Folders to Archive**:
  - `lib/` (all Dart source code: `main.dart`, `core/`, `widgets/`, `views/`)
  - `android/` (`build.gradle.kts`, `MainActivity.kt`, `AndroidManifest.xml`)
  - `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `build_mobile.ps1`, `README.md`
- **Version Increment**: Once backup is secured, update version in `pubspec.yaml` (e.g., `version: 3.5.0`) before implementing code changes.

---

## 2. Core Flutter & Native Kotlin Protection (Zero Regression Policy)
- **Protected Core Architecture**:
  - The real-time voice audio streaming system (`lib/core/audio_stream_manager.dart`), Gemini Live WebSocket client (`lib/core/gemini_live_client.dart`), and floating overlay service (`lib/widgets/floating_overlay_manager.dart`, `MainActivity.kt`) are stable and critical.
  - Native Kotlin MethodChannel bridges and system service permissions must remain secure and reliable.
- **Rule**: Never alter, break, or casually refactor the core mobile voice engine or floating overlay architecture.
- **Scope for Changes**: Future enhancements must focus on:
  - Frontend UI / UX / HUD Flutter widgets, styling, glassmorphic themes, and responsive layouts.
  - Adding new modular features, widgets, or tools.
  - Any new feature must integrate non-blockingly via clean event hooks/signals without introducing regressions to existing core voice interaction.

---

## 3. Standard Execution Lifecycle
Whenever the user asks for new tasks or modifications:
1. **Analyze & Formulate Plan**: Understand the requirements and outline a clean implementation plan.
2. **User Alignment**: Get approval from Azhar before making modifications.
3. **Backup Execution**: Archive the current version into `backups/v<VERSION>_mobile/`.
4. **Implement**: Code the new features adhering to modern Flutter styling and robust Dart/Kotlin coding standards.
5. **Verify**: Test and confirm that the new feature builds (`flutter pub get`, `flutter build apk`) and functions flawlessly.

---

## 4. Mobile Platform Scope Rules
- **Target Scope**: Android Mobile (Flutter & Native Kotlin).
- **Directory Scope**: Work is strictly confined to workspace project files (`lib/`, `android/`, `pubspec.yaml`, `build_mobile.ps1`).

