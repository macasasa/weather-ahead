import EventKit
import SwiftUI

@main
struct WeatherAheadApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    #if DEBUG
    static var galleryOffset: Int {
        guard let index = CommandLine.arguments.firstIndex(of: "--gallery-offset"),
              index + 1 < CommandLine.arguments.count else { return 0 }
        return Int(CommandLine.arguments[index + 1]) ?? 0
    }
    #endif

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var store = TimelineStore()
    @Environment(\.scenePhase) private var scenePhase

    /// `--gallery [--gallery-offset N]` opens the effects gallery straight
    /// away, for reviewing every condition's animation. Debug builds only.
    private var showsGallery: Bool {
        #if DEBUG
        CommandLine.arguments.contains("--gallery")
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if showsGallery {
                #if DEBUG
                NavigationStack { WeatherEffectsGallery(startOffset: Self.galleryOffset) }
                #endif
            } else if !hasCompletedOnboarding {
                OnboardingFlow(store: store) {
                    hasCompletedOnboarding = true
                    store.refresh()
                }
            } else if store.needsCalendarAccess {
                PermissionDeniedView(store: store)
            } else {
                TimelineScreen(store: store)
            }
        }
        .onAppear {
            store.refresh()
        }
        .task {
            #if DEBUG
            await DemoSeeder.seedIfRequested()
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            store.refresh()
        }
    }
}
