# Project Specification

Status: active — first repository-local Base adoption

## Purpose

`weather-widget` is currently a static weather Web embed. The active browser UI
is the existing `weatherwidget.io` integration in `index.html`.

Checked-in `manifest.webmanifest` and `service-worker.js` files are retained as
Project-owned PWA artifacts, but the current HTML does not activate them and the
repository does not currently claim installability or offline behavior.

## Acceptance

1. Existing static Web weather behavior remains unchanged.
2. `knt doctor` validates the local Project Overlay and Base.
3. `knt base-check` detects changes to common Base files.
4. Dormant manifest/service-worker artifacts remain retained without being
   interpreted as active PWA behavior.
5. No Domain file is moved merely to satisfy the Base structure.

## Ownership boundary

- Active weather UI and weather-data embed behavior remain in the existing
  repository root.
- Retained manifest/service-worker artifacts remain Project-owned, but their
  presence alone does not define current installability, cache policy, or
  offline behavior.
- KiNoTch Base files and repository operations live under `.kinotch/`.
- The Project Manifest, contracts, and adoption state live under `project/`.
- PWA Default helpers are not generated merely because dormant Project files
  exist.

## Commands

This static repository has no Project-owned setup, build, or deploy command.
`knt verify` runs a Project-owned static contract test that checks the accepted
weather embed and dormant-PWA boundary without browser automation.

## Constraints

- The Base does not impose a framework, generated PWA asset, cache policy, or
  weather data contract on this Project.
- PWA activation, icon creation, service-worker registration, installability,
  and browser/offline verification are explicit future work and are not inferred
  from the retained artifacts.
- The static verification gate is a regression check only; it does not activate
  or claim browser/PWA behavior.
- Existing active static Web behavior remains authoritative until such work is
  explicitly specified and verified.
