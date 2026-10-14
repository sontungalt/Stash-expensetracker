# Editable current balance

Give Overview and Activity one shared current balance based on the existing weekly allowance schedule. Add “Edit money left” on both screens, including empty Activity. The user can enter the actual amount (including zero), review, save or cancel. Store an exact-decimal correction separately in app preferences; never fabricate or rewrite transactions. Additional spending continues to reduce the corrected balance. The correction expires at the next scheduled allowance reset.

Activity's seven-day/search/category filters affect transaction totals, not the current balance. Preserve historical Overview totals and weekly allowance configuration. Label the current balance and manual correction clearly. Keep the existing persistence UI test isolated using its own preferences suite.

Tests: 3.10→1.50 correction, subsequent spending, persistence/repeated edits, zero/invalid input, scheduled Monday reset, pre-activation reset; existing UI flow editing from Activity, switching to Overview and relaunching. Then build, back up and update the installed app without modifying stored transactions or automatically entering a user balance.

Implementation: shared CurrentBalance calculation and exact-decimal preference correction; editor on Overview and Activity; Activity current balance is independent of its seven-day list filters. Correction does not alter SwiftData or create transactions. UI-test preferences reset the correction between independent launches.

Review caught and fixed a real integration issue: TimelineView's scheduled timestamp predates corrections saved between minute ticks. Both screens now evaluate actual Date.now while the timeline still drives refreshes. The same UI tests reproduce and verify this fix. Read-only follow-up review found no further issues.

Signed build 3 succeeded. All 64 logic tests passed. Device became unavailable during backup/build; user was asked to reconnect and unlock before installation. Previous app/data are not changed by the pending update.

Final verification: all 64 native logic tests and 4 simulator UI tests passed. Covered save across tabs/relaunch, immediate rendering, subsequent spending, list-filter independence, cancel, invalid input and zero; weekly allowance and Activity filtering regressions also passed. Phone reconnected; targeted Application Support backup succeeded before installation. No correction is automatically applied; the editor starts with the current balance and the user saves the actual amount.
