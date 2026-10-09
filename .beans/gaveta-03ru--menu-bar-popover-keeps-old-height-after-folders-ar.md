---
# gaveta-03ru
title: Menu bar popover keeps old height after folders are removed
status: completed
type: bug
priority: normal
created_at: 2026-10-09T01:30:29Z
updated_at: 2026-10-09T01:34:22Z
---

After removing folders, reopening the popover shows a taller blurred panel with the content centered. Suspected: ScrollView + fixedSize reports a stale height. Step 1: plain VStack for few rows, ScrollView with fixed height only above a threshold. Steps 2/3 (resize NSWindow, computed height) if needed.

## Summary of Changes

Step 1 was enough: the folder list is a plain VStack up to 6 rows (exact height reported to the popover) and a fixed-height ScrollView above that. Confirmed by the user; steps 2 and 3 not needed.
