# Kingdom Sponsor — Roadmap (Post-Launch Features)

Each item is blocked by an external account, a Lipila capability gap, or storage
that does not exist yet. Order roughly by business value.

---

## 1. Recurring giving (monthly "pledges")

**Status: BLOCKED — Lipila cannot do true saved auto-debit.**
Lipila's USSD/PIN collection flow is a one-off customer-initiated payment. There
is no mandate / standing-order API, so the app cannot silently charge a donor
every month. The code has no recurring-give button yet.

Options:
- **Scheduled reminders (recommended, build now):** donor chooses "give K100
  every month"; app stores a `recurring_pledges` row (campaign, phone, amount,
  day-of-month, active flag) and sends an OTP/SMS/WhatsApp reminder on that day.
  One tap opens the existing Lipila flow. Zero Lipila changes.
- **Lipila mandate feature:** ask Lipila whether they can enable standing
  orders / mandates. If yes, add `POST /api/pledges` that creates the mandate
  reference and stores it; `scheduled` handler re-collects monthly.
- **Airtel Money scheduled payments** (Airtel has standing instruction for
  salary-type payments) — investigate eligibility with the settlement provider.

## 2. Campaign media (photos / video gallery)

**Status: BLOCKED — no upload backend or storage.**
Campaigns currently have only a title/description and a gradient placeholder.

Plan:
- Add **Cloudflare R2** bucket + upload endpoint `POST /api/campaigns/:id/media`
  (multipart, size/type limits, malware scan of images).
- Worker returns an `image_url`; campaign header renders it (the model already
  supports `imageUrl`, the UI falls back to the gradient).
- Later: video via Cloudflare Stream with signed playback URLs.

## 3. In-app chat / announcements

**Status: NOT STARTED — needs realtime infra.**
- Use **Durable Objects** (chat rooms per campaign) or a simpler
  announcements table (`announcements`: campaign, host id, body, created_at)
  shown on the campaign detail screen. Start with one-way host announcements;
  add donor replies only if engagement data supports it.
- Notifications piggyback on #4.

## 4. Push notifications (FCM)

**Status: BLOCKED — needs Firebase account + google-services.json.**
- Create a Firebase project, add Android app, drop `google-services.json` into
  `android/app/`, use `firebase_messaging`.
- Worker sends pushes via Firebase HTTP v1 API with a `FCM_SERVICE_ACCOUNT`
  secret (service-account JSON) — no extra npm packages needed.
- Use cases: host has new donation, payout sent, campaign goal reached, weekly
  reminder for recurring pledges.

## 5. Error monitoring (Sentry)

**Status: BLOCKED — needs Sentry account + DSN.**
- `@sentry/node` in the Worker (`SENTRY_DSN` secret), `sentry_flutter` in the
  app. Catch unhandled exceptions in the app's `main()` and in the Worker's
  `fetch` wrapper. Cheap and high value before going public.

## 6. Multi-currency / cross-border

**Status: BLOCKED — Lipila is currently ZMW/Zambia-centric.**
- Verify Lipila's multi-currency support (do they hold/disburse other
  currencies? USD/MWK/ZAR?).
- If yes: add a `currency` column to campaigns and a settlement currency per
  host. All money math is integer minor-units already, so the fee/ledger layer
  only needs a currency-aware `formatKwacha` (rename to `formatMoney`).
- If no: keep ZMW-only, document the limitation in the Play Store listing.

---

## Launch blockers (short term)

1. **Africa's Talking credentials** — real `AT_USERNAME` / `AT_API_KEY` +
   registered sender ID; flip `ENV` to `production` so OTP SMS works without
   the debug code.
2. **Delete test data** — campaign #1 `test-k1` ("Test Campaign - Delete Me")
   and failed contribution #4 must be removed before real launch.
3. **Play Store items** — public privacy policy + delete-account flow, final
   icon/branding, and produce the AAB.
