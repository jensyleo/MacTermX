import MacTermXCore
import SwiftUI

struct PortListView: View {
    @ObservedObject var viewModel: PortListViewModel
    @Binding var selection: SerialDevice?

    var body: some View {
        List(viewModel.ports, selection: $selection) { device in
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                Text(device.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let vendorId = device.vendorId, let productId = device.productId {
                    Text("VID \(vendorId) · PID \(productId)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .tag(device)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel(for: device)))
        }
        .overlay {
            if viewModel.ports.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cable.connector.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Serial Ports")
                        .font(.headline)
                    Text("Connect a USB-to-serial adapter to see it here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await viewModel.refresh() }
                }
            }
        }
    }

    private func accessibilityLabel(for device: SerialDevice) -> String {
        var label = "\(device.name), \(device.path)"
        if let vendorId = device.vendorId, let productId = device.productId {
            label += ", vendor \(vendorId), product \(productId)"
        }
        return label
    }
}
