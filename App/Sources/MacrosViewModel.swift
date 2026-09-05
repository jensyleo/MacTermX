import Foundation
import MacTermXCore

@MainActor
final class MacrosViewModel: ObservableObject {
    @Published private(set) var macros: [MacroCommand] = []
    private let store: MacroStore
    private let key: String

    init(deviceKey: String) {
        self.key = deviceKey
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacTermX/Macros", isDirectory: true)
        self.store = MacroStore(directory: directory)
        self.macros = store.load(for: deviceKey)
    }

    func add(_ macro: MacroCommand) {
        macros.append(macro)
        persist()
    }

    func update(_ macro: MacroCommand) {
        guard let index = macros.firstIndex(where: { $0.id == macro.id }) else { return }
        macros[index] = macro
        persist()
    }

    func delete(_ macro: MacroCommand) {
        macros.removeAll { $0.id == macro.id }
        persist()
    }

    private func persist() {
        try? store.save(macros, for: key)
    }
}
