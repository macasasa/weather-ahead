import CoreLocation
import EventKit
import SwiftUI
import UIKit

enum AppInfo {
    /// Set once the project has a public home; the Settings row hides while nil.
    static let repositoryURL: URL? = nil
}

struct SettingsView: View {
    let store: TimelineStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HowItWorksView()
                        .padding(.vertical, 8)
                }

                Section {
                    LabeledContent("Calendar", value: calendarStatusText)
                    LabeledContent("Location", value: locationStatusText)
                    Button("Open System Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("Both permissions are used on-device only. Calendar access is required; location is optional and only powers the \"where you are now\" entry.")
                }

                Section {
                    NavigationLink {
                        WeatherEffectsGallery()
                    } label: {
                        Label("Weather Effects", systemImage: "sparkles")
                    }
                }

                Section {
                    if let url = AppInfo.repositoryURL {
                        Link("Source Code", destination: url)
                    }
                    AttributionFooter(provider: store.weatherProvider)
                } footer: {
                    Text("Weather data by  Weather.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var calendarStatusText: String {
        switch store.calendarStatus {
        case .fullAccess: String(localized: "Full access")
        case .writeOnly: String(localized: "Write only — not enough")
        case .denied: String(localized: "Denied")
        case .restricted: String(localized: "Restricted")
        case .notDetermined: String(localized: "Not requested")
        @unknown default: String(localized: "Unknown")
        }
    }

    private var locationStatusText: String {
        switch store.locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: String(localized: "While using the app")
        case .denied: String(localized: "Denied")
        case .restricted: String(localized: "Restricted")
        case .notDetermined: String(localized: "Not requested")
        @unknown default: String(localized: "Unknown")
        }
    }
}
