# Expense Tracker

A native **SwiftUI + SwiftData iPhone app** for tracking spending and money received, plus a separate React + FastAPI web version.

## Native iPhone app (`ios/`)

The Swift app replaces the older Expo implementation in `mobile/`. Continue iPhone development in **`ios/ExpenseTracker.xcodeproj`**, not `mobile/`.

- **Requirements:** iOS 26+; this project is developed with Xcode 26.6 and Swift 6.
- **Weekly allowance:** starts at **$50**, editable from Overview. The first reset is scheduled for the next Monday at local midnight and saved once; relaunching never postpones it. Until then, the existing balance (recorded income minus spending) is preserved. From that Monday onward, a fresh Monday–Sunday budget applies with no rollover or need to add a receipt every week. Recorded income stays in Activity and does not double-count the active allowance.
- **Overview:** defaults to **This week**, showing allowance left (or overspent) and spending. At Monday midnight the weekly spending window resets; transaction history is never deleted. Monthly and All time views show historical spending, with category breakdowns and a monthly chart.
- **Money left:** Overview and Activity share the same current balance. Tap **Edit** on the Overview balance card, or the pencil in Activity, to enter what you actually have (including zero). The editor shows the previous balance and has a clear-amount button and keyboard Done control. The correction survives relaunches, future spending reduces it, and it expires at the scheduled Monday allowance reset. Transaction history and category totals stay unchanged.
- **Activity:** transactions from the past 7 calendar days (today plus the previous six), with search, In/Out filters, category chips, sorting, and optional day grouping. Older transactions remain saved and available to historical Overview analytics.
- **Add/edit:** Spent and Received entries, recent-entry shortcuts, amount validation, explicit save states, and a five-second Undo banner after deletion.
- **Native UI controls:** origin dropdowns, a liquid group-by-day toggle, and a draggable Liquid Glass tab dock. The dock adapts to larger text and respects Reduce Motion and Reduce Transparency. The labelled weekly allowance row opens its settings.
- **Stash companion:** the supplied mascot is rendered natively beside Money left. Its mood follows the current balance, including manual corrections; saving entries triggers short reactions. Tap Stash for all 18 animation previews and **Show in Dynamic Island**. The Live Activity displays the same balance on Dynamic Island and the Lock Screen, with an Add expense link in its expanded view. iOS limits active sessions to eight hours; expired allowance data shows a refresh prompt until the app reopens. Animation previews do not change the Island or your money. Reduce Motion shows a still pose.
- **Persistence:** SwiftData, with an import path for expenses saved by the previous Expo app. Keep the existing bundle identifier when installing an update; do not uninstall the old app first if you need its data.
- **Sample data:** try the app without entering transactions; Exit removes sample entries while keeping your own entries.

### Run in the simulator

Open `ios/ExpenseTracker.xcodeproj`, choose the **ExpenseTracker** scheme and an iPhone simulator, then Run.

From the repository root, run the native unit and UI tests with:

```bash
xcodebuild test -project ios/ExpenseTracker.xcodeproj -scheme ExpenseTracker \
  -destination 'platform=iOS Simulator,name=Expense Balance QA' \
  -parallel-testing-enabled NO
```

Use a simulator name installed on your Mac. UI tests launch with `-uiTesting` and use an in-memory store, separate from normal app data.

### Run on your iPhone

Open the same Xcode project, choose your paired iPhone as the destination, configure your signing team under **Signing & Capabilities**, and Run. The project's deployment target is iOS 26.0.

This is a native app: an Expo Go link or `expo start --tunnel` does **not** launch this Swift build. Installing it on a phone requires a signed native build; the Mac must be able to reach the paired phone for an Xcode deployment.

### Project structure

- `ios/ExpenseTracker/App/` — app entry point, tabs, sheets.
- `ios/ExpenseTracker/Features/` — Overview, Activity, add/edit form, and native UI controls.
- `ios/ExpenseTracker/Logic/` — amount parsing, analytics, filters, dates, and animation/layout math.
- `ios/ExpenseTracker/Data/` — persistence and legacy import.
- `ios/ExpenseTrackerTests/` — native unit tests.
- `ios/ExpenseTrackerUITests/` — simulator UI flows.
- `ios/StashShared/` — shared Live Activity content and small mascot portraits.
- `ios/StashIsland/` — embedded WidgetKit Live Activity extension.
- `docs/mascot/` — original animation reference and atlases; `scripts/build_stash_manifest.py` and `scripts/build_stash_portraits.swift` regenerate the native assets.
- `ios/project.yml` — XcodeGen project definition; regenerate the committed Xcode project when changing targets or source membership.

## Web version (`frontend/` and `backend/`)

React (Vite + Recharts) frontend, FastAPI + SQLite backend.

```bash
./start.sh        # then open http://localhost:5173
```

- **Dashboard:** summary cards, category donut, 12-month bar chart, and period picker.
- **Transactions:** search, category filter, sortable columns, pagination, edit and delete.
- **Add expense:** validated form with fixed category colors.
- **Storage:** `backend/expenses.db`, with a `localStorage` fallback when the backend is unavailable. This is separate from the native app's SwiftData store.
- **Tests:** `cd backend && .venv/bin/pytest`
- **API:** `GET/POST /api/expenses`, `PUT/DELETE /api/expenses/{id}` (docs at `:8000/docs`).

## Legacy Expo app (`mobile/`)

Retained as the previous implementation and migration reference. Its JavaScript build, tests, or Expo preview do not verify the native Swift app.
