import SwiftUI

/// The single main screen: a scrollable timeline of day sections, anchored on
/// today, with a floating button to jump back when scrolled away.
struct TimelineScreen: View {
    let store: TimelineStore

    @State private var scrollPosition = ScrollPosition(idType: Date.self)
    @State private var todayVisible = true
    @State private var showingSettings = false
    @State private var path = NavigationPath()

    private var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                GlassEffectContainer(spacing: 14) {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        ForEach(store.sections) { section in
                            DaySectionView(section: section, todayVisible: $todayVisible)
                        }
                        if !store.laterGroups.isEmpty {
                            TimelineDivider(
                                title: String(localized: "Beyond the 10-day forecast"),
                                detail: String(localized: "Each trip below shows the typical climate for its season. Real forecasts appear as the dates get closer.")
                            )
                            ForEach(store.laterGroups) { group in
                                MonthGroupView(group: group)
                            }
                        }
                        timelineFooter
                        AttributionFooter(provider: store.weatherProvider)
                    }
                    .scrollTargetLayout()
                }
                .padding(.horizontal)
            }
            .contentMargins(.bottom, 64, for: .scrollContent)
            .scrollPosition($scrollPosition, anchor: .top)
            .overlay(alignment: .bottomTrailing) {
                if !todayVisible {
                    BackToTodayButton {
                        withAnimation {
                            // A negative offset (clamped by the scroll view)
                            // lands above the content, inside the nav bar's
                            // inset — which is what re-expands the large
                            // title. `scrollTo(edge: .top)` only brings the
                            // first row up, leaving the title collapsed.
                            scrollPosition.scrollTo(y: -600)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 48)
                    .transition(.scale(scale: 0.75).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: todayVisible)
            .navigationTitle("Weather Ahead")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        showingSettings = true
                    }
                }
            }
            .navigationDestination(for: PlaceDay.self) { entry in
                PlaceDayDetailView(entry: entry, provider: store.weatherProvider)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(store: store)
            }
            #if DEBUG
            .task(id: store.sections.count + store.laterGroups.count) {
                await ScreenshotStaging.stage(store: store, path: $path,
                                              scrollPosition: $scrollPosition)
            }
            #endif
        }
    }

    /// The honest end of the list: explains what isn't shown and why.
    @ViewBuilder
    private var timelineFooter: some View {
        if store.isLoading && !store.hasEventEntries {
            EmptyView()
        } else if !store.hasEventEntries, store.beyondWindowEvent == nil {
            ContentUnavailableView {
                Label("No places yet", systemImage: "calendar.badge.plus")
            } description: {
                Text("Add locations to your calendar events — or sync your travel bookings to your calendar — and they'll show up here with their weather.")
            }
        } else if let upcoming = store.beyondWindowEvent {
            FooterNote(text: String(localized: "That's the next 12 months. “\(upcoming.title)” in \(upcoming.start.formatted(.dateTime.month(.wide).year())) will appear here as it gets closer."))
        } else if store.hasEventEntries {
            FooterNote(text: String(localized: "That's everything on your calendar for the next 12 months."))
        }
    }
}

/// A section break in the timeline: a rule either side of a short label, with
/// an explanation underneath. Deliberately not a card — nothing to tap here.
private struct TimelineDivider: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                line
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                line
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }

    private var line: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
            .frame(height: 0.5)
    }
}

/// A quiet closing note at the very end of the timeline — plain text, not a card.
private struct FooterNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.top, 18)
    }
}

/// A month of trips beyond the forecast window: month header + trip cards.
private struct MonthGroupView: View {
    let group: MonthGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(group.monthStart, format: monthFormat)
                    .font(.title3.weight(.bold))
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            ForEach(group.trips) { trip in
                NavigationLink(value: trip.representativeDay) {
                    TripRow(trip: trip)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var monthFormat: Date.FormatStyle {
        let sameYear = Calendar.current.isDate(group.monthStart, equalTo: .now, toGranularity: .year)
        return sameYear ? .dateTime.month(.wide) : .dateTime.month(.wide).year()
    }
}

/// A day and its place cards. Header scrolls with the content (not pinned).
private struct DaySectionView: View {
    let section: DaySection
    @Binding var todayVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DayHeader(day: section.day, isToday: section.isToday)
            if section.entries.isEmpty {
                Text("No places on your calendar today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            ForEach(section.entries) { entry in
                NavigationLink(value: entry) {
                    PlaceDayRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
        .onScrollVisibilityChange(threshold: 0.05) { visible in
            // Only assign on an actual change — repeated identical values
            // trip SwiftUI's "multiple updates per frame" warning.
            if section.isToday, todayVisible != visible {
                todayVisible = visible
            }
        }
    }
}

private struct DayHeader: View {
    let day: Date
    let isToday: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(day, format: .dateTime.day(.twoDigits).month(.wide))
                .font(.title3.weight(.bold))
            Text(isToday ? String(localized: "Today") : day.formatted(.dateTime.weekday(.wide)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}
