# Seven-day transaction list

Show only transactions dated today or in the previous six calendar days in the native Activity tab. Use the device calendar/time zone, exclude future calendar days, and refresh the window through SwiftUI TimelineView. Apply this window before search, kind/category filters, sorting, grouping, and summary totals. Label the window clearly. Saved history and historical Overview analytics remain intact.

Validation: test inclusive/exclusive boundaries, local midnight rollover, daylight-saving transitions, totals and grouping. Run the full native logic suite and Activity filtering UI flow, build signed Release, install in place, and verify stored records are preserved. Date-boundary tests first failed because the new helper did not yet exist.

Verification: all 59 native logic tests passed; the Activity income-filtering UI test passed and verified the “Past 7 days” label. Signed Release build succeeded. A private pre-update backup contains all 14 existing records. App build number increased to 2.

Installed in place on the paired iPhone. Post-install database comparison confirms all 14 original entries are unchanged.
