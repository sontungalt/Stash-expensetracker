# Restore the existing Swift iPhone app

The initial workspace inspection found only the legacy Expo app, but recovery investigation located the existing SwiftUI + SwiftData implementation in the `ui-refresh` worktree. Use that implementation; do not introduce a new JSON store or change the existing database model.

## Findings
- Installed bundle: `com.sontungle.expensetracker`, version 1.0.0 at inspection.
- Phone sandbox backed up privately to the git-ignored `recovery/iphone-before-swift-20261013/` before any installation.
- Existing SwiftData database contains 14 non-sample entries: 8 spent, 6 received. Legacy AsyncStorage has one separate entry.
- Swift source copied, including uncommitted UI/allowance improvements, from the existing worktree into `ios/` here. Source worktree remains untouched.
- The provisional standalone JSON implementation was moved out of this repository to `/private/tmp/expense-tracker-provisional-native-20261013` and will not be installed.

## Execution
1. Back up and inspect existing storage without modifying it. Done.
2. Restore existing Swift app into this workspace and generate its Xcode project. Done.
3. Run native unit tests and selected simulator UI flows, and build a signed Release for the connected phone.
4. Install in place without uninstalling or replacing data files. Launch normally, without UI-test/sample flags.
5. Verify the existing database rows remain intact after launch and report installed version.

The existing SwiftData model, default.store location, preferences, bundle identifier, and signing team are preserved. Native development continues in `ios/`; `mobile/` stays as the legacy Expo source.

## Verified installation
- Xcode 26.6 signed Release build succeeded; installed version 2.0.0 (build 1) on the paired iPhone.
- Read-back after installation found all 14 original transaction records with every persisted field identical to the pre-install backup.
- All 56 native unit tests passed, and the tab/add-button UI smoke test passed.
- A pre-existing UI test for an unfinished Activity balance editor fails because that editor does not exist in the recovered app; this is not a database or migration failure. The copied test is preserved, not disabled.
- Initial launch was blocked by the phone lock screen; user was asked to unlock it for launch verification.
- Additional simulator flows passed: Activity income filtering and adding spending/income with correct weekly allowance handling (2 tests, 0 failures).

Final device verification: Swift app launched successfully. Database contains 14 records; all 14 originals remain field-for-field identical, the separate legacy AsyncStorage expense remains preserved in the backup.

Launch caveat: iOS accepted one launch request, but no persistent app process was confirmed. A subsequent diagnostic launch explicitly failed because the phone was locked again. Final on-phone visual/startup verification remains pending unlock; no startup crash was established. Installation and preservation of the 14 original records were verified independently of launch.
