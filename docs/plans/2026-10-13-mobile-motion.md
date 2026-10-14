# Mobile motion implementation plan

**Goal:** Add subtle pop feedback and spring entrances to the iPhone expense tracker.

**Architecture:** Extend the existing React Native Animated helpers without adding dependencies. Share the system Reduce Motion preference through context, stop animations on cleanup, and preserve existing expense persistence changes.

**Tech stack:** Expo SDK 57, React Native 0.86, React 19.

1. Extend `mobile/src/hooks.js` with a motion preference provider, reusable animated pressable, selection pops, and spring card entrances. Keep disabled controls inert and existing touch/accessibility props intact.
2. Apply feedback to tabs, category chips/tiles, expense rows, recent expense shortcuts, and empty-state actions in `App.js`, `History.js`, `AddSheet.js`, and `Overview.js`. Pop the category badge when selection changes. Respect Reduce Motion for the sheet and tab indicator.
3. Run mobile lint, JavaScript/JSX compilation with TypeScript, existing expense tests, and an Expo iOS export. Review the diff for layout and behavior changes. Animation feel still needs a device/simulator check if no native preview is available.

This is a reversible presentation change; use the existing regression tests and build checks rather than implementation-mirroring animation tests.

## Verification

- Mobile Expo lint passed.
- TypeScript JavaScript/JSX compilation check passed (`--allowJs --noEmit`; this JavaScript project has no configured full typecheck).
- All 10 existing expense entry and persistence tests passed.
- Expo iOS bundle export passed.
- No device/simulator visual check was performed; spring timing and feel remain to be reviewed on a device.
