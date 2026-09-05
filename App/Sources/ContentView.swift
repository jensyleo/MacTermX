import MacTermXCore
import SwiftUI

private enum SidebarTab: String, CaseIterable, Identifiable {
    case ports = "Ports"
    case profiles = "Profiles"
    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var portList = PortListViewModel()
    @StateObject private var profiles = ProfilesViewModel()
    @State private var tab: SidebarTab = .ports
    @State private var portSelection: SerialDevice?
    @State private var profileSelection: SerialProfile?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(SidebarTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(8)

                switch tab {
                case .ports:
                    PortListView(viewModel: portList, selection: $portSelection)
                case .profiles:
                    ProfileListView(viewModel: profiles, selection: $profileSelection)
                }
            }
            .navigationTitle("MacTermX")
            .frame(minWidth: 220)
        } detail: {
            detailView
        }
        .frame(minWidth: 760, minHeight: 480)
    }

    @ViewBuilder
    private var detailView: some View {
        switch tab {
        case .ports:
            if let portSelection {
                TerminalConsoleView(viewModel: ConnectionViewModel(device: portSelection), profiles: profiles)
                    .id(portSelection.id)
            } else {
                placeholder("Select a Port", "terminal", "Choose a serial port on the left to open a session.")
            }
        case .profiles:
            if let profileSelection {
                if let device = profiles.matchingDevice(for: profileSelection, in: portList.ports) {
                    TerminalConsoleView(
                        viewModel: ConnectionViewModel(device: device, initialConfiguration: profileSelection.serial),
                        profiles: profiles
                    )
                    .id(profileSelection.id)
                } else {
                    placeholder(
                        "Device Not Connected",
                        "cable.connector.slash",
                        "Plug in \"\(profileSelection.name)\" to open this profile. It's matched by USB vendor/product ID, not by port path."
                    )
                }
            } else {
                placeholder("Select a Profile", "tray.full", "Choose a saved profile on the left to reconnect.")
            }
        }
    }

    private func placeholder(_ title: String, _ systemImage: String, _ message: String) -> some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
