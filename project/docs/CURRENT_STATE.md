# Current State

Last verified: 2026-09-23 — KiNoTch Base v0.3.5 Canary adoption

## Implemented

- Repository-local KiNoTch Base v0.3.5 and Project Overlay
- `web-app` Surface declaration
- Existing installable PWA manifest, service worker, icons, and static assets retained
- Existing Domain files remain at their original root paths; no bulk move was performed

## Default state

- `web-app`: `OVERRIDE` — existing static Web implementation is authoritative
- `pwa`: `OVERRIDE` — existing manifest and service worker are authoritative

## Known constraints

- PWA cache policy, browser behavior, and weather data handling remain Project-owned.
- This repository has no common setup/test command configured; `knt verify` is
  intentionally a no-op until a Project-owned check is defined.
- The Base does not replace existing PWA assets with generated helpers.

## Next work

1. Preserve existing PWA behavior as a Project override.
2. Add Project-specific verification only when a real check is defined.
3. Consider further Default adoption only where it removes a real duplicate.

## Verification

- `knt doctor`
- `knt base-check`
- `knt verify`
