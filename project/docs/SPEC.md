# Project Specification

Status: active — first repository-local Base adoption

## Purpose

`weather-widget` is a static weather Web/PWA. The existing browser UI, weather
data flow, manifest, service worker, icons, and offline behavior remain the
Project's implementation.

## Acceptance

1. Existing static Web and PWA behavior remains unchanged.
2. `knt doctor` validates the local Project Overlay and Base.
3. `knt base-check` detects changes to common Base files.
4. Existing manifest and service worker remain the authoritative PWA boundary.
5. No Domain file is moved merely to satisfy the Base structure.

## Ownership boundary

- Weather UI, data handling, browser storage, PWA cache policy, and release
  behavior remain in the existing repository root.
- KiNoTch Base files and repository operations live under `.kinotch/`.
- The Project Manifest, contracts, and adoption state live under `project/`.
- PWA Default helpers are not generated because equivalent Project files already
  exist.

## Commands

This static repository currently has no Project-owned setup, test, build, or
deploy command registered. `knt verify` therefore completes without invoking a
toolchain command.

## Constraints

The Base does not impose a framework, generated PWA asset, cache policy, or
weather data contract on this Project. Existing implementation boundaries remain
authoritative.
