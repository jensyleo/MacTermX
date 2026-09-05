import SwiftUI
import MacTermXCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
            Text("MacTermX")
                .font(.title)
            Text("Serial terminal — scaffold")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    ContentView()
}
