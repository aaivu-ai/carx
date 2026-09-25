import SwiftUI
import Charts

struct SingleSensorChartView: View {
    @Environment(OBDCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    let pid: PID

    @State private var windowSeconds: Double = 60
    @State private var isPaused = false
    @State private var pausedSamples: [RollingBuffer.Sample] = []

    private let windowOptions: [(String, Double)] = [("30s", 30), ("1m", 60), ("5m", 300)]

    private var samples: [RollingBuffer.Sample] {
        isPaused ? pausedSamples : coordinator.telemetry.samples(for: pid.id, within: windowSeconds)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CaRxBackground()
                VStack(spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(coordinator.telemetry.value(for: pid.id)?.formattedGauge ?? "--")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(pid.unit)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Window", selection: $windowSeconds) {
                            ForEach(windowOptions, id: \.1) { label, value in
                                Text(label).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    Chart(samples) { sample in
                        LineMark(x: .value("Time", sample.timestamp), y: .value(pid.name, sample.value))
                            .foregroundStyle(CaRxTheme.accent)
                            .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("Time", sample.timestamp), y: .value(pid.name, sample.value))
                            .foregroundStyle(LinearGradient(colors: [CaRxTheme.accent.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: pid.range)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                    .frame(maxHeight: .infinity)
                    .carxCard()

                    Button {
                        if isPaused {
                            isPaused = false
                        } else {
                            pausedSamples = coordinator.telemetry.samples(for: pid.id, within: windowSeconds)
                            isPaused = true
                        }
                    } label: {
                        Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CaRxTheme.accent)
                }
                .padding()
            }
            .navigationTitle(pid.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
