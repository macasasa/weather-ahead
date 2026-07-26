# CLAUDE.md — Weather Ahead

## What it is

iOS app that reads Apple Calendar and turns it into a **weather timeline**: every calendar event
with a location becomes a stop on one scrollable day-by-day list with the forecast for that place
on that date.

**No backend, no accounts, no purchases, no analytics.** Everything is on-device plus Apple
WeatherKit. That's a deliberate product property — don't add a server without a real reason.

- App Store ID **6792811995** · bundle `com.nikolayukolov.weatherahead`
- **Public repo**, MIT licensed → assume every commit is world-readable
- SwiftUI, iOS 26+, Swift Charts, Liquid Glass

## Build

```bash
open WeatherAhead.xcodeproj        # normal development
# fresh clone that needs signing:
cp Config/Local.xcconfig.example Config/Local.xcconfig   # then fill in DEVELOPMENT_TEAM
```

**Signing config lives in xcconfig, never in the project file.** `Config/Base.xcconfig` is
committed and holds the shipping bundle id (a public identifier). `Config/Local.xcconfig` is
gitignored and holds personal overrides; `Base.xcconfig` pulls it in with `#include?`, so a fresh
clone builds without it. Don't move signing settings into `project.pbxproj`.

**WeatherKit is authorised per App ID.** Without a WeatherKit-enabled App ID the app still builds
and runs, but every row shows "No weather data" — that's expected, not a bug.

## Releasing

**Xcode Cloud** — workflow `release`, environment macOS Tahoe 26.5.1 (`25F80`) + Xcode 26.6
(`17F113`), both released builds.

```bash
asc xcode-cloud workflows --app 6792811995
asc xcode-cloud run --app 6792811995 --workflow release --branch main --wait
```

A successful run uploads a build **3–4 minutes after it starts** (that timing gap is how you tell a
CI build from a local one — the API exposes no direct link).

⚠️ **Never archive an App Store build on this Mac.** The host runs beta macOS, and Apple rejects
any binary whose `BuildMachineOSBuild` carries a beta stamp with **ITMS-90111** — regardless of how
stable Xcode and the SDK are. Proven on Lompakko builds 19 and 20. Xcode Cloud is the way.
Full runbook: the global `/ios-release` skill.

## Architecture

| Path | Role |
|---|---|
| `WeatherAheadApp.swift` | entry point |
| `TimelineStore.swift` | the state hub — owns the timeline and drives refresh |
| `Models/` | `PlaceDay`, `DaySection`, `TripSpan`, `Coordinate`, `WeatherModels` |
| `Services/` | `CalendarService` (EventKit), `GeocodingService`, `LocationService`, `WeatherProvider` (WeatherKit) |
| `Timeline/` | the main screen, rows, detail view, Swift Charts |
| `Timeline/Effects/` | animated weather scenes (cloud, precipitation, storm, atmosphere, sky) |
| `Onboarding/` | first-run permission flow |
| `Settings/` | settings + an effects gallery |
| `Support/` | `DemoSeeder`, `ScreenshotStaging` — for demos and App Store screenshots |

**Forecast horizon matters to the product.** The next ~10 days get real WeatherKit forecasts; beyond
that, trips are grouped by month and show **climate normals**, which convert to real forecasts as
the date approaches. Never present a climate normal as a forecast — that distinction is the point.

## Permissions

- **Calendar — required.** Reads event dates and locations only; never transmitted.
- **Location — optional.** Only powers the "weather where you are now" entry; the app is fully
  functional if declined.

No camera, no contacts, no ATT.

## Gotchas

- **Project-level `*_DEPLOYMENT_TARGET` is `27.0`** (an unreleased iOS) while the app target
  overrides with `26`. Builds work because of that override, but a **new target added without one
  will inherit 27.0 and fail** against the 26.x SDK. Lower the project-level values if you touch them.
- **The core feature is invisible without data.** On a device with no location-tagged calendar
  events the timeline is near-empty by design. This caused an App Review *Guideline 2.1 — Information
  Needed* request; the answer is a demo recording plus `Support/DemoSeeder`.
- The repo is public — no secrets, no personal data, no internal URLs in commits.

## Current state (2026-07-25)

Version 1.0, build 5, `WAITING_FOR_REVIEW`. A Guideline 2.1 information request was answered on
Jul 22 with a screen recording and sample `.ics`; App Review Notes carry the full explanation.
The red flag in App Store Connect marks that message thread, not a defect.
