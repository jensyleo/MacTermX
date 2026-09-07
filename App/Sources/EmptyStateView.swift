import SwiftUI

/// A single consistent empty/placeholder state — used by the port list,
/// the profile list, and the detail area's "nothing selected" screen,
/// which previously each hand-rolled a slightly different version.
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String
    var fillsAvailableSpace = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: fillsAvailableSpace ? .infinity : nil, maxHeight: fillsAvailableSpace ? .infinity : nil)
    }
}
