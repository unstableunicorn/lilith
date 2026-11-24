---
id: 0001
title: Sharing from the sharer's pod with a per-share key
kind: decision
status: closed
updated: 2026-11-24
---

# Sharing from the sharer's pod with a per-share key

**Status:** decided with the owner 2026-11-23 (lilith#25), built in PRs #26 to #37, proven end to end on the live server with the solidpod agent checking the ACL on disk.

## Decided

- Nothing on any pod is ever opened to `foaf:Agent` or `AuthenticatedAgent`; the pod stays owner-only except the share folders.
- One mechanism: a folder `lilith/data/shares/<id>/` on the **sharer's** pod, ACL owner RWC + recipient Read (`accessTo` and `default`), id = first 16 hex of sha256(recipient WebID).
- Encrypted pods share a **per-share key** (16 Crockford base-32 chars, AES key = sha256(code)), as a compact JWE (`alg dir`, `enc A256GCM`); the pod's own key is never shared. Plain pods share plain JSON.
- Transport of the invite: a link or QR (`?share=<WebID>&code=<code>`), kept across login.
- Expiry: 30 days, 90 days, until revoked, or a custom date; a sweep closes expired shares and a reminder fires the morning after the end day.
- Report shares write `report.pdf` and `cycle_data.csv` in the clear for health providers.

## Alternatives rejected

- solidpod's `grantPermission` and the data browser's share feature: they need the recipient to read the sharer's pod root and push the pod's own key through the recipient's inbox, which opens the pod wider than the owner accepts.
- A backend service relaying shares or email: later, after the store release (decision to come).
- Writing into the recipient's pod: the sharer would need write access there.

## Notes

- `writePod(createAcl: false)` is required; solidpod's default per-file ACL locks the recipient out.
- solidpod's `createDir` POSTs to the parent, so `shares/` must exist before a share folder (PR #30).
