import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("activeProfileIDString") private var activeProfileIDString: String = ""

    private let packs = VehiclePackLoader.loadAll()

    @State private var selectedPack: VehiclePack?
    @State private var profileName = ""
    @State private var connectionMode: ConnectionMode = .wifi
    @State private var wifiHost = "192.168.0.10"
    @State private var wifiPort = "35000"
    @State private var step = 0

    var body: some View {
        NavigationStack {
            ZStack {
                CaRxBackground()
                VStack(spacing: 24) {
                    header

                    if step == 0 {
                        vehicleStep
                    } else {
                        connectionStep
                    }

                    Spacer()

                    Button(step == 0 ? "Next" : "Finish Setup") {
                        if step == 0 {
                            profileName = selectedPack?.displayName ?? ""
                            step = 1
                        } else {
                            createProfile()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CaRxTheme.accent)
                    .disabled(step == 0 && selectedPack == nil)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("CaRx")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [CaRxTheme.accent, CaRxTheme.accentSecondary], startPoint: .leading, endPoint: .trailing)
                )
                .carxGlow(CaRxTheme.accent)
            Text(step == 0 ? "Choose your vehicle" : "Choose how to connect")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }

    private var vehicleStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(packs) { pack in
                    Button {
                        selectedPack = pack
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pack.displayName).font(.headline).foregroundStyle(.white)
                            Text(pack.ecuAccessNotes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .carxCard()
                    .overlay(
                        RoundedRectangle(cornerRadius: CaRxTheme.cornerRadius)
                            .stroke(selectedPack?.id == pack.id ? CaRxTheme.accent : .clear, lineWidth: 2)
                    )
                }
            }
        }
    }

    private var connectionStep: some View {
        VStack(spacing: 18) {
            Picker("Connection", selection: $connectionMode) {
                ForEach(ConnectionMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if connectionMode == .wifi {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Wi-Fi ELM327 adapters typically host a small TCP server once you join their access point.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Host", text: $wifiHost)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Port", text: $wifiPort)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
                .carxCard()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Bluetooth LE adapters only", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(CaRxTheme.warning)
                        .font(.subheadline.weight(.semibold))
                    Text("Classic Bluetooth (SPP) ELM327 clones aren't supported -- iOS has no public API for Bluetooth Classic. Use a BLE adapter such as an OBDLink CX/MX+ or Vgate iCar Pro BLE. You'll pick your adapter from a scan after setup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .carxCard()
            }

            TextField("Profile name", text: $profileName)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func createProfile() {
        guard let selectedPack else { return }
        let profile = VehicleProfile(
            name: profileName.isEmpty ? selectedPack.displayName : profileName,
            vehiclePackID: selectedPack.id,
            connectionMode: connectionMode,
            wifiHost: wifiHost,
            wifiPort: Int(wifiPort) ?? 35000
        )
        modelContext.insert(profile)
        activeProfileIDString = profile.id.uuidString

        let layout = DashboardLayout.makeDefault(for: selectedPack)
        modelContext.insert(layout)
    }
}
