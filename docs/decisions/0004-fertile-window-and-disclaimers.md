---
id: 0004
title: Fertile window as information, with two switches and two disclaimers
kind: decision
status: open
updated: 2026-11-24
---

# Fertile window as information, with two switches and two disclaimers

**Status:** decided with the owner 2026-11-24 in the feature pass (items 7 and 8); to be built as the second feature PR, after the calendar and the page settings screen.

## Decided

- A **page settings** screen (per device, `SettingsStore`) chooses what Today, Log and History show. Two switches concern the fertile window: **Trying to conceive** and **Show fertile window**. Both off by default.
- The window is six days ending the day after the estimated ovulation, shown as "likely fertile" on Today and the calendar, only when temperature or a positive test supports the estimate. Never red/green days.
- **Trying to conceive on:** the window shows with "Lilith estimates, it does not confirm" and no contraception line.
- **Show fertile window on, trying to conceive off:** the window shows with "Lilith estimates, it does not confirm. It is not a contraceptive method and cannot tell you when it is safe to have unprotected sex."
- **Both off:** no window; the ovulation estimate on Today keeps the short "estimates, does not confirm" line.
- The PDF carries the same sentence as the screen that produced it.

## Alternatives rejected

- Always-on disclaimer (Claude's first proposal): pointless for someone trying to conceive.
- Red/green days: that is a contraceptive claim only Natural Cycles is cleared to make.
- A "mode" selector: factors and switches cover it without a mode concept.
