---
# gaveta-03ru
title: Menu bar popover keeps old height after folders are removed
status: in-progress
type: bug
priority: normal
created_at: 2026-10-09T01:30:29Z
updated_at: 2026-10-10T01:42:51Z
---

After removing folders, reopening the popover shows a taller blurred panel with the content centered. Suspected: ScrollView + fixedSize reports a stale height. Step 1: plain VStack for few rows, ScrollView with fixed height only above a threshold. Steps 2/3 (resize NSWindow, computed height) if needed.

## Summary of Changes

Step 1 was enough: the folder list is a plain VStack up to 6 rows (exact height reported to the popover) and a fixed-height ScrollView above that. Confirmed by the user; steps 2 and 3 not needed.

## Regression

Step 1 (plain VStack) did not fix it: the user reproduced the bug again. Moving to step 2: measure the content height and resize the popover NSWindow, keeping its top edge anchored.

## Summary of Changes

Root cause: the MenuBarExtra(.window) panel is only ever grown by SwiftUI, and its own hosting view reports a zero fitting size (and GeometryReader measures 0), so shrinking was never triggered. Fix: PopoverSizer measures the ideal height on a separate NSHostingView of the same MenuView (same observable state) and resizes the panel on open, on external resizes and when folders/messages change, keeping the top edge anchored. Verified with real mouse clicks (open, +/- folders while open and closed, scroll case, pause) and 4 unit tests. GAVETA_DEBUG_SIZER=1 enables a diagnostic log.

## Cleanup

Follow-up: remove leftovers of the debugging (debug log, anchoredTop, isApplying, redundant observer) and the step 1 VStack/ScrollView split; add Scripts/check-popover.sh as the real-panel regression check.

Cleanup done: removed debug log, anchoredTop, isApplying, the redundant didBecomeKey observer and the VStack/ScrollView split (back to the original ScrollView).
