#if DEBUG
import SwiftUI

/// Drives the app into a specific state for App Store screenshots, so a
/// capture run is scriptable instead of hand-tapped.
///
/// Pass `--screenshot <target>` as a launch argument:
///
/// | target     | screen                                        |
/// |------------|-----------------------------------------------|
/// | `timeline` | the timeline as-is (the default)              |
/// | `detail`   | pushes the first day that has a real forecast |
/// | `trips`    | scrolls to the trips beyond the forecast      |
///
/// Debug builds only — it compiles out entirely for release.
enum ScreenshotStaging {
    static var target: String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--screenshot"),
              index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    @MainActor
    static func stage(store: TimelineStore,
                      path: Binding<NavigationPath>,
                      scrollPosition: Binding<ScrollPosition>) async {
        guard let target else { return }
        // Let the weather land first, so nothing is captured mid-load.
        try? await Task.sleep(for: .seconds(3))

        switch target {
        case "detail":
            let entry = store.sections
                .flatMap(\.entries)
                .first { if case .ready = $0.weather { return true } else { return false } }
            if let entry, path.wrappedValue.isEmpty {
                path.wrappedValue.append(entry)
            }
        case "trips":
            // Anchor on the last forecast day rather than the first month
            // group: the divider then sits mid-screen with real forecasts
            // above and seasonal trip cards below, which tells the story in
            // one frame and avoids ending on empty space.
            if let lastForecastDay = store.sections.last?.day {
                withAnimation(.none) {
                    scrollPosition.wrappedValue.scrollTo(id: lastForecastDay, anchor: .top)
                }
            }
        default:
            break
        }
    }
}
#endif
