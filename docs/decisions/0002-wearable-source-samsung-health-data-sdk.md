---
id: 0002
title: Wearable temperature comes from the Samsung Health Data SDK
kind: decision
status: in_progress
updated: 2026-11-24
---

# Wearable temperature comes from the Samsung Health Data SDK

**Status:** decided 2026-11-24 after research; the owner's device is a Galaxy Watch9. Model and seam built (PRs #53 to #55); the Android source waits on the SDK zip from the owner and a licence check of its `.aar`.

## Decided

- The series is `WearableNight(date, celsius, source)`: the night's skin temperature **as the device reports it**. The app compares: the predictor against the cycle's early nights, History against the mean of the nights shown. Skin runs below core and differs per device, so it is never mixed with oral readings.
- Source on Android: **Samsung Health Data SDK**, `DataTypes.SKIN_TEMPERATURE` (read-only; absolute °C with min, max and a series; Samsung Health 6.30.2+, Android 10+, any Android phone). Behind `WearableSource` through a Kotlin platform channel.
- Test builds use Samsung Health's developer mode (About > tap the version ten times > Developer Mode for Data Read). A partner request (package name + signing key SHA-256) is needed before a store release.
- Web and, for now, iOS: `NoWearableSource`; iOS later through the same seam (Apple Watch wrist temperature via HealthKit).

## Alternatives rejected

- **Health Connect:** Samsung Health does not write skin temperature or menstruation there (third-party reports to October 2026; Samsung's pages silent), so there is nothing to read.
- **Samsung Health Sensor SDK:** runs on the watch itself, needs a watch app, and does not share with Samsung Health.
- **Storing a delta from the vendor's baseline:** the SDK gives no baseline; storing one we computed would change stored values between syncs.

## Open

- Licence of the SDK `.aar`: may it be committed to a public AGPL repo? If not, CI downloads it, which may need a Samsung account.
- Whether Samsung Health's "Skin temperature during sleep" setting is on for the owner.
