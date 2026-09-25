# Current State

Base version: `0.3.8`

Last verified: 2026-09-23 — KiNoTch Base v0.3.8 Canary adoption

## Implemented

- Repository-local KiNoTch Base v0.3.8 and Project Overlay
- `web-app` Surface declaration
- Existing PWA manifest and service-worker artifacts retained
- Existing static HTML, CSS, JavaScript, and weather embed retained
- Existing Domain files remain at their original root paths; no bulk move was performed

## Default state

- `web-app`: `OVERRIDE` — existing static Web implementation is authoritative
- `pwa`: `OVERRIDE` — checked-in manifest/service-worker artifacts remain Project-owned, but the current HTML does not activate them

## Known constraints

- PWA cache policy, browser behavior, and weather data handling remain Project-owned.
- The current HTML does not link the manifest or register the service worker, so installability is not currently claimed.
- No icon assets are present in the current tree; stale references to the missing icon paths were removed during maintenance.
- This repository has no common setup/test command configured; `knt verify` is
  intentionally a no-op until a Project-owned check is defined.
- The Base does not replace existing PWA assets with generated helpers.

## Next work

1. Preserve the existing static weather embed as the current Project override.
2. Add Project-specific browser/PWA verification only when a real check is defined.
3. Treat PWA activation or icon design as explicit future work rather than maintenance inference.
4. Consider further Default adoption only where it removes a real duplicate.

## Verification

- `knt doctor`
- `knt base-check`
- `knt verify`
- Changed-scope static review of Project-owned PWA metadata
