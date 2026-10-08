# Expense Tracker

Track spending with a Liquid Glass iOS app (React Native / Expo) plus a React + FastAPI web version.

## Download the iPhone app

Grab **ExpenseTracker.ipa** from the [latest release](../../releases/latest). It is **unsigned** (this isn't on the App Store), so install it with a sideloading tool, which signs it with your own Apple ID:

- **[Sideloadly](https://sideloadly.io)** (Mac/Windows): plug in your iPhone, drag in the `.ipa`, enter your Apple ID, press Start.
- **[AltStore](https://altstore.io)**: install AltServer on your computer, then open the `.ipa` in AltStore on the phone.

Then on the iPhone: **Settings → General → VPN & Device Management →** trust your Apple ID, and enable **Settings → Privacy & Security → Developer Mode**.
Free Apple IDs expire after 7 days (re-sideload to refresh). Liquid Glass needs iOS 26+; older iOS gets a blur look. Data is stored on the device only.

## Web version

React (Vite + Recharts) frontend, FastAPI + SQLite backend.

```
./start.sh        # then open http://localhost:5173
```

- **Dashboard:** summary cards, category donut, 12‑month bar chart (click a bar to focus a month), period picker.
- **Transactions:** search, category filter, sortable columns, pagination, edit & delete.
- **Add expense:** form with validation; category colors are fixed per category.
- **Storage:** data lives in `backend/expenses.db`. If the backend isn't running, the app falls back to `localStorage`.
- **Tests:** `cd backend && .venv/bin/pytest`
- **API:** `GET/POST /api/expenses`, `PUT/DELETE /api/expenses/{id}` (docs at `:8000/docs`).

## iOS app (`mobile/`)

React Native + Expo app with the same features, stored on-device (works offline).

```
cd mobile && npx expo start --ios     # opens in the iOS Simulator via Expo Go
```

- **Overview:** animated gradient hero total, 6‑month bar chart (tap or drag across bars to focus a month), category donut with progress rows.
- **Activity:** search, category + sort chips, expenses grouped by day.
- **Add/edit:** tap the **+** in the floating tab bar, or tap any expense to edit or delete it.
- Liquid Glass UI (native `expo-glass-effect` on iOS 26+, blur fallback), morphing liquid toggle, light/dark mode, haptics, VoiceOver labels, Reduce Transparency support.

### Components ported from easyui (web → React Native)
- `src/OriginDropdown.js` — menu that grows out of its trigger's corner (scale .96→1 + 8pt slide, snappy spring, flipping chevron, tap-outside to close). Used for the **Period** picker and the Activity **sort** menu.
- `src/PullToRefresh.js` — `idle → pulling → ready (68pt) → refreshing → complete` pill that follows the pull, flips its arrow at the threshold, pins while refreshing, then shows "Updated". Re-reads on-device storage.
- `src/LiquidToggle.js` — morphing-blob switch ("Group by day").
Native Liquid Glass needs an iOS 26+ simulator/device; older iOS uses a blur fallback.

### Install on a physical iPhone
`cd mobile && npx expo prebuild --platform ios` then build Release with automatic signing:
`xcodebuild -workspace ios/ExpenseTracker.xcworkspace -scheme ExpenseTracker -configuration Release -destination 'id=<UDID>' -allowProvisioningUpdates DEVELOPMENT_TEAM=<team> build`
and `xcrun devicectl device install app --device <UDID> <path-to>.app`. A free Apple ID profile lasts 7 days.
