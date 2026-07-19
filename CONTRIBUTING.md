# Contributing to Weather Ahead

Thanks for taking an interest. This is a small, deliberately simple app: SwiftUI, Swift Concurrency, Apple frameworks only, no third-party dependencies. Please keep it that way unless there's a strong reason not to.

## Getting it running

See [Building](README.md#building) in the README. In short: copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`, put in your own Team ID and a bundle id you own, and enable WeatherKit for that App ID.

Two things worth knowing before you file a bug:

- **WeatherKit needs your own App ID.** Without one the app runs fine but every row reads "No weather data". That's expected, not a bug.
- **Apple's forecast covers 10 days including today.** Anything further out deliberately shows seasonal climate averages instead. That's by design — see `WeatherProvider.forecastHorizonDays`.

Debug builds accept `--seed-demo-events` (fills the simulator calendar with sample trips) and `--gallery` (opens the weather-effects gallery). Both are listed in the README's Debugging section.

## Making changes

- **Match the surrounding code.** Naming, comment density, and structure should look like what's already there. Comments explain constraints and non-obvious *why*, not what the next line does.
- **Keep the privacy promise.** Calendar and location data must never leave the device. Any change that adds a network call needs a very good reason and a note in the PR.
- **Check it actually runs.** Build and exercise the affected screen in the simulator before opening a PR — this app has no test suite yet, so a screenshot of the change is the most useful evidence you can attach.
- **Watch text contrast** if you touch the weather visuals: text over the animated skies should stay at or above WCAG AA (4.5:1). The cell scrim in `PlaceDayRow` exists for exactly this reason.

## Pull requests

Describe the **user-visible change** first — what's different when you open the app — then the implementation if it needs explaining. Screenshots or a short screen recording are very welcome for anything visual.

If you're planning something large, open an issue first so we can agree on the approach before you spend time on it.

## Reporting bugs

Weather issues are much easier to diagnose with logs. The app logs its weather fetches (requested ranges, what came back, fallbacks, errors) — capture them with:

```sh
log stream --predicate 'subsystem == "<your bundle id>"' --level debug
```

Paste the relevant lines into the issue along with the date, the place, and what you expected to see.
