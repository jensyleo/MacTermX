import MacTermXCore
import SwiftUI
import UniformTypeIdentifiers

struct ProfileListView: View {
    @ObservedObject var viewModel: ProfilesViewModel
    @Binding var selection: SerialProfile?
    @State private var exportingProfile: SerialProfile?
    @State private var showingImporter = false
    @State private var importError: String?

    var body: some View {
        List(viewModel.profiles, selection: $selection) { profile in
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                Text("\(profile.serial.baudRate) baud · \(profile.environment.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(profile)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(profile.name), \(profile.serial.baudRate) baud, \(profile.environment.rawValue)"))
            .swipeActions {
                Button("Delete", role: .destructive) {
                    viewModel.delete(profile)
                }
            }
            .contextMenu {
                Button("Duplicate") { viewModel.duplicate(profile) }
                Button("Export…") { exportingProfile = profile }
                Button("Delete", role: .destructive) { viewModel.delete(profile) }
            }
        }
        .overlay {
            if viewModel.profiles.isEmpty {
                EmptyStateView(
                    title: "No Saved Profiles",
                    systemImage: "tray",
                    message: "Connect to a port and save its settings as a profile."
                )
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Import Profile…", systemImage: "square.and.arrow.down") {
                    showingImporter = true
                }
            }
        }
        .fileExporter(
            isPresented: Binding(get: { exportingProfile != nil }, set: { if !$0 { exportingProfile = nil } }),
            document: exportingProfile.map { ProfileFileDocument(profile: $0) },
            contentType: .json,
            defaultFilename: exportingProfile.map { "\($0.name).json" } ?? "profile.json"
        ) { _ in }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            do {
                _ = try viewModel.importProfile(from: url)
            } catch {
                importError = String(describing: error)
            }
        }
        .alert("Import Failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }
}
