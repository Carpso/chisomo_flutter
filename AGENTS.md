# AGENTS.md — Kingdom Sponsor (Flutter app)

## Build & release rules (IMPORTANT)

- **Every release build MUST use an unused version code.** Before running
  `flutter build apk` / `flutter build appbundle`, bump `versionCode` in
  `android/app/build.gradle.kts` to a value that has not been uploaded yet
  (Google Play rejects duplicate/older version codes).
- **Always `flutter clean` before release builds** (`flutter clean` then
  `flutter pub get`, then `flutter build ...`). This guarantees no stale
  incremental artifacts or the previously-renamed "Kingdom Sponsor.apk"
  leftovers ship in a store build.
- Current version name comes from `pubspec.yaml` (`version:`), current
  versionCode is in `android/app/build.gradle.kts`.
- **Current version: 0.7.0 (versionCode 75)** — last built 2026-08-13.
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
- Cron triggers: `*/15 * * * *` (intruder alerts) and `0 6 * * *` (daily sweeps incl. `runAutoDisburse`, 08:00 CAT)

## Environment

- Windows PowerShell (5.1); Flutter 3.35.1 / Dart 3.9.0
- Android SDK at `C:\Users\User\AppData\Local\Android\Sdk`
- Firebase project: `kingdom-sponsor` (configured for FCM push)
- Lipila environment: `production`
- Lipila integration guide (reusable for other wallets/apps): `docs/LIPILA_INTEGRATION.md` in the chisomo repo — covers narration sanitization, collections (MoMo + card), disbursements, logging, limits.

## Key features implemented

- Push notifications (Firebase Admin SDK)
- Airtime purchase system (admin-controlled enable/disable)
- Verified Host Badge subscription (3 tiers, admin-controlled pricing)
- USSD service endpoint (requires MNO approval for production)
- Campaign image editing (admin endpoint)
- Manual disbursement trigger
- Auto-sliding carousel (pause/play toggle in Settings → "Auto-slide carousel")
- Ticket support with status filtering and admin replies
- SMS network status message (editable by admin)
- Linked account donation collaboration view
- Deep links: `kingdomsponsor://campaign/<id>`, `kingdomsponsor://donate/<id>`
- Receipt download from donation success screen
- Processing fees: K0.24 + 1% (K3 minimum) per transaction
- **Card donations** (Visa/Mastercard/Amex) via Lipila hosted checkout (`POST /api/campaigns/:id/contribute-card` → `cardRedirectionUrl`; donate screen has a Mobile Money / Card toggle). Disbursements remain mobile-money only. Card fees: 2% (K5 min) + ZMW 0.24 + Lipila's card collection fee, configured via `CARD_PLATFORM_FEE_PCT` / `CARD_PLATFORM_MIN_FEE_CENTS` / `CARD_LIPILA_COLLECTION_FEE_PCT` (wrangler vars, live since 0.4.3; platform rates to be revised later).
- **Referral rewards** — users enter a referral code at signup (manual field + deep links), one link per user (unique index), `referral_reward_threshold` admin setting (default 5 signups). When a referrer reaches the threshold they qualify; admin sees a "Referral rewards" tile on the dashboard and rewards them (`POST /api/admin/referrals/:userId/reward` → push + SMS notification, `users.referral_rewarded_at`).
- **PDF receipts** capitalize every word of the donor name and campaign title.
- **Admin dashboard "Total raised (active)" card** — sum of confirmed donations on active campaigns (`totalActiveRaisedCents` from `/api/admin/stats`), tap for per-campaign breakdown.
- **Narration sanitization** for all Lipila calls (`sanitizeNarration` in src/lipila.ts) — fixed production 400s (`Narration can only contain letters, numbers and spaces`).
- **Lipila event logging** (`lipila_logs` table, `/api/admin/lipila-logs`) — every collection/disbursement success AND failure with real amounts and full error bodies.
- **Airtime orders** (live since 0.4.4) — order reference prefix `AIR-`, payment collected via Lipila MoMo prompt, fulfilled through Africa's Talking airtime API (`sendAirtime` in `src/sms.ts`; needs `AT_API_KEY` secret + `AT_USERNAME`; sandbox logs only). `airtime_orders` carries `lipila_reference` / `attempts` / `error` / `credits_used_cents` (migration_v26). Enable via `app_settings.airtime_enabled` (off by default).
- **Admin exports** (0.4.4) — `GET /api/admin/stats/export.csv`, `GET /api/admin/stats/export.pdf` (pdf-lib), `GET /api/admin/backup/export` (full records incl. `lipila_logs`, `airtime_orders`, `host_badges`); dashboard "Total processed" card (`totalProcessedCents` = confirmed donations + successful withdrawals + fee sweeps).
- **Carousel** (0.4.4) — promoted campaigns show their own image (network or bundled asset) + host name; airtime slides only when `/api/airtime/config` says enabled; pause/play moved to Settings ("Auto-slide carousel" switch, `carouselAutoSlideProvider`); real MNO icons (`assets/airtel_icon.jpg`, `mtn_icon.webp`, `zamtel_icon.jpg`, `zedmobile_icon.jpg`).
- **Carousel fixes (0.4.6)** — campaign slide bottom content rebuilt (scrim + clean column: FEATURED CAMPAIGN pill + raised amount row + 2-line title + host + Give Now button, no overlap); bottom-nav no longer flickers when the carousel auto-slides (`BottomNavShell` ignores horizontal scrolls); auto-slide timer no longer recreated every rebuild (listener in `initState`).
- **Sample campaign images** — hosts and admins can pick one of 5 bundled images (`assets/campaign_samples/sample_1..5.png`, `kSampleCampaignImages`) when creating/editing a campaign.
- **Host name on campaigns** — backend joins `users.name` into campaign responses (`hostName`), shown on cards, detail and carousel.
- **Short links & deep links (0.4.6 fix)** — `createShortLink` now reuses the stored row for a long URL (old random codes and new deterministic codes both resolve; `INSERT OR IGNORE` no longer returns a code that 404s). Share links are consistent between list + detail. Web share page deep links use `kingdomsponsor://campaign/<id>?ref=CODE` (was `&ref=`). Flutter: `donateDeepLink()` replaces fragile `replaceFirst('campaign','donate')`; `shortUrl()` fallback points at the long share page (always resolves); wa.me links drop the unsupported `&media=` param. Share message template: title / description / raised·donors·host / Give here + Open in app + Play Store lines.
- **Admin notifications (0.4.5)** — every new host application (`pushAdmins` on `/api/host/apply`, `type: "host_application"`) and every confirmed donation (`type: "donation"` with `campaignId`) pushes to the superadmins alongside existing ticket alerts.
- **Campaign categories (0.4.5)** — ~31 curated categories (`src/categories.ts` + `kCampaignCategories` in models.dart, kept in sync), `campaigns.category` column (migration_v27), `GET /api/campaign-categories`, optional `?category=` filter on `GET /api/campaigns`, category required on create + admin edit (validated by `isValidCategory`), host create form dropdown, admin edit dropdown, horizontal filter chips on the campaign list, category badge on campaign detail.
- **Lock-screen notifications (0.4.5)** — AndroidManifest `com.google.firebase.messaging.default_notification_channel_id` → `giving_updates` (high-importance channel created in `push_service.dart`) so FCM notifications show as heads-up banners with sound while the app is closed; POST_NOTIFICATIONS permission now also requested at startup for already-signed-in users; background FCM handler mirrors data-only messages as local notifications.
- **Public/private campaigns (0.4.6)** — `campaigns.visibility` column (migration_v28, `public`|`private`), host create form gets a Public/Private toggle, admin edit has a Visibility dropdown. Private campaigns are hidden from `/api/campaigns`, `/share` landing, USSD menus and the home carousel, and don't trigger the "New campaign posted" donor push — but remain reachable by direct link/share and visible to the host + admins. `campaignPublic` returns `visibility`; Flutter `Campaign.visibility`/`isPrivate` with lock badges on detail, list card, and host dashboard.
- **Deep-link + push routing fixes (0.4.7)** — `main.dart` now switches on `uri.host` (was wrongly parsing `pathSegments.first` for host-style `kingdomsponsor://campaign/<id>` links, so deep links opened home); cold-start push taps are buffered and flushed once `onNotificationOpen` is set (were dropped because `initPushService` runs before `runApp`); `accept-link`/`reject-link` hosts added to the AndroidManifest; `LinkActionScreen` reads the id from the correct segment; `_routeFromData` routes `referral_rewarded`→`/settings/referrals`, `airtime_delivered`→`/airtime`, `badge_activated`→`/host/badge`.
- **Category sample images (0.4.7)** — 15 generated category-specific sample images (`assets/campaign_samples/cat_*.png`) alongside the original 5; `kSampleCampaignImages` now has 20; `kSampleImageForCategory` maps every category to a fitting sample, auto-selected when a host picks a category (if no photo chosen yet). Admin edit dialog uses the same set.
- **Share with image (0.4.7)** — share sheet "Share with image" button downloads the campaign image (network or bundled asset) to a temp file and opens the native share sheet (`share_plus`) with the photo attached alongside the message.
- **Admin assistants (0.4.7)** — `admin_assistants` table (migration_v29) + `requireStaff(...scopes)` helper; superadmins always pass, assistants pass only with matching scopes (`campaigns`/`donations`/`tickets`/`users`/`settings`/`finance`/`restore`). Endpoints: `GET /api/admin/assistants`, `GET /api/admin/users/search?q=`, `POST/PUT/DELETE /api/admin/assistants[/:id]`. Admin dashboard "Staff & restore" tile → `AdminStaffScreen` (assistants + restore + audit log tabs).
- **Restore + audit log (0.4.7)** — campaigns are soft-deleted (`status='deleted'`), so admins can restore: `POST /api/admin/campaigns/:id/restore` (needs `restore` scope) notifies the host + re-lives the campaign; `GET /api/admin/campaigns/deleted` lists restorable campaigns. Every delete/restore/ban/reward writes to the `admin_actions` audit log (`GET /api/admin/actions`), visible in the staff screen. All delete buttons keep their confirm dialogs; assistants are gated by scope, so a limited assistant can't delete what they can't manage.
- **Host edit requests (0.5.0, fraud protection)** — hosts CANNOT edit campaigns directly. `PUT /api/campaigns/:id` records a `campaign_edit_requests` row (migration_v32) of proposed changes (title/description/goal/minWithdraw/category/visibility/endsAt) and pushes superadmins; a duplicate pending request is rejected (409). Admin reviews via `GET /api/admin/edit-requests` and applies via `POST /api/admin/edit-requests/:id/approve` (applies changes + SMS/push host) or `:id/reject` (with notes). Flutter: host dashboard Edit button opens the prefilled form; saving shows "submitted for review" and returns to Host tab; admin dashboard "Edit requests" tile → `AdminEditRequestsScreen`.
- **KSPONSOR sender ID (0.5.0)** — all SMS (OTP + notifications) send from `KSPONSOR` (`AT_FROM=KSPONSOR` in wrangler vars; code defaults to KSPONSOR and falls back to AT default on a 400). All SMS templates in `src/messages.ts` refreshed with KSPONSOR branding + concise copy (OTP, donation, payout, pledge, promo, delete/edit, support, milestone, campaign end). Mojibake removed from intruder/link/campaign SMS.
- **Reusable playbook (0.5.0)** — `docs/REUSABLE_PLAYBOOK.md` in the chisomo repo captures intruder detection, Lipila gateway + fee math + idempotency, SMS/sender-ID setup, and the clean Android release build process for reuse in other apps.
- **Public verified-host badge (0.5.2)** — `campaignPublic` returns `hostVerified` (from `users.host_verified`, joined into list/detail queries); gold badge on campaign cards, detail, carousel, and the web share page.
- **Host KYC (0.5.2)** — `users` gains `host_kyc_status/type/doc_url/notes` (migration_v34); `POST /api/host/apply` captures KYC type + doc URL; `POST /api/host/kyc-upload` stores the document in R2 under `kyc/` (media route requires admin for that prefix); admin reviews via `POST /api/admin/hosts/:id/kyc` (approve flips the public verified badge). Flutter host-apply form has a document-type dropdown + upload; admin application card shows KYC status/type/doc link + Approve/Reject buttons.
- **Campaign types (0.5.2)** — `campaigns.campaign_type` (migration_v34): `community|ngo|faith|emergency|medical|sponsor`, validated on create/admin-edit/edit-request; `campaignPublic` returns `campaignType`; `kCampaignTypes` in models.dart; dropdown in host create form + admin edit dialog.
- **Smart search + org grouping (0.5.3)** — Campaigns tab has an AppBar search icon → inline search bar that filters loaded campaigns instantly by title/description/host/category/org; backend `GET /api/campaigns/search?q=` for full coverage. `campaignPublic` returns `hostOrg` (host's `host_org`). Org name shown on cards (tap → opens search for that org); campaign detail shows a "More from {org}" section listing the community's other campaigns.
- **FCM fix (0.5.3)** — `lib/firebase_options.dart` added with explicit `FirebaseOptions`; `Firebase.initializeApp(options:)` in `main()` and the background handler. Previously `Firebase.initializeApp()` was called with no options, so FCM tokens/pushes silently failed. Admin assistants screen: search now uses a proper controller + search button (mobile-friendly).
- **Airtime toggle adherence (0.5.3)** — new shared `airtimeEnabledProvider` (FutureProvider) reads `/api/airtime/config`; home carousel watches it (hides the Buy Airtime slide the instant the admin disables it), the airtime screen blocks the buy form with "Airtime is not available right now" if disabled, and `_order()` fails fast when the toggle is off. Admin airtime config invalidates the provider on save so the toggle applies everywhere immediately.

## 0.7.0 — events, assistants, updates, QA hardening (2026-08-13)

- **Events as first-class** — dedicated `EventsScreen` (Instagram-style feed), `EventDetailScreen`, `BuyTicketScreen` (tier + qty, MoMo/card), RSVP for free events, QR check-in. Campaign detail auto-redirects event campaigns to the event screen; every "Buy ticket" CTA routes to the ticket screen (never the donate flow). Deep link `kingdomsponsor://event/<id>` (and `/buy-ticket`) added to the AndroidManifest + router.
- **USD giving** — USD presets ($5/$10/$20/$50/$100) + custom field with decimal input, converted via the live FX rate (the old toggle left the amount area empty).
- **Assistants actually work** — `/api/host/me` + verify-otp now return `assistantScopes`; `AuthState.isStaff`/`canScope()` gate the admin shield, routes and tiles by scope; ~50 admin endpoints converted from `requireAdmin` to `requireStaff(scope)`. Assistant-management + backup/restore stay superadmin-only. Admin dashboard shows a scopes banner for assistants.
- **Host → donor updates (moderated)** — hosts post updates via their dashboard; submissions go to a moderation queue (`/admin/announcements`, `campaigns` scope); approved updates render on campaign/event pages ("Updates from the host") and push every confirmed donor. migration_v42.
- **Notifications fixed** — `sendMulticastPush` bulk errors no longer return all tokens as failed, so a bad key/quota/network can't wipe `device_tokens` anymore (`bulkError`); `giving_updates` channel self-heals if an old build left it silent; legacy `users.fcm_token` pushes (new campaign/updated) switched to `device_tokens` + bell records. Settings has a "Test notification" button (`POST /api/user/push/test`).
- **Payments QA** — `moneyRef()` (fees.ts) appends a random suffix to every money reference (`CON-`, `PAY-`, `REF-`, `PRO-`, `AIR-`, …) so same-ms collisions can't corrupt webhook idempotency; `confirmContribution` enforces event capacity atomically in the confirm UPDATE (a late ticket payment when the event just sold out is failed + host alerted, never oversold). Test suites: `src/__tests__/fees.test.ts`, `webhook-idempotency.test.ts` (backend, 35 tests) and `test/money_test.dart`, `test/fx_test.dart` (Flutter, 26 tests).
- **K0.48 fixed fee** — platform flat fee is ZMW 0.48 (backend was already 48); all Flutter strings/fallbacks updated from 0.24.
- **Restore list aligned** — deleted-campaigns items rebuilt as `Card + ListTile` (consistent icon/title/button alignment) in `admin_staff_screen.dart`.
- **Admin shield on Events tab** — the admin guard button (shield icon) now also appears on the Events tab for staff, so assistants see it wherever they are.
- **Donor emails list** — card donations/ticket purchases now store the payer email on `contributions` (migration_v43); `GET /api/admin/emails` (donations scope) lists confirmed donor emails with giving totals; admin dashboard "Donor emails" tile → `AdminEmailsScreen` with search + one-tap copy.
- **Event tier create fixed** — `parseEventTiers` now accepts BOTH a JSON string and an already-parsed array (the app sends an array). Previously `JSON.parse(String(array))` mangled arrays → tiers were silently dropped on create/admin-edit. Verified live (event tiers round-trip). Poster upload now detects MIME from image bytes (JPEG/PNG/WebP magic numbers) + retries once.

