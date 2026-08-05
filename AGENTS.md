# AGENTS.md — Kingdom Sponsor (Flutter app)

## Build & release rules (IMPORTANT)

- **Every release build MUST use an unused version code.** Before running
  `flutter build apk` / `flutter build appbundle`, bump `versionCode` in
  `android/app/build.gradle.kts` to a value that has not been uploaded yet
  (Google Play rejects duplicate/older version codes).
- Current version name comes from `pubspec.yaml` (`version:`), current
  versionCode is in `android/app/build.gradle.kts`.
- A "store build" (something to upload) requires a version code bump even if
  only assets/code changed.
- Release build commands:
  - `flutter build apk --release` -> `build/app/outputs/flutter-apk/app-release.apk`
  - `flutter build appbundle --release` -> `build/app/outputs/bundle/release/app-release.aab`
- Verify a built APK's code with:
  `aapt dump badging build/app/outputs/flutter-apk/app-release.apk | findstr versionCode`

## Backend

- Worker lives in the sibling repo `D:\Explorer\MAYUNDO\KEY PROJECTS\chisomo`.
  Deploy: `npx wrangler deploy` (after `npx tsc --noEmit`).
