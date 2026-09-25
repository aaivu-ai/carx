import SwiftUI

/// Advanced tool for verifying/correcting enhanced PIDs against a real vehicle:
/// send an arbitrary mode+PID hex string at an arbitrary ECU header and see the raw
/// response. This is the standard workflow the OBD hobbyist community uses to reverse
/// engineer manufacturer-specific PIDs -- see §5b of the dev prompt.
struct RawDiscoveryView: View {
    @Environment(OBDCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @State private var header = "7E0"
    @State private var request = "010C"
    @State private var responseText = ""
    @State private var isSending = false
    @State private var history: [(request: String, response: String)] = []

    var body: some View {
        NavigationStack {
            ZStack {
                CaRxBackground()
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ECU Header").font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. 7E0", text: $header)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)

                        Text("Mode + PID (hex)").font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. 010C or 2211B0", text: $request)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)

                        Button {
                            Task { await send() }
                        } label: {
                            if isSending { ProgressView() } else { Text("Send").frame(maxWidth: .infinity) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CaRxTheme.accent)
                        .disabled(isSending || coordinator.connectionState != .connected)
                    }
                    .carxCard()

                    List(history.indices.reversed(), id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(history[index].request).font(.caption.monospaced()).foregroundStyle(CaRxTheme.accent)
                            Text(history[index].response).font(.callout.monospaced())
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
                .padding()
            }
            .navigationTitle("Raw PID Discovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private func send() async {
        isSending = true
        let result = await coordinator.sendRawDiagnostic(header: header, request: request)
        switch result {
        case .success(let response):
            history.append((request: "\(header) → \(request)", response: response))
        case .failure(let error):
            history.append((request: "\(header) → \(request)", response: "Error: \(error.localizedDescription)"))
        }
        isSending = false
    }
}
