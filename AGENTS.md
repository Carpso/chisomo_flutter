# AGENTS.md — Kingdom Sponsor (Flutter app)

## Build & release rules (IMPORTANT)

- **Every release build MUST use an unused version code.** Before running
  `flutter build apk` / `flutter build appbundle`, bump `versionCode` in
  `android/app/build.gradle.kts` to a value that has not been uploaded yet
  (Google Play rejects duplicate/older version codes).
- Current version name comes from `pubspec.yaml` (`version:`), current
  versionCode is in `android/app/build.gradle.kts`.
- **Current version: 0.4.1 (versionCode 49)** — last built 2026-08-07.
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
- Production API: `https://kingdom-sponsor-api.godfreymoseskalambo.workers.dev`
- D1 database: `kingdom-sponsor-db` (id: `01c99f57-3f1b-4212-85db-261f86f90a24`)
- Cron triggers: `*/15 * * * *` (intruder alerts) and `0 2 * * *` (daily sweeps incl. `runAutoDisburse`)

## Environment

- Windows PowerShell (5.1); Flutter 3.35.1 / Dart 3.9.0
- Android SDK at `C:\Users\User\AppData\Local\Android\Sdk`
- Firebase project: `kingdom-sponsor` (configured for FCM push)
- Lipila environment: `production`

## Key features implemented

- Push notifications (Firebase Admin SDK)
- Airtime purchase system (admin-controlled enable/disable)
- Verified Host Badge subscription (3 tiers, admin-controlled pricing)
- USSD service endpoint (requires MNO approval for production)
- Campaign image editing (admin endpoint)
- Manual disbursement trigger
- Auto-sliding carousel with user pause control
- Ticket support with status filtering and admin replies
- SMS network status message (editable by admin)
- Linked account donation collaboration view
