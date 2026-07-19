import SwiftUI

/// First-launch flow: (1) how the app works, (2) why calendar access,
/// (3) why location access. Step 1's content is `HowItWorksView`, reused in
/// Settings so the explanation is always one tap away.
struct OnboardingFlow: View {
    let store: TimelineStore
    let onFinished: () -> Void

    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case 0:
                stepPage {
                    HowItWorksView()
                } button: {
                    Button("Continue") { step = 1 }
                }
            case 1:
                stepPage {
                    PermissionExplanation(
                        systemImage: "calendar",
                        title: String(localized: "Your calendar is the itinerary"),
                        message: String(localized: "Weather Ahead needs full access to your calendar to read the dates and locations of your events. That's the whole magic: your bookings and plans become a weather timeline.\n\nYour events are read on this device only and are never sent anywhere.")
                    )
                } button: {
                    Button("Allow Calendar Access") {
                        Task {
                            _ = await store.calendarService.requestFullAccess()
                            step = 2
                        }
                    }
                }
            default:
                stepPage {
                    PermissionExplanation(
                        systemImage: "location",
                        title: String(localized: "Weather where you are"),
                        message: String(localized: "With location access, today's section always starts with the weather at your current place — even on days with no plans.\n\nYour location stays on this device. You can skip this; the timeline works without it.")
                    )
                } button: {
                    VStack(spacing: 10) {
                        Button("Allow Location Access") {
                            Task {
                                _ = await store.locationService.requestAuthorization()
                                onFinished()
                            }
                        }
                        Button("Not Now") { onFinished() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .animation(.default, value: step)
    }

    private func stepPage(@ViewBuilder content: () -> some View,
                          @ViewBuilder button: () -> some View) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                content()
                    .padding(24)
            }
            button()
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
}

/// One permission step: big icon, title, plain-words explanation.
private struct PermissionExplanation: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 40)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// What the app is and how it works — shown as onboarding step 1 and reused
/// in Settings.
struct HowItWorksView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "cloud.sun")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Weather Ahead")
                    .font(.largeTitle.bold())
                Text("The weather for everywhere you're going")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)

            featureRow(systemImage: "calendar",
                       title: String(localized: "Reads your plans"),
                       detail: String(localized: "Every calendar event with a location — trips, bookings, meetups — becomes a stop on your timeline."))
            featureRow(systemImage: "cloud.sun.rain",
                       title: String(localized: "Shows the weather there"),
                       detail: String(localized: "Apple Weather forecasts for upcoming stops, and the recorded weather for places you've been."))
            featureRow(systemImage: "lock",
                       title: String(localized: "Everything stays on your device"),
                       detail: String(localized: "No account, no servers, no tracking. The app is open source, so you can verify it."))
        }
    }

    private func featureRow(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
