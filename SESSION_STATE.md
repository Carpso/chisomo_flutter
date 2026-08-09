# Session State — Kingdom Sponsor

**Last Updated**: 2026-08-09
**Version**: 0.5.3 (versionCode 64)
**Backend Commit**: working tree (deployed 2026-08-09 as version 3d0e91bd)
**Status**: pre-release; clean build APK (65.3MB) + AAB (51.5MB) verified versionCode 64 / 0.5.3

---

## Current session (2026-08-09) — v0.5.x feature sprint + fixes

### What was done this session

**Trust / market-segment readiness (0.5.2)**
1. **Public verified-host badge** — `campaignPublic` returns `hostVerified` (from `users.host_verified`, joined into list/detail queries); gold badge on campaign cards, detail, carousel, and the web share page.
2. **Host KYC** — `users` gains `host_kyc_status/type/doc_url/notes` (migration_v34); `POST /api/host/apply` captures KYC type (NRC / NGO cert / endorsement) + doc URL; `POST /api/host/kyc-upload` stores the document in R2 under `kyc/` (media route requires admin for that prefix, no cache); admin reviews via `POST /api/admin/hosts/:id/kyc` (approve flips the public verified badge). Flutter host-apply form has a document-type dropdown + upload; admin application card shows KYC status/type/doc link + Approve/Reject buttons.
3. **Campaign types** — `campaigns.campaign_type` (migration_v34): `community|ngo|faith|emergency|medical|sponsor`, validated on create/admin-edit/edit-request; `campaignPublic` returns `campaignType`; `kCampaignTypes` in models.dart; dropdown in host create form + admin edit dialog.

**Smart search + org grouping (0.5.3)**
4. **Smart search** — Campaigns tab AppBar search icon → inline search bar filtering loaded campaigns instantly by title/description/host/category/org; backend `GET /api/campaigns/search?q=` for full coverage.
5. **Church/organisation grouping** — `campaignPublic` returns `hostOrg`; org name on cards (tap → opens filtered search); campaign detail shows a "More from {org}" section listing the community's other campaigns.

**Critical fixes (0.5.3)**
6. **Push notifications root cause fixed** — `Firebase.initializeApp()` was called with NO options, so FCM tokens/pushes silently failed. Added `lib/firebase_options.dart` with explicit `FirebaseOptions` (apiKey, appId, messagingSenderId, projectId from google-services.json) and passed in `main()` + the background handler.
7. **Admin assistants route fixed** — `/admin/staff` search dialog rebuilt with a proper `TextEditingController` + visible search button (mobile-friendly); full analyze clean.
8. **Buy Airtime adheres to admin toggle** — new shared `airtimeEnabledProvider` (FutureProvider reading `/api/airtime/config`); carousel hides the Buy Airtime slide the instant the admin disables it, the buy screen blocks the form with "Airtime is not available right now", `_order()` fails fast, and the admin config invalidates the provider on save.

**Earlier in the session (0.4.5 → 0.5.1)**
- Deep-link GoException fix (`deepLinkToRoute` normalizer — raw URI or path → safe route).
- Host **edit-requests** (fraud protection): hosts can't edit directly; `PUT /api/campaigns/:id` records a `campaign_edit_requests` row (migration_v32), admin approves/rejects.
- KSPONSOR sender ID for ALL SMS (OTP + notifications); all `src/messages.ts` templates refreshed with KSPONSOR branding + concise copy; mojibake removed.
- Africa's Talking **airtime status callback** (`/api/webhooks/at-airtime/status`) — stores `at_request_id`, confirms real MNO delivery, branded delivered/failed SMS (migration_v33).
- Telegram intruder alerts configured (bot `KingdomSponsorBot`, chat id 1414449063) — verified live.
- IP-based OTP throttle (migration_v30), campaign-ending push alerts, admin assistants + restore + audit log (migration_v29), public/private campaigns (migration_v28), categories (migration_v27).
- Carousel fixes (text overlap, bottom-nav flicker, play/pause moved to Settings), share-with-image (share_plus), 20 sample images incl. category real photos, Play Store badge, host-campaigns carousel slide.
- Reusable playbook written: `chisomo/docs/REUSABLE_PLAYBOOK.md` (intruder detection, Lipila gateway + fee math + idempotency, SMS/sender-ID, Android release build).

---

## Migrations Applied

| Version | Description |
|---------|-------------|
| v18–v26 | short links, failed logins, notifications, badges/airtime, lipila_logs, MNO health |
| v27 | campaigns.category |
| v28 | campaigns.visibility (public/private) |
| v29 | admin_assistants + admin_actions (audit log) |
| v30 | otp_attempts (IP throttling) |
| v31 | users.host_verified + host_verification_notes |
| v32 | campaign_edit_requests |
| v33 | airtime_orders.at_request_id/sent_at/delivered_at |
| v34 | campaigns.campaign_type + users.host_kyc_* |

---

## Build History (most recent)

### 2026-08-09 — v0.5.3 versionCode 64 (clean rebuild)

```bash
flutter clean
flutter pub get
flutter analyze       → 0 issues
npx tsc --noEmit      → clean
flutter build apk --release
  ✓ Built build/app/outputs/flutter-apk/app-release.apk (65.3MB)
  versionCode 64 / versionName 0.5.3 verified via aapt
flutter build appbundle --release
  ✓ Built build/app/outputs/bundle/release/app-release.aab (51.5MB)
```

**Backend deployed** as version `3d0e91bd` (includes smart search endpoint + hostOrg).

---

## Project Structure

```
D:\Explorer\MAYUNDO\KEY PROJECTS\
├── chisomo_flutter\     # Flutter app (Dart)
│   ├── lib\
│   │   ├── core\        # Theme, router, API client, push_service, widgets
│   │   ├── features\    # Screens by feature
│   │   └── firebase_options.dart   # Explicit Firebase options (FCM fix)
│   ├── android\         # Android config
│   └── pubspec.yaml     # Dependencies
└── chisomo\             # Cloudflare Worker API (TypeScript)
    ├── src\             # index.ts, lipila.ts, sms.ts, messages.ts, shorten.ts, categories.ts, fees.ts, firebase.ts
    ├── sql\             # D1 migrations v2–v34
    ├── docs\            # REUSABLE_PLAYBOOK.md, LIPILA_INTEGRATION.md
    └── wrangler.toml    # Worker config (AT_FROM=KSPONSOR)
```

---

## Environment

- **OS**: Windows 11, PowerShell 5.1
- **Flutter**: 3.35.1 / Dart 3.9.0
- **Android SDK**: `C:\Users\User\AppData\Local\Android\Sdk`
- **Production API**: `https://kingdom-sponsor-api.godfreymoseskalambo.workers.dev`
- **D1 Database**: `kingdom-sponsor-db` (id: `01c99f57-3f1b-4212-85db-261f86f90a24`)
- **Firebase**: `kingdom-sponsor` project (FCM push; explicit options in firebase_options.dart)
- **Lipila**: production environment
- **Africa's Talking**: `ChurchOnApp`, sender ID `KSPONSOR` (all SMS)

---

## Build Commands

```bash
# Flutter — ALWAYS clean before release builds
cd D:\Explorer\MAYUNDO\KEY PROJECTS\chisomo_flutter
flutter clean
flutter pub get
flutter analyze
flutter build apk --release        # -> build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # -> build/app/outputs/bundle/release/app-release.aab

# Backend
cd D:\Explorer\MAYUNDO\KEY PROJECTS\chisomo
npx tsc --noEmit                   # Type check
npx wrangler deploy                # Deploy to production
npx vitest run src/__tests__       # Run backend tests

# D1 Migrations
npx wrangler d1 execute kingdom-sponsor-db --file=./sql/migration_vNN.sql --remote

# Verify APK version
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | findstr versionCode
```

---

## Secrets & Configuration

### Backend Secrets (Cloudflare Workers) — `wrangler secret put NAME`
- `JWT_SECRET`, `AT_API_KEY`, `LIPILA_API_KEY`, `LIPILA_WEBHOOK_SECRET`
- `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` (FCM)
- `SUPERADMIN_PHONES`, `SETTLEMENT_PHONE`, `TWILIO_AUTH`, `TWILIO_SID`

### Wrangler vars (non-secret)
- `ENV=production`, `AT_USERNAME=ChurchOnApp`, `AT_FROM=KSPONSOR`, `LIPILA_ENV=production`
- `APP_URL`, fee vars, `CARD_*` vars, `OTP_TTL_MINUTES`, `PROMO_*`

### Admin settings (D1 `admin_settings` / `app_settings`)
- `intruder_alert_telegram=1`, `telegram_bot_token`, `telegram_chat_id=1414449063`
- `app_settings`: `airtime_enabled` (currently **false**), `airtime_markup_pct=5`, `promo_price_cents=5000`, `promo_days=30`, `host_badge_enabled=true`

### Flutter Config
- `.env` (gitignored): `API_URL=https://kingdom-sponsor-api.godfreymoseskalambo.workers.dev`
- `google-services.json`: Firebase config (project: kingdom-sponsor, package: com.kingdomsponsor.app)

---

## Features Implemented (v0.5.3)

### Core
- OTP auth (AT SMS, KSPONSOR sender), campaigns CRUD, MoMo + card donations (Lipila), auto-disbursement, FCM push (fixed), carousel, support tickets, linked accounts, PDF receipts
- **Public/private campaigns**, **categories (~31)**, **campaign types (6)**, **smart search**, **org grouping**

### Trust / fraud
- **Host KYC** (document upload to private R2, admin review), **public verified badge**, host **edit-requests** (admin-approved), soft-delete + **restore**, admin **assistants** (scoped), **audit log**

### Premium
- Verified Host Badge (3 tiers), airtime purchase (toggle-gated, AT status callback), USSD (backend ready), promotions (paywall)

### Admin
- Dashboard stats, user/host management, campaign/image management, promotions, tickets, disbursements, push status/test, airtime + badge config, **edit-requests**, **staff & restore**, **KYC review**, Lipila logs, SMS status

---

## Cron Schedule

- `*/15 * * * *` — intruder alert scan, MNO health, auto-disburse
- `0 6 * * *` UTC — fee sweep, fee-sweep status checks, pledge reminders, promotion expiry, auto-disburse, withdrawal status checks, ticket auto-close, airtime fulfillment, campaign-ending alerts

---

## Known Issues / TODO

### Active
- [ ] Airtime is currently **disabled** in production (`app_settings.airtime_enabled=false`) — re-enable via admin when ready
- [ ] USSD needs AT dashboard setup + MNO approval (2–4 weeks)
- [ ] Verified Host Badge subscription is a free activation stub (no Lipila payment) — keep disabled or wire payment
- [ ] Campaign 9 payout (K124.81) blocked by Lipila wallet "Insufficient balance" — fund wallet; cron retries
- [ ] Telegram/email intruder channels: Telegram live; email needs `admin_email` config

### Future
- [ ] Real-time disbursement (instant on donation)
- [ ] Multi-device sign-out handling
- [ ] More category sample images / user-uploaded photos

---

## Important Notes

1. **Version code must be unique** for each Play Store upload — bump before building. Current: 0.5.3 / 64.
2. **Always `flutter clean` before release builds** (stale incremental artifacts / renamed "Kingdom Sponsor.apk" must not ship).
3. **Firebase.initializeApp() MUST use `DefaultFirebaseOptions.currentPlatform`** — bare init silently breaks FCM (fixed in 0.5.3).
4. **AT_FROM=KSPONSOR** — all SMS (OTP + notifications) branded; falls back to AT default on 400.
5. **Lipila** is in production mode — real money flows through it.
6. **`.env` and `build_log.txt` are gitignored**; `chisomo/.dev.vars` gitignored.

---

## Next Session Checklist

1. Decide on enabling airtime (toggle is ready; AT keys verified; add real funding for the wallet).
2. Wire Verified Host Badge to a real payment flow (or keep disabled).
3. Fund the Lipila wallet so campaign 9's K124.81 payout retries succeed.
4. Consider enabling the Airtime Status callback URL in the AT dashboard: `https://kingdom-sponsor-api.godfreymoseskalambo.workers.dev/api/webhooks/at-airtime/status`.
5. Upload AAB (0.5.3 / 64) to Play Console.
