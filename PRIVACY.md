# Privacy Policy — Weather Ahead

**Short version: Weather Ahead has no account, no servers, and no analytics. Your calendar and location never leave your device.**

Last updated: July 2026

## What the app reads

- **Calendar events.** With your permission, the app reads events from your calendars to find the dates and places you'll be at. It looks at the event's title, dates and location. This happens entirely on your device.
- **Your location.** Optionally, with your permission, the app uses your current location to show today's weather where you are. This also stays on your device. You can decline it; the rest of the app works normally.

## What leaves your device

Only what's needed to fetch a forecast: **coordinates and dates are sent to Apple's WeatherKit service**, the same service Apple's own Weather app uses. Your event titles, your calendars, and your identity are never sent — WeatherKit is asked "what is the weather at this latitude/longitude on these dates", nothing more.

Place names are resolved to coordinates using Apple's MapKit geocoding, which likewise receives only the location text or coordinates from the event.

Apple's handling of that data is covered by [Apple's privacy policy](https://www.apple.com/legal/privacy/).

## What is stored

Weather results, resolved coordinates and place names are cached in the app's own private container on your device, so the app doesn't re-request the same data. Deleting the app deletes all of it. Nothing is backed up to any server run by this project.

## What is *not* collected

- No account, sign-in, or personal identifiers
- No analytics, telemetry, crash reporting, or advertising
- No third-party SDKs of any kind

## Verifying this

The app is open source under the MIT licence. Every network call it makes is in [`WeatherAhead_iOS/Services/`](WeatherAhead_iOS/Services/) — you're welcome to read it, or watch the requests yourself with the logging described in the [README](README.md#debugging).

## Contact

Questions or concerns: please open an issue on the project's GitHub repository.
