# Changelog

All notable changes to the Kingdom Sponsor app and API are documented here.

## [0.3.0] - 2026-08-04

### Added
- PDF donation receipts: rebranded with the Kingdom Sponsor blue header, richer details (donor, campaign, reference, date, status), full fee breakdown, "Campaign receives" net amount, and branded footer.
- Receipt download button on the donation success screen.
- API status endpoint now returns the contribution `id`, so the app can build the receipt URL.
- Auto-disbursement: a daily sweep now pays out eligible balances for every active campaign, honouring each campaign's payout minimum.
- New campaigns default to a K10 payout minimum (was K200).

### Fixed
- USSD: donations were charged 100x the selected amount (double multiply). Now the correct amount is charged.
- USSD: menu-level collisions (donation amounts clashing with campaign submenu choices) resolved by restructuring the flow into a state machine.
- Platform fee cap: a K1 donation no longer incurs the K3 minimum over its value.
- App logo: the orange square logo was clipped awkwardly inside a circle. Replaced with a circular PNG (transparent corners) used consistently on the login screen, share QR code, and loading spinner.

### Changed
- Version code bumped to 30, version name 0.3.0.
- Platform fee now charged on disbursement too (K3 min / 1%), mirroring Lipila's model of taking a cut on both collection and disbursement.
- Host payout now respects the campaign's configured `min_withdraw_cents` (auto-disburse previously swept at K1 regardless of the configured minimum).
- Admin stats include payout platform fees in platform fee totals.

### Security
- OTP login throttling verified in place: max 5 codes/hour, max 5 verify attempts, 30s cooldown, hashed 6-digit codes.
