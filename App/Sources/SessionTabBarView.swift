import MacTermXCore
import SwiftUI

struct SessionTabBarView: View {
    @ObservedObject var viewModel: SessionTabsViewModel
    @State private var tabPendingClose: SessionTab?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(viewModel.tabs) { tab in
                    tabButton(tab)
                }
            }
            .padding(6)
        }
        .background(.bar)
        .alert(
            "Close \"\(tabPendingClose?.title ?? "")\"?",
            isPresented: Binding(
                get: { tabPendingClose != nil },
                set: { if !$0 { tabPendingClose = nil } }
            )
        ) {
            Button("Close and Abort Transfer", role: .destructive) {
                if let tab = tabPendingClose { viewModel.close(tab) }
                tabPendingClose = nil
            }
            Button("Cancel", role: .cancel) { tabPendingClose = nil }
        } message: {
            Text("A file transfer is in progress on this tab. Closing it now will abort the transfer.")
        }
    }

    private func tabButton(_ tab: SessionTab) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tab.connectionViewModel.state == .connected ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 6, height: 6)
            Text(tab.title)
                .lineLimit(1)
            Button {
                if viewModel.closeNeedsConfirmation(tab) {
                    tabPendingClose = tab
                } else {
                    viewModel.close(tab)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(tab.id == viewModel.activeTabID ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { viewModel.activeTabID = tab.id }
    }
}
