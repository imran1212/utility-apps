# Budget Planner by SVSystem

An original, offline-first Flutter budget planner for the SVSystem utility-app portfolio.

## Cashew research reference

The open-source project [Cashew](https://github.com/jameskokoska/Cashew) was reviewed for product research and feature inspiration. This application is an independent implementation; no Cashew source files, assets, branding, or UI code are copied.

Cashew is GPL-3.0. Any future decision to incorporate or modify its code must first undergo a GPL compliance review, including source-distribution obligations. The current MVP is developed independently to preserve a clean licensing path.

## Current MVP

- Monthly spending budget
- Income and expense transactions
- Expense and income categories
- Current-month income, spending and remaining budget
- Spending by category
- USD and GBP display preference
- Local persistence using SharedPreferences
- SVSystem blue/navy/white/yellow identity with a dedicated Budget Planner mark
- Branded Android adaptive launcher icon and navy launch screen
- In-app logo and 'by SVSystem' attribution
- AdMob banner configured with the app's registered AdMob production banner unit ID (live serving remains subject to review)

## Development

From the monorepo root:

```bash
melos bootstrap
bash tool/build_budget_planner.sh
```

The build script creates the Android platform scaffold if it is not present, applies the app label, SVSystem launcher/splash branding and registered AdMob application ID, runs analysis/tests, and builds APK/AAB.

## Important limitations before production

- USD/GBP selection changes display formatting only; it does not convert existing transaction values.
- Data is stored locally on this device; backup/sync is not included.
- AdMob currently shows the app as requiring review; live ad serving may be limited until review is complete. Never click your own ads.
- No paid Premium purchase flow is enabled in this MVP.
- Add a public privacy policy and complete Play Console declarations before release.
- Verify financial totals, date handling, accessibility and Android lifecycle behavior on real devices.
