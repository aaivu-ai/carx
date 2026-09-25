import SwiftUI
import SwiftData

struct ChartsView: View {
    @Environment(OBDCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    @Query private var presets: [ChartPreset]

    @State private var isPresentingBuilder = false
    @State private var selectedPreset: ChartPreset?
    @State private var csvURL: IdentifiableURL?

    private var pack: VehiclePack { coordinator.telemetry.activePack }
    private var pidsByID: [String: PID] { Dictionary(uniqueKeysWithValues: pack.allPIDs.map { ($0.id, $0) }) }

    var body: some View {
        NavigationStack {
            ZStack {
                CaRxBackground()
                if let preset = selectedPreset {
                    VStack(spacing: 12) {
                        MultiSeriesChartView(
                            seriesPIDs: preset.seriesPIDIDs.compactMap { pidsByID[$0] },
                            rangeOverrides: preset.rangeOverrides,
                            windowSeconds: preset.timeWindowSeconds
                        )
                        HStack {
                            Button { selectedPreset = nil } label: {
                                Label("Presets", systemImage: "chevron.left")
                            }
                            Spacer()
                            Button {
                                exportCSV(preset: preset)
                            } label: {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                    .padding()
                } else {
                    List {
                        Section("Saved Multi-Series Charts") {
                            if presets.isEmpty {
                                Text("No saved charts yet.").foregroundStyle(.secondary)
                            } else {
                                ForEach(presets) { preset in
                                    Button {
                                        selectedPreset = preset
                                    } label: {
                                        VStack(alignment: .leading) {
                                            Text(preset.name).font(.headline)
                                            Text(preset.seriesPIDIDs.compactMap { pidsByID[$0]?.name }.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .onDelete { indices in
                                    for index in indices { modelContext.delete(presets[index]) }
                                }
                            }
                        }
                        .listRowBackground(CaRxTheme.surface.opacity(0.6))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Charts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ConnectionStatusBanner(state: coordinator.connectionState)
                }
                if selectedPreset == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isPresentingBuilder = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isPresentingBuilder) {
                ChartBuilderSheet(pack: pack) { preset in
                    selectedPreset = preset
                }
            }
            .sheet(item: $csvURL) { wrapper in
                ShareLink(item: wrapper.url) {
                    Label("Share \(wrapper.url.lastPathComponent)", systemImage: "square.and.arrow.up")
                        .padding()
                }
                .presentationDetents([.height(120)])
            }
        }
    }

    private func exportCSV(preset: ChartPreset) {
        let pids = preset.seriesPIDIDs.compactMap { pidsByID[$0] }
        var rows = ["timestamp," + pids.map(\.name).joined(separator: ",")]
        let allTimestamps = Set(pids.flatMap { coordinator.telemetry.samples(for: $0.id, within: preset.timeWindowSeconds).map(\.timestamp) }).sorted()
        for timestamp in allTimestamps {
            var row = [ISO8601DateFormatter().string(from: timestamp)]
            for pid in pids {
                let sample = coordinator.telemetry.samples(for: pid.id, within: preset.timeWindowSeconds).first { $0.timestamp == timestamp }
                row.append(sample.map { String($0.value) } ?? "")
            }
            rows.append(row.joined(separator: ","))
        }
        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(preset.name)-\(Int(Date().timeIntervalSince1970)).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        csvURL = IdentifiableURL(url: url)
    }
}

struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
