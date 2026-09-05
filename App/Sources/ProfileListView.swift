import MacTermXCore
import SwiftUI

struct ProfileListView: View {
    @ObservedObject var viewModel: ProfilesViewModel
    @Binding var selection: SerialProfile?

    var body: some View {
        List(viewModel.profiles, selection: $selection) { profile in
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                Text("\(profile.serial.baudRate) baud · \(profile.environment.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(profile)
            .swipeActions {
                Button("Delete", role: .destructive) {
                    viewModel.delete(profile)
                }
            }
        }
        .overlay {
            if viewModel.profiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Saved Profiles")
                        .font(.headline)
                    Text("Connect to a port and save its settings as a profile.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
}
