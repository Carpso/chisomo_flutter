# Kingdom Sponsor - Flutter app

Neutral fundraising platform app (donate + host campaigns). Backend: https://github.com/Carpso/chisomo

- **Deployed API**: https://kingdom-sponsor-api.godfreymoseskalambo.workers.dev
- **USSD service**: `*384*3448#` (Africa's Talking sandbox)

## Run
```powershell
flutter pub get
flutter run
```

## Configuration
Edit `.env`:
- `API_URL=https://kingdom-sponsor-api.godfreymoseskalambo.workers.dev` — deployed Worker URL.
- Use `http://10.0.2.2:8787` for Android emulator local dev, `http://localhost:8787` for web/iOS simulator.

## Host approval
Anyone can apply to host (Host dashboard > Become a host). A superadmin approves or rejects; only approved hosts can create campaigns. Superadmin phone numbers are configured in the backend SUPERADMIN_PHONES.

## Admin dashboard
Superadmins get a shield icon on the campaigns list opening the admin dashboard: platform stats (total raised, fees, daily rate), host application approvals with reason, top campaigns, top supporters, recent contributions.

## Flow
1. **Login** — phone OTP (Africa's Talking SMS via backend). Sandbox mode returns the code in the API response for testing.
2. **Browse campaigns** — public list with progress bars; detail page shows donors.
3. **Donate** — amount presets, optional name/anonymous, mobile number → Lipila USSD prompt on the phone → app polls until confirmed. USSD donations are recorded with the `USSD-` prefix reference ID.
4. **Host dashboard** — create campaigns, see balance + transactions, withdraw anytime, end campaign (sweeps remainder).

## Structure
```
lib/
  core/        api client, theme, router, money formatting
  features/
    auth/      OTP login
    campaigns/ list, detail, models, controllers
    donate/    donate flow with status polling
    host/      dashboard + create campaign + apply to become host
    admin/     superadmin dashboard (stats, approvals, leaderboards)
```
