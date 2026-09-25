import Foundation

/// A fixed-capacity FIFO sample buffer backing both gauge "latest value" reads
/// and chart history, so both views are always looking at the same data.
struct RollingBuffer {
    struct Sample: Identifiable {
        let id = UUID()
        let timestamp: Date
        let value: Double
    }

    private(set) var samples: [Sample] = []
    let capacity: Int

    init(capacity: Int = 240) {
        self.capacity = capacity
    }

    var latest: Double? { samples.last?.value }

    mutating func append(_ value: Double) {
        samples.append(Sample(timestamp: Date(), value: value))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    func samples(within window: TimeInterval) -> [Sample] {
        let cutoff = Date().addingTimeInterval(-window)
        return samples.filter { $0.timestamp >= cutoff }
    }
}
