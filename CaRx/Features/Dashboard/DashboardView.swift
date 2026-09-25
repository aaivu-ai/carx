import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(OBDCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @Query private var layouts: [DashboardLayout]
    let activeProfile: VehicleProfile

    @State private var selectedLayout: DashboardLayout?
    @State private var isEditing = false
    @State private var isPresentingAddWidget = false
    @State private var isPresentingNewLayout = false
    @State private var chartPID: PID?

    private var pack: VehiclePack { coordinator.telemetry.activePack }
    private var pidsByID: [String: PID] { Dictionary(uniqueKeysWithValues: pack.allPIDs.map { ($0.id, $0) }) }

    var body: some View {
        NavigationStack {
            ZStack {
                CaRxBackground()
                ScrollView {
                    if let layout = selectedLayout {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(layout.widgets.sorted(by: { $0.sortOrder < $1.sortOrder })) { widget in
                                if let pid = pidsByID[widget.pidID] {
                                    widgetView(for: widget, pid: pid)
                                        .onTapGesture {
                                            guard !isEditing else { return }
                                            chartPID = pid
                                        }
                                        .overlay(alignment: .topTrailing) {
                                            if isEditing {
                                                Button {
                                                    remove(widget, from: layout)
                                                } label: {
                                                    Image(systemName: "minus.circle.fill")
                                                        .foregroundStyle(CaRxTheme.danger)
                                                        .background(Circle().fill(.black))
                                                }
                                                .offset(x: 6, y: -6)
                                            }
                                        }
                                }
                            }
                            if isEditing {
                                Button { isPresentingAddWidget = true } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill").font(.title)
                                        Text("Add Widget").font(.caption)
                                    }
                                    .foregroundStyle(CaRxTheme.accent)
                                    .frame(maxWidth: .infinity, minHeight: 120)
                                }
                                .carxCard()
                            }
                        }
                        .padding(16)
                    } else {
                        ContentUnavailableView("No Dashboard Layout", systemImage: "square.grid.2x2", description: Text("Create a layout to get started."))
                    }
                }
            }
            .navigationTitle("CaRx")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ConnectionStatusBanner(state: coordinator.connectionState)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Layout", selection: $selectedLayout) {
                            ForEach(layouts) { layout in
                                Text(layout.name).tag(Optional(layout))
                            }
                        }
                        Button("New Layout", systemImage: "plus") { isPresentingNewLayout = true }
                        Divider()
                        Button(isEditing ? "Done Editing" : "Edit Layout", systemImage: isEditing ? "checkmark" : "slider.horizontal.3") {
                            isEditing.toggle()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { seedLayoutIfNeeded() }
            .task(id: selectedLayout?.id) { updateActivePIDs() }
            .sheet(isPresented: $isPresentingAddWidget) {
                if let layout = selectedLayout {
                    AddWidgetSheet(layout: layout, pack: pack) { updateActivePIDs() }
                }
            }
            .sheet(isPresented: $isPresentingNewLayout) {
                NewLayoutSheet { name in
                    let layout = DashboardLayout(name: name)
                    modelContext.insert(layout)
                    selectedLayout = layout
                }
            }
            .sheet(item: $chartPID) { pid in
                SingleSensorChartView(pid: pid)
            }
        }
    }

    @ViewBuilder
    private func widgetView(for widget: WidgetConfig, pid: PID) -> some View {
        let range = (widget.customMin ?? pid.minValue)...(widget.customMax ?? pid.maxValue)
        let value = coordinator.telemetry.value(for: pid.id)

        Group {
            switch widget.widgetType {
            case .radialGauge:
                RadialGaugeView(name: pid.name, value: value ?? range.lowerBound, unit: pid.unit, range: range)
            case .linearBarGauge:
                LinearBarGaugeView(name: pid.name, value: value ?? range.lowerBound, unit: pid.unit, range: range)
            case .digitalCard:
                DigitalCardView(name: pid.name, value: value, unit: pid.unit, isVerified: pid.verified)
            case .sparklineCard:
                SparklineCardView(name: pid.name, value: value, unit: pid.unit, samples: coordinator.telemetry.samples(for: pid.id, within: 60), range: range)
            }
        }
        .carxCard()
    }

    private func seedLayoutIfNeeded() {
        if layouts.isEmpty {
            let layout = DashboardLayout.makeDefault(for: pack)
            modelContext.insert(layout)
            selectedLayout = layout
        } else if selectedLayout == nil {
            selectedLayout = layouts.first
        }
    }

    private func updateActivePIDs() {
        guard let layout = selectedLayout else { return }
        let pids = layout.widgets.compactMap { pidsByID[$0.pidID] }
        coordinator.setActivePIDs(pids)
    }

    private func remove(_ widget: WidgetConfig, from layout: DashboardLayout) {
        layout.widgets.removeAll { $0.id == widget.id }
        modelContext.delete(widget)
        updateActivePIDs()
    }
}

private struct NewLayoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Layout name", text: $name)
            }
            .navigationTitle("New Layout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name.isEmpty ? "Untitled Layout" : name)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(180)])
    }
}
