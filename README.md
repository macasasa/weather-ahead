# WeatherAhead

**The weather for everywhere you're going.**

WeatherAhead reads your Apple Calendar and turns it into a weather timeline. Every event with a location — a hotel booking synced to your calendar, a trip, a meetup — becomes a stop on a single scrollable list: day by day, place by place, with the forecast for each.

- **One timeline.** Days are sections; places are rows on condition-tinted Liquid Glass cards showing city, country, condition, temperature and H/L. Leave Espoo and arrive in Joensuu on the same day? That day shows both, each with its own weather.
- **Today, anchored.** The timeline opens on today, which always starts with the weather at your current location. Scroll far away and a floating button brings you back.
- **Near future and beyond.** The next 10 days get real forecasts (Apple Weather's horizon). Past that, trips are grouped by month and show the **typical climate** for that place and time of year, from WeatherKit's climate normals — each one turning into a real forecast as the date comes closer. No dead ends, and nothing pretends to be a forecast when it isn't.
- **Tap for detail.** Any place opens a full day view styled after Apple's Weather app: an hour-by-hour **temperature chart** (with an Actual / Feels-Like toggle) and precipitation chart built with Swift Charts, a scrollable hourly strip, and a grid of everything WeatherKit provides — feels-like, humidity, dew point, wind and gusts, pressure and trend, visibility, cloud cover, UV, sunrise/sunset and moon phase. Active weather alerts appear at the top.

## Privacy

There is no backend, no account, and no tracking.

- Your calendar events are read **on-device only** and are never sent anywhere.
- Your location is used **on-device only**, just for the "where you are now" entry. Granting it is optional.
- Weather comes from [Apple Weather](https://weatherkit.apple.com/legal-attribution.html) (WeatherKit); only coordinates and dates are sent to Apple's weather service, as with any weather app.
- Geocoding of event addresses uses Apple's MapKit on-device APIs, and results are cached locally.

The entire app is open source so you can verify all of this.

## Requirements

- iOS 26+
- Xcode 26 or later to build

## Building

There are no API keys and no third-party dependencies — but WeatherKit is tied to *your* Apple developer account, so you need to supply your own signing identity.

1. Copy the signing template and fill in your details:

   ```sh
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

   Set `DEVELOPMENT_TEAM` to your 10-character Team ID (Xcode → Settings → Accounts) and `PRODUCT_BUNDLE_IDENTIFIER` to a bundle id you own. `Local.xcconfig` is gitignored, so your identifiers stay out of the repo.

2. **Enable WeatherKit for that App ID.** WeatherKit needs a paid Apple Developer membership: register the identifier at [developer.apple.com](https://developer.apple.com/account/resources/identifiers) with the WeatherKit capability ticked, then enable WeatherKit for the same App ID in App Store Connect. It can take up to ~30 minutes to activate.

3. Open `WeatherAhead_iOS.xcodeproj` and run.

Without a WeatherKit-enabled App ID the app still builds and runs — the timeline, calendar events, places and permissions all work — but every row shows "No weather data".

## Architecture (short version)

SwiftUI + Swift Concurrency, no third-party dependencies.

```
EventKit events (today … +365 d, with locations)
  → expand multi-day events into per-day stops
  → resolve coordinates (event geo, or geocode the address — cached)
  → within the forecast window: group into day sections
    (same place on the same day merges)
  → beyond it: collapse consecutive days into one trip card per month
  → weather per (place, day) from WeatherKit, or climate normals
    beyond the horizon — both cached on disk
  → one @Observable TimelineStore drives the whole UI
```

| Piece | Where |
|---|---|
| Services (calendar, geocoding, weather, location) | `WeatherAhead_iOS/Services/` |
| Timeline UI + detail view | `WeatherAhead_iOS/Timeline/` |
| Onboarding & permission screens | `WeatherAhead_iOS/Onboarding/` |
| The one store | `WeatherAhead_iOS/TimelineStore.swift` |

## Debugging

The app logs weather fetches (ranges, coverage, fallbacks, errors) via the unified logging system. To capture logs, run:

```sh
log stream --predicate 'subsystem == "com.example.weatherahead"' --level debug
```

Use whatever bundle id you set in `Local.xcconfig` — the logging subsystem follows it. You can also open Console.app and filter by that subsystem. For the simulator, prefix the command with `xcrun simctl spawn booted`.

Debug builds accept two launch arguments (Xcode → Product → Scheme → Edit Scheme → Arguments):

| Argument | Effect |
|---|---|
| `--gallery` | Opens the weather-effects gallery straight away (also in Settings → Weather Effects). Add `--gallery-offset N` to skip the first N conditions. |
| `--seed-demo-events` | Seeds the simulator calendar with sample trips covering near-term, horizon-edge, seasonal and beyond-a-year cases. |

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for how to build and what to include in a pull request.

## Licence

MIT — see [LICENSE](LICENSE). Weather data is provided by Apple Weather.

## Roadmap

- Widget with recent & upcoming places
- Choosing which calendars to read

---

Weather data provided by  Weather. [Data sources & attribution](https://weatherkit.apple.com/legal-attribution.html).
