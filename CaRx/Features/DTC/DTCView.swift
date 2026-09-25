import SwiftUI
import SwiftData

struct DTCView: View {
    @Environment(OBDCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    let activeProfile: VehicleProfile

    @State private var isRefreshing = false
    @State private var isClearing = false
    @State private var isPresentingClearConfirmation = false
    @State private var isPresentingClearResult = false
    @State private var clearResultMessage: String = ""
    @State private var freezeFrameDTC: String?
    @State private var selectedCurrentCode: DiagnosticCode?

    var body: some View {
        NavigationStack {
            ZStack {
                CaRxBackground()
                List {
                    section("Current", codes: coordinator.telemetry.currentDTCs, tint: CaRxTheme.danger, allowSelection: true)
                    section("Pending", codes: coordinator.telemetry.pendingDTCs, tint: CaRxTheme.warning)
                    section("Permanent", codes: coordinator.telemetry.permanentDTCs, tint: .secondary)

                    if let selectedCurrentCode {
                        Section("Freeze Frame") {
                            if let freezeFrameDTC {
                                Text("Freeze frame captured at fault: \(freezeFrameDTC)")
                                    .font(.callout)
                            } else {
                                Text("No freeze frame stored for \(selectedCurrentCode.code).")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let lastPoll = coordinator.telemetry.lastDTCPollDate {
                        Section {
                            Text("Last read: \(lastPoll.formatted(date: .omitted, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Trouble Codes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ConnectionStatusBanner(state: coordinator.connectionState)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(isRefreshing)

                    Button(role: .destructive) {
                        isPresentingClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(isClearing || coordinator.telemetry.currentDTCs.isEmpty)
                }
            }
            .task { await refresh() }
            .confirmationDialog(
                "Clear all stored trouble codes? This cannot be undone.",
                isPresented: $isPresentingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Codes", role: .destructive) { Task { await clear() } }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Clear Codes", isPresented: $isPresentingClearResult) {
                Button("OK") {}
            } message: {
                Text(clearResultMessage)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, codes: [DiagnosticCode], tint: Color, allowSelection: Bool = false) -> some View {
        Section(title) {
            if codes.isEmpty {
                Label("No codes detected", systemImage: "checkmark.circle")
                    .foregroundStyle(CaRxTheme.success)
            } else {
                ForEach(codes) { dtc in
                    Button {
                        guard allowSelection else { return }
                        selectedCurrentCode = dtc
                        Task { freezeFrameDTC = await coordinator.readFreezeFrameDTC() }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(dtc.code)
                                .font(.headline.monospaced())
                                .foregroundStyle(tint)
                            Text(dtc.description)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowBackground(CaRxTheme.surface.opacity(0.6))
    }

    private func refresh() async {
        isRefreshing = true
        await coordinator.refreshDTCs()
        logEvent(.read, codes: coordinator.telemetry.currentDTCs.map(\.code))
        isRefreshing = false
    }

    private func clear() async {
        isClearing = true
        let success = await coordinator.eraseDTCs()
        logEvent(.cleared, codes: [])
        clearResultMessage = success
            ? "Trouble codes cleared successfully."
            : "The adapter did not confirm the codes were cleared. Some ECUs reject a clear while the check-engine condition is still active -- try again after the underlying issue is fixed."
        isPresentingClearResult = true
        isClearing = false
    }

    private func logEvent(_ type: DiagnosticEventType, codes: [String]) {
        let record = DiagnosticEventRecord(eventType: type, codes: codes, vehicleProfileName: activeProfile.name)
        modelContext.insert(record)
    }
}
