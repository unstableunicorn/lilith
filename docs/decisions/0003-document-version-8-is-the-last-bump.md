---
id: 0003
title: Document version 8 is the last schema bump
kind: decision
status: closed
updated: 2026-11-24
---

# Document version 8 is the last schema bump

**Status:** decided in the roadmap plan (approved 2026-11-24): exactly two bumps, v7 (period end and flow) and v8 (wearable nights). Both are merged.

## Decided

- Every device, including share recipients, must update before a newer document loads, so a bump is costly. **No further bumps are planned.**
- A new field is **optional in the codec**: it loads as absent or empty from a document that lacks it, and an older app that does not know it drops it on save, which is accepted for the features that follow (notes, tags, moods, factors, page settings).
- Enum additions are read leniently: an unknown value is skipped, not an error.
- Per-device settings (reminders, page settings, app lock) live in `SettingsStore`, not in the pod document.

## Alternatives rejected

- A bump per feature: forces every device to update for a day note.
- A separate document per feature: more files, more ACL work for shares, no gain.
