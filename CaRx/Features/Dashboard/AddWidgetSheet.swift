import SwiftUI
import SwiftData

struct AddWidgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let layout: DashboardLayout
    let pack: VehiclePack
    let onAdded: () -> Void

    @State private var selectedPID: PID?
    @State private var widgetType: WidgetType = .digitalCard
    @State private var customMin: String = ""
    @State private var customMax: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Sensor") {
                    Picker("PID", selection: $selectedPID) {
                        Text("Select a sensor").tag(Optional<PID>.none)
                        ForEach(pack.allPIDs) { pid in
                            HStack {
                                Text(pid.name)
                                if !pid.verified {
                                    Text("unverified").font(.caption2).foregroundStyle(CaRxTheme.warning)
                                }
                            }
                            .tag(Optional(pid))
                        }
                    }
                }

                Section("Widget Type") {
                    Picker("Type", selection: $widgetType) {
                        ForEach(WidgetType.allCases) { type in
                            Label(type.displayName, systemImage: type.systemImage).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Custom Range (optional)") {
                    TextField("Min (default \(selectedPID?.minValue.formattedGauge ?? "-"))", text: $customMin)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Max (default \(selectedPID?.maxValue.formattedGauge ?? "-"))", text: $customMax)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle("Add Widget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addWidget() }
                        .disabled(selectedPID == nil)
                }
            }
        }
    }

    private func addWidget() {
        guard let selectedPID else { return }
        let widget = WidgetConfig(
            pidID: selectedPID.id,
            widgetType: widgetType,
            sortOrder: layout.widgets.count,
            customMin: Double(customMin),
            customMax: Double(customMax)
        )
        widget.layout = layout
        layout.widgets.append(widget)
        modelContext.insert(widget)
        onAdded()
        dismiss()
    }
}
