import AppKit
import SwiftUI

@main
struct MacTermXApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MacTermX") {
                    showAboutPanel()
                }
            }
            CommandGroup(replacing: .help) {
                Button("MacTermX Help on GitHub") {
                    if let url = URL(string: "https://github.com/jensyleo/MacTermX") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        Settings {
            AppPreferencesView()
        }
    }

    private func showAboutPanel() {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let credits = NSAttributedString(
            string: "A native macOS serial terminal.\nVersion \(version) (\(build))\nLicensed under GPL-3.0 — see NOTICE.md for third-party licenses.",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .applicationVersion: version,
        ])
    }
}
