# Kingdom Sponsor — Competitive Analysis (Zambia / Africa)

Compiled from public sources, Aug 2026.

## Context on the players

- **Hobbiton Technologies** (hobbiton.tech, Lusaka) is a Zambian fintech *developer* —
  it built **Lipila** (the payment gateway Kingdom Sponsor runs on) plus insurance,
  capital markets and payments platforms (Inshuwa, Gari, Samala, MyLuSE, Airtel
  Village Banking, Patumba). It is **not** a fundraising app — it is the rails.
- **Giver by Zuhile** (usezuhile.com) — the closest **direct competitor** in Zambia:
  church/org giving over Airtel Money, MTN MoMo, Zamtel Kwacha.
- **BlessPay** (blesspay.app) — church giving app out of **Ghana** (MTN, Vodafone,
  AirtelTigo), expanding to orgs.
- **The Treasurer** (treasurer.cloudone.co.zm) — Zambian church *administration*
  platform (collections, expenses, pledges, multi-branch, PDF receipts, 15+ currencies).
- **My Church Zambia** — church management with tithe/contribution records and
  online-giving integration.
- **Ozona** (ozona.org) — "Zambia's national contribution platform": one transparent
  national fund for community needs. Not per-org fundraising.
- **Airtel Village Banking** (built by Hobbiton) — digitizes community savings groups
  via USSD/web. Adjacent, not crowdfunding.
- **Global references:** GoFundMe (multi-purpose crowdfunding), M-Changa (Kenya —
  event/group fundraising, MPesa).

## Feature comparison

| Capability | Kingdom Sponsor | Giver (ZM) | BlessPay (GH) | Treasurer (ZM) |
|---|---|---|---|---|
| Multi-org open marketplace (anyone can host) | ✅ | ❌ per-church | ❌ per-church | ❌ per-church |
| Campaigns with OR without a target goal | ✅ | Goal only | ❌ | Pledges |
| Phone (OTP) login, no email/password | ✅ | ❌ email | ❌ | ❌ |
| Superadmin host approval (trust layer) | ✅ | ❌ | ❌ | ❌ |
| Auto payout to host mobile money | ✅ | ✅ | ✅ instant | ❌ |
| Public share page + QR + WhatsApp | ✅ | ✅ links only | ❌ | ❌ |
| Donor gamification (usernames, badges, leaderboard) | ✅ | ❌ | ❌ | ❌ |
| Public transparency (raised, avg, per-day, on-track date) | ✅ | partial | ❌ | ❌ |
| Anonymous giving | ✅ | ❌ | ✅ | ❌ |
| Recurring / scheduled giving | ❌ (planned) | ✅ one-time+recurring | ✅ recurring/threshold | ✅ pledges |
| PDF receipts & exports | ❌ | ✅ reports | ✅ receipts | ✅ PDF receipts |
| Donation categories (Tithe/Offering/Fund) & departments | ❌ | ✅ departments | ✅ multiple funds | ✅ categories |
| Multi-campus / multi-branch | ❌ | ✅ | ✅ multi-campus | ✅ branches |
| Push notifications | ❌ (planned) | ✅ | ✅ | ❌ |
| Multi-currency | ❌ ZMW only | ❌ ZMW | ❌ GHS | ✅ 15+ currencies |
| White-label / custom domain | ❌ | ✅ | ❌ | ❌ |
| Website embeddable links | ❌ (share page = close) | ✅ | ❌ | ❌ |

## What the competitors have that we should have

High priority (usage drivers):
1. **Recurring giving** — Giver & BlessPay both offer it. BlessPay even does
   *threshold-based* giving. Start with scheduled reminders (see ROADMAP.md).
2. **PDF receipts / donation history** — donors expect a receipt for records; hosts
   need exports for their own books and regulators.
3. **In-app notifications** — donation confirmed, payout sent, goal reached (FCM).
4. **Pledge / category support** — churches run Tithe / Offering / Building-Fund
   streams, not just "one campaign". A `category` field on campaigns covers 80% of this.

Medium priority:
5. **Multi-branch / multi-campus** — denominations manage one account for several
   congregations (Treasurer's standout feature).
6. **Multi-currency** — Treasurer leads here; useful once we expand beyond Zambia.
7. **White-label / custom domain** — Giver sells this to "growing churches"; a good
   paid tier later.

## What we have that competitors don't (keep & market)

1. **Open, neutral marketplace** — anyone (church, NGO, school, youth group, family)
   can host. Every Zambian competitor is a single-church walled garden; GoFundMe-style
   openness doesn't exist locally yet.
2. **Goal or no-target campaigns** — a "sponsor a youth trip" drive and a "church
   building fund" fit one app.
3. **Host verification/approval + superadmin oversight** — a trust layer that reduces
   fraud vs unmoderated platforms; also gives us an audit trail to show partners.
4. **Public transparency & shareability** — QR, WhatsApp deep-link, per-campaign
   stats, badges/leaderboards drive word-of-mouth in mobile-messaging-heavy Zambia.
5. **Phone-first OTP login** — lowest-friction onboarding for a population that uses
   mobile money, not email.
6. **Fair pricing story** — flat K3 or 1% (no monthly fees, no subscription) vs Giver's
   tiered subscriptions and BlessPay's 2.5%. We are cheaper at the low end.

## Pricing benchmark

- Giver: from 1.5%/transaction, no monthly fees; paid tiers add analytics/white-label.
- BlessPay: 2.5% flat.
- Kingdom Sponsor: 1% (min K3) on donations, 1% on host payouts.
  → We're undercutting on donations; keep K3 floor documented and revisit once volume
  justifies (see revenue analysis).

## Bottom line

Our moat is **openness + transparency + verification** that church tools don't offer,
combined with Zambia's native mobile-money rails. To win against Giver specifically,
the must-close gaps are **recurring giving**, **receipts/export**, and **categories**.
Everything else (multi-currency, white-label) is a later paid tier.
