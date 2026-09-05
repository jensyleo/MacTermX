import MacTermXCore
import SwiftUI

/// Macro library editor — CoolTerm/ZTerm call this "commands"/"connection
/// scripts"; here it's a flat list of name+template+line-ending+danger
/// flag per device, edited in a sheet from the console toolbar.
struct MacrosView: View {
    @ObservedObject var viewModel: MacrosViewModel
    @State private var editing: MacroCommand?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.macros) { macro in
                    Button {
                        editing = macro
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(macro.name)
                                if macro.isDangerous {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                            }
                            Text(macro.template)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    for index in indexSet { viewModel.delete(viewModel.macros[index]) }
                }
            }
            .navigationTitle("Quick Commands")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        editing = MacroCommand(name: "New Command", template: "")
                    }
                }
            }
            .sheet(item: $editing) { macro in
                MacroEditorView(macro: macro) { saved in
                    if viewModel.macros.contains(where: { $0.id == saved.id }) {
                        viewModel.update(saved)
                    } else {
                        viewModel.add(saved)
                    }
                }
            }
        }
        .frame(width: 420, height: 420)
    }
}

private struct MacroEditorView: View {
    @State var macro: MacroCommand
    var onSave: (MacroCommand) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $macro.name)
                TextField("Template", text: $macro.template, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                Text("Variables: {date}, {time}, {profile}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("Line Ending", selection: $macro.lineEnding) {
                    Text("None").tag(LineEndingKind.none)
                    Text("CR").tag(LineEndingKind.cr)
                    Text("LF").tag(LineEndingKind.lf)
                    Text("CRLF").tag(LineEndingKind.crlf)
                }
                Toggle("Requires confirmation before sending", isOn: $macro.isDangerous)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 300)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Save") {
                    onSave(macro)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(macro.name.isEmpty || macro.template.isEmpty)
            }
            .padding()
        }
    }
}
