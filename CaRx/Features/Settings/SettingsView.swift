import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VehicleProfile.createdAt) private var profiles: [VehicleProfile]
    @AppStorage("activeProfileIDString") private var activeProfileIDString: String = ""
    @AppStorage("useMockHardware") private var useMockHardware: Bool = true
    let activeProfile: VehicleProfile

    @State private var isPresentingAddProfile = false
    @State private var isPresentingRawTool = false

    var body: some View {
        NavigationStack {
            ZStack {
                CaRxBackground()
                List {
                    Section("Demo Mode") {
                        Toggle("Use simulated data", isOn: $useMockHardware)
                        Text("On by default so CaRx is fully demoable without a physical OBD-II adapter. Turn off to connect real Bluetooth LE / Wi-Fi hardware.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Vehicle Profiles") {
                        ForEach(profiles) { profile in
                            Button {
                                activeProfileIDString = profile.id.uuidString
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(profile.name).foregroundStyle(.primary)
                                        Text("\(profile.connectionMode.rawValue) · \(VehiclePackLoader.load(named: profile.vehiclePackID)?.displayName ?? profile.vehiclePackID)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if profile.id.uuidString == activeProfileIDString {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(CaRxTheme.accent)
                                    }
                                }
                            }
                        }
                        .onDelete { indices in
                            for index in indices { modelContext.delete(profiles[index]) }
                        }
                        Button("Add Vehicle Profile", systemImage: "plus") { isPresentingAddProfile = true }
                    }

                    Section("Advanced") {
                        Button("Raw PID Discovery Tool", systemImage: "waveform.badge.magnifyingglass") {
                            isPresentingRawTool = true
                        }
                        NavigationLink {
                            DiagnosticHistoryView()
                        } label: {
                            Label("Diagnostic Event History", systemImage: "clock.arrow.circlepath")
                        }
                    }

                    Section("About CaRx") {
                        Text("App from aaivu.co — TheSaravanas Group of Companies")
                            .font(.subheadline.weight(.semibold))
                        Text("CaRx turns your phone into a live OBD-II diagnostic dashboard. Connect a Bluetooth LE or Wi-Fi ELM327 adapter to watch configurable gauges and charts, read and clear trouble codes, and keep an eye on your vehicle's sensors, with a simplified view on CarPlay.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                            LabeledContent("Version", value: version)
                                .font(.caption)
                        }
                    }
                    .listRowBackground(CaRxTheme.surface.opacity(0.6))

                    Section("About CarPlay") {
                        Text("Full gauges and charts are on the iPhone screen. CarPlay shows a simplified, glanceable list of live values and DTC status, per Apple's CarPlay template restrictions for non-navigation apps.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isPresentingAddProfile) {
                AddVehicleProfileSheet()
            }
            .sheet(isPresented: $isPresentingRawTool) {
                RawDiscoveryView()
            }
        }
    }
}

private struct AddVehicleProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("activeProfileIDString") private var activeProfileIDString: String = ""
    private let packs = VehiclePackLoader.loadAll()

    @State private var selectedPack: VehiclePack?
    @State private var name = ""
    @State private var connectionMode: ConnectionMode = .wifi
    @State private var wifiHost = "192.168.0.10"
    @State private var wifiPort = "35000"

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle") {
                    Picker("Vehicle Pack", selection: $selectedPack) {
                        Text("Select").tag(Optional<VehiclePack>.none)
                        ForEach(packs) { pack in Text(pack.displayName).tag(Optional(pack)) }
                    }
                }
                Section("Name") {
                    TextField("Profile name", text: $name)
                }
                Section("Connection") {
                    Picker("Mode", selection: $connectionMode) {
                        ForEach(ConnectionMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if connectionMode == .wifi {
                        TextField("Host", text: $wifiHost)
                        TextField("Port", text: $wifiPort).keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("New Vehicle Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(selectedPack == nil)
                }
            }
        }
    }

    private func save() {
        guard let selectedPack else { return }
        let profile = VehicleProfile(
            name: name.isEmpty ? selectedPack.displayName : name,
            vehiclePackID: selectedPack.id,
            connectionMode: connectionMode,
            wifiHost: wifiHost,
            wifiPort: Int(wifiPort) ?? 35000
        )
        modelContext.insert(profile)
        activeProfileIDString = profile.id.uuidString

        let layout = DashboardLayout.makeDefault(for: selectedPack)
        modelContext.insert(layout)
        dismiss()
    }
}

private struct DiagnosticHistoryView: View {
    @Query(sort: \DiagnosticEventRecord.timestamp, order: .reverse) private var events: [DiagnosticEventRecord]

    var body: some View {
        List(events) { event in
            VStack(alignment: .leading) {
                Text(event.eventType == .cleared ? "Cleared Codes" : "Read Codes")
                    .font(.headline)
                Text(event.codes.isEmpty ? "No codes" : event.codes.joined(separator: ", "))
                    .font(.caption)
                Text(event.timestamp.formatted())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Event History")
    }
}
