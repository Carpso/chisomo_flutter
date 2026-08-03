# Kingdom Sponsor — Google Play Listing Draft

## App details
- **App name**: Kingdom Sponsor
- **App ID / package**: `com.kingdomsponsor.app` (confirm with your Flutter bundle id — currently `kingdom_sponsor_app`)
- **Category**: Finance (fits "Charity & Causes" style apps; Play's closest: *Finance* or *Social*)
- **Countries**: Zambia (launch), expand later
- **Pricing**: Free (money flows via Lipila + platform fee)
- **Age rating**: 3+ (no adult content); note purchase prompts for parental guidance
- **Developer**: Kingdom Sponsor / [your company name]
- **Website**: [your domain] — needed for the developer page
- **Support email**: [you@domain.com]

## Short description (max 80 chars)
> Raise and give for causes you trust — church projects, missions, and youth outreach.

## Full description (HTML allowed)

### Heading
Kingdom Sponsor is Zambia's neutral fundraising platform. Set up a campaign in minutes, share it, and receive mobile-money contributions from anyone — every kwacha is tracked transparently.

### Body
**For campaign hosts (churches, youth groups, NGOs)**
- Create a campaign with a goal, story, and photo.
- Get paid directly to your mobile money via Lipila.
- Live progress bar and donor list.
- Withdraw whenever your balance reaches the minimum.

**For donors**
- Sign in with just your phone number.
- Give in seconds with MTN, Airtel, or Zamtel mobile money.
- Give anonymously or hide your amount.
- See exactly what you gave and to which cause.

**Transparent fees**
A small platform fee (K3 minimum or 1%) plus standard mobile-money charges apply, shown before you confirm.

**Built for Zambia**
- Works on the mobile-money networks Zambians already use.
- Contributions settle into the Lipila wallet and pay out to hosts automatically.

### Keywords (hidden SEO)
church fundraising Zambia, online offering, mobile money donation, crowdfunding Zambia, church tithe, youth ministry, NGO fundraising, MTN Airtel Zamtel, giving app

## Feature graphic / icon requirements
- Icon 512×512 PNG, no rounded corners (Play masks it)
- Feature graphic 1024×500 JPG/PNG
- Screenshots: at least 2 (recommend 6–8) 1080×1920 portrait
  - Suggested shots: (1) home feed of campaigns, (2) campaign detail with progress, (3) donate + fee breakdown, (4) login with phone number, (5) host dashboard, (6) admin dashboard

## Content rating questionnaire (short answers)
- Contains ads: No
- Collects personal info: Yes (phone number, name)
- Shares info: No (except with payment processor Lipila for the transaction)
- Has in-app purchases: Yes — real-money donations (not "virtual goods", so no Play billing required)
- Accounts: Phone-number-based accounts

## Data safety form (required by Play)
Collects:
- **Phone number** — used to identify the account / OTP login
- **Name** (optional) — displayed on public donor list
- **Payment info** — processed by Lipila (third-party SDK); app never stores card/MPIN
- **Financial transaction records** — amounts, references

Declared purposes: App functionality, Fraud prevention/security.
Encryption in transit: Yes (HTTPS to the API and Lipila).
You cannot delete data via an in-app control: add a "Delete account" flow (or document data-deletion email).

## Privacy policy
You must host a privacy policy at a public URL and link it in Play Console. Key clauses:
- What data is collected (phone, name, transaction records)
- Payment processing by Lipila (their privacy policy link)
- How OTP/SMS works (Africa's Talking or your provider)
- Data retention & account deletion process
- Contact email

## Play Console upload checklist
1. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`
2. Create a developer account ($25 one-time) at play.google.com/console
3. Create app → fill listing fields above → upload AAB → add 2+ screenshots
4. Declare Data safety → add privacy policy URL → complete content rating
5. Choose release track (production) → set country to Zambia
6. Signing: keep your upload key safe; Play manages the app signing key
7. Testing: install the APK (`flutter build apk --release`) on a real device first

## Pre-launch blockers to fix
- [ ] Add a public privacy policy + delete-account flow
- [ ] Confirm bundle/package ID matches your Google Play account ownership
- [ ] Logo + feature graphic designed
- [ ] Real SMS (Africa's Talking live) OR a visible "code shown in app" note for sandbox
- [ ] Production environment on the backend (`ENV=production`) with real credentials
- [ ] Test donations + payouts with real money on a device before submitting
