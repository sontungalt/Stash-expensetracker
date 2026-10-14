# Native daily-use UI polish

The requested continuation focuses on the existing SwiftUI app in `ios/`. Keep the current balance calculations and saved transactions intact while improving the balance card, amount editor, allowance settings, and Liquid Glass navigation.

## Changes

- Move balance editing onto the Overview balance card as a compact glass Edit control. At accessibility text sizes, show a pencil with the full VoiceOver label.
- Replace the unlabelled allowance settings icon with a row showing “Weekly allowance” and its amount. Explain pending and active allowance schedules accurately in the editor.
- Give the balance editor a currency prefix, clear-amount control, keyboard Done button, previous-balance context, and shorter explanations. Preserve save, cancel, zero, validation, and shared balance behavior.
- Adapt the tab dock to available width and Dynamic Type. Accessibility sizes use text-only segments; regular sizes retain icons. Keep dragging, tapping, selection feedback, Reduce Motion, and Reduce Transparency behavior.
- Build version is now 2.0.0 (8). No schema, financial calculation, or stored-data changes.

## Verification

- 71 native logic tests passed.
- Nine distinct selected UI flows passed across the validation runs: clear/replace amount, cancel/validation/zero, shared balance and persistence, deferred first reset, allowance editing, tab dragging/tapping, largest text tab navigation, period selection, and chart scrolling.
- The new clear-amount test failed before implementation. The large-text containment check reproduced an overflowing tab label; the final layout and screenshots confirm it is contained. Text-only SwiftUI buttons merge their accessibility label, so the test checks their full label instead of requiring a child text element.
- The existing chart test selected the section title via an ambiguous label. It now targets the chart identifier, brings the plot on screen, and verifies that a vertical drag moves the scroll position without changing the selected month.
- Read-only code review found the initial largest-text tab overflow and Edit word wrapping. Both were fixed and visually checked. The final affected UI checks passed.
- Signed Release build succeeded; code-signature verification passed. Screenshots are in `docs/design-previews/ui-polish-*.png` (sample data or isolated UI-test data).

The paired iPhone remained unavailable during this pass. Build 8 is prepared but was not installed on that phone. The updated app is running in the simulator with isolated sample data.
