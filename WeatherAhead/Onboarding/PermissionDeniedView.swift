import EventKit
import SwiftUI
import UIKit

/// Shown when calendar access is denied — the app genuinely can't do anything
/// without it, so explain kindly and point to Settings.
struct PermissionDeniedView: View {
    let store: TimelineStore

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Weather Ahead needs your calendar")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Sorry — without calendar access there's nothing to show: your events are where the places and dates come from.\n\nYour events never leave this device and are never shared with anyone. The app is open source, so you can verify that yourself.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            if store.calendarStatus == .notDetermined {
                Button("Grant Calendar Access") {
                    Task {
                        _ = await store.calendarService.requestFullAccess()
                        store.refresh()
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            } else {
                VStack(spacing: 12) {
                    Text("To enable it: Settings → Apps → Weather Ahead → Calendar → Full Access")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding(24)
    }
}
