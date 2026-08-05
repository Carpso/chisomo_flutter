# Kingdom Sponsor — Release Notes

## Version 0.3.0 (2026-08-04)

### What's new
- **Downloadable PDF receipts** — after a successful donation you can now save/share a branded, detailed receipt showing the fee breakdown and the exact amount the campaign receives.
- **Correct USSD donations** — a bug that charged 100x the chosen amount is fixed, and the USSD menu flow was restructured so choices no longer collide.
- **Circular logo** — the app logo now renders as a clean circle (login screen, share QR code, loading spinner).

### Fees
- Donors pay the platform cut (K3 min / 1%) plus Lipila's collection fee (2.5%) on top of their donation.
- The host campaign receives the donation minus those collection fees.
- On payout, both Lipila's disbursement fee (1.5%) **and** the platform's payout cut (K3 min / 1%) are deducted — the platform charges on collection and on disbursement, the same model as Lipila.
- Payouts run automatically each day, once a campaign's balance reaches its payout minimum.

### App
- Version: 0.3.0 (build 30).
- Receipt download button added to the donation success screen.

### Security
- Phone-number login stays protected by SMS OTP (rate-limited and one-time-use); a number can't be taken over without the code.

### Install
- Android: install `app-release.apk` (or the `.aab` via Play Console / your store listing).
