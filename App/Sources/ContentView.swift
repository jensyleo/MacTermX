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
    @StateObject private var sessionTabs = SessionTabsViewModel()
    @State private var tab: SidebarTab = .ports
    @State private var portSelection: SerialDevice?
    @State private var profileSelection: SerialProfile?
    @State private var showingDiagnosticsExport = false

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
            VStack(spacing: 0) {
                if !sessionTabs.tabs.isEmpty {
                    SessionTabBarView(viewModel: sessionTabs)
                    Divider()
                }
                detailView
            }
        }
        .frame(minWidth: 760, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Export Diagnostics…", systemImage: "stethoscope") {
                    showingDiagnosticsExport = true
                }
            }
        }
        .fileExporter(
            isPresented: $showingDiagnosticsExport,
            document: TextFileDocument(text: diagnosticReportText),
            contentType: .plainText,
            defaultFilename: "MacTermX-diagnostics.txt"
        ) { _ in }
        .onChange(of: portSelection) { device in
            guard let device else { return }
            sessionTabs.openPort(device)
        }
        .onChange(of: profileSelection) { profile in
            guard let profile else { return }
            if let device = profiles.matchingDevice(for: profile, in: portList.ports) {
                sessionTabs.openProfile(profile, device: device)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let active = sessionTabs.activeTab {
            TerminalConsoleView(viewModel: active.connectionViewModel, profiles: profiles)
                .id(active.id)
        } else if tab == .profiles, let profileSelection, profiles.matchingDevice(for: profileSelection, in: portList.ports) == nil {
            placeholder(
                "Device Not Connected",
                "cable.connector.slash",
                "Plug in \"\(profileSelection.name)\" to open this profile. It's matched by USB vendor/product ID, not by port path."
            )
        } else {
            placeholder("No Open Sessions", "terminal", "Choose a serial port or profile on the left to open a session. Each opens in its own tab.")
        }
    }

    private var diagnosticReportText: String {
        let bundle = Bundle.main
        let activeSession: (deviceName: String, configuration: SerialConfiguration, state: String)?
        if let tab = sessionTabs.activeTab {
            activeSession = (tab.title, tab.connectionViewModel.configuration, "\(tab.connectionViewModel.state)")
        } else {
            activeSession = nil
        }
        return DiagnosticReport.generate(
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            activeSession: activeSession,
            lastError: sessionTabs.activeTab?.connectionViewModel.lastError
        )
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
