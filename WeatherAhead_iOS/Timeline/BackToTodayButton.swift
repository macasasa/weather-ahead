import SwiftUI

/// Floating capsule that appears once today is scrolled off-screen. The list
/// starts at today, so today is always above — the arrow always points up.
struct BackToTodayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Today", systemImage: "arrow.up")
                .font(.callout.weight(.semibold))
        }
        .buttonStyle(.glassProminent)
        .accessibilityHint("Scrolls the timeline back to the top, at today")
    }
}
