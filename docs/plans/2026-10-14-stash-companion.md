# Stash in the app and Dynamic Island

User-approved scope: add the uploaded Stash mascot to both the native app and Dynamic Island. Preserve the supplied 18 poses, layered artwork, and animation timings. Existing balances, allowance rules, and transactions remain authoritative.

## Design

The Overview balance card contains an animated Stash. Its resting pose follows the actual current balance: stuffed at 80% or more of the allowance, happy from 20%, running low below 20%, empty at zero, and overspent below zero. Historical analytics use the chart pose. Saving an expense or receipt briefly plays counting or saving; a weekly reset noticed by the running app plays refill. Tapping Stash opens a native companion sheet with a wave, animation previews, and Show/Hide Dynamic Island.

The app renders the original layered PNG artwork with native SwiftUI Canvas transforms from a generated animation manifest. Animation pauses for Reduce Motion, backgrounding, and offscreen views. All 18 animations remain available in the companion sheet; previews never affect money or the Island.

A WidgetKit extension displays small, precomposed Stash portraits and the current balance through ActivityKit. It offers compact, minimal, expanded, and Lock Screen layouts. No HTML, remote server, push credentials, or shared database are needed. App changes update the existing activity; repeated Show requests reuse it. Hide ends it. Permission and start failures are reported in the sheet. The Island uses short state transitions, not continuous animation. Content becomes stale at the scheduled allowance reset and replaces the amount with a refresh prompt. Tapping it opens Stash; the expanded layout links to adding an expense. The sheet explains the system's eight-hour limit and Lock Screen visibility.

## Implementation and validation

- [x] Validate mood boundaries, decimal amounts, content expiry, and lifecycle handling with native tests. Initial mood/content tests failed before the types existed; the complete suite is green.
- [x] Generate a faithful layer/keyframe manifest and small WidgetKit portraits from the supplied art. Validate all referenced images and animations.
- [x] Add native animation rendering, the companion sheet, and balance/entry reactions.
- [x] Add and embed the ActivityKit widget extension and route links back into the app.
- [x] Run logic and UI tests, inspect app/Island screenshots, and request a read-only review.
- [x] Build a signed update. Install in place only if the paired phone is available; preserve its data.

Review focus: zero and negative balances; a manual correction followed by spending; reset while the app is suspended; disabled/dismissed Live Activities; duplicate start and overlapping content updates; Reduce Motion and large text; sample-data labels and preview isolation.

## Review notes

Read-only review found an ended-activity lifecycle edge: an activity can remain on the Lock Screen after iOS removes it from Dynamic Island. Refresh now reconciles even without an active Island, removing ended cards on the same serialized worker. Hide also dismisses all non-dismissed handles. A routing concern was checked with a UI test: opening Stash from the balance editor, then opening Add from the allowance editor, both passed without a routing change.

Assets: 18 native poses, 61 keyframe tracks, four original PNG atlases, and small 30-point portraits for WidgetKit. Screenshots in `docs/design-previews/stash-*.png` use isolated test data. The app and embedded extension use version 2.0.0 (9).

Final validation: 78 native logic tests and nine UI flows passed. UI coverage includes balance corrections shared across screens and relaunch, subsequent spending, preview isolation, first Monday reset scheduling, allowance persistence, sample exit, Undo, largest text, editor deep links, Live Activity start/update/stop, actual compact Island amounts, and the expanded Island Add button. App and widget signed Release build and strict signature verification passed. The simulator runner emitted a post-test diagnostic-collection warning about its `simctl` path; the tests completed successfully and all screenshot attachments exported.

Installed in place on the paired iPhone and launched with `expensetracker://stash`. Device read-back confirms version 2.0.0 (9). Private pre/post-update backups contain all 14 transaction records with every persisted field identical. The weekly amount, allowance start, correction amount, and correction expiry are unchanged. The correction's save timestamp was refreshed after launch; its monetary value is identical. Recovery files remain git-ignored.
