import SwiftUI
import SwiftData

struct ChartBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let pack: VehiclePack
    let onSave: (ChartPreset) -> Void

    @State private var name = ""
    @State private var selectedPIDIDs: Set<String> = []
    @State private var rangeOverrideText: [String: (min: String, max: String)] = [:]
    @State private var windowSeconds: Double = 60

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Boost vs. RPM", text: $name)
                }

                Section("Sensors (select 2 or more)") {
                    ForEach(pack.allPIDs) { pid in
                        Toggle(isOn: binding(for: pid)) {
                            HStack {
                                Text(pid.name)
                                if !pid.verified {
                                    Text("unverified").font(.caption2).foregroundStyle(CaRxTheme.warning)
                                }
                            }
                        }
                    }
                }

                if !selectedPIDIDs.isEmpty {
                    Section("Per-Series Range Override (optional)") {
                        ForEach(pack.allPIDs.filter { selectedPIDIDs.contains($0.id) }) { pid in
                            HStack {
                                Text(pid.name).font(.subheadline)
                                Spacer()
                                TextField("min", text: minBinding(for: pid)).frame(width: 60).keyboardType(.numbersAndPunctuation)
                                Text("–")
                                TextField("max", text: maxBinding(for: pid)).frame(width: 60).keyboardType(.numbersAndPunctuation)
                            }
                        }
                    }
                }

                Section("Time Window") {
                    Picker("Window", selection: $windowSeconds) {
                        Text("30s").tag(30.0)
                        Text("1m").tag(60.0)
                        Text("5m").tag(300.0)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Multi-Series Chart")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selectedPIDIDs.count < 2 || name.isEmpty)
                }
            }
        }
    }

    private func binding(for pid: PID) -> Binding<Bool> {
        Binding(
            get: { selectedPIDIDs.contains(pid.id) },
            set: { isOn in
                if isOn { selectedPIDIDs.insert(pid.id) } else { selectedPIDIDs.remove(pid.id) }
            }
        )
    }

    private func minBinding(for pid: PID) -> Binding<String> {
        Binding(
            get: { rangeOverrideText[pid.id]?.min ?? "" },
            set: { rangeOverrideText[pid.id, default: ("", "")].min = $0 }
        )
    }

    private func maxBinding(for pid: PID) -> Binding<String> {
        Binding(
            get: { rangeOverrideText[pid.id]?.max ?? "" },
            set: { rangeOverrideText[pid.id, default: ("", "")].max = $0 }
        )
    }

    private func save() {
        var overrides: [String: ClosedRange<Double>] = [:]
        for (pidID, text) in rangeOverrideText {
            if let min = Double(text.min), let max = Double(text.max), max > min {
                overrides[pidID] = min...max
            }
        }
        let preset = ChartPreset(name: name, seriesPIDIDs: Array(selectedPIDIDs), rangeOverrides: overrides, timeWindowSeconds: windowSeconds)
        modelContext.insert(preset)
        onSave(preset)
        dismiss()
    }
}
