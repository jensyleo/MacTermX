import MacTermXCore
import SwiftUI

struct ContentView: View {
    @StateObject private var portList = PortListViewModel()
    @State private var selection: SerialDevice?

    var body: some View {
        NavigationSplitView {
            PortListView(viewModel: portList, selection: $selection)
                .navigationTitle("Ports")
                .frame(minWidth: 220)
        } detail: {
            if let selection {
                TerminalConsoleView(viewModel: ConnectionViewModel(device: selection))
                    .id(selection.id)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Select a Port")
                        .font(.headline)
                    Text("Choose a serial port on the left to open a session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 760, minHeight: 480)
    }
}

#Preview {
    ContentView()
}
