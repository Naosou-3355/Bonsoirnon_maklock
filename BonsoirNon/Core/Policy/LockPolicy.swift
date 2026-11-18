import Foundation

/// Pure decision rules, free of AppKit and system services so they can be unit-tested
/// (see Tests/ and scripts/run-tests.sh).

// MARK: - Proximity filter

/// Decides whether the Watch is in range from noisy RSSI readings.
///
/// Raw RSSI jitters by several dB, so a single threshold makes the state flap
/// (in, out, in, out every minute) and re-locks apps for nothing. This filter:
/// - uses the median of the last `windowSeconds` of readings (ignores spikes);
/// - comes back in range at `inThreshold` but only goes out below
///   `inThreshold - hysteresis` (a dead band where nothing changes);
/// - requires the low median to hold for `outHoldSeconds` before going out.
struct ProximityFilter {
    enum Change { case none, cameInRange, wentOutOfRange }

    var inThreshold: Int
    var hysteresis = 10
    var windowSeconds: TimeInterval = 15
    var outHoldSeconds: TimeInterval = 10

    private(set) var inRange = false
    private var samples: [(date: Date, rssi: Int)] = []
    private var belowSince: Date?

    init(inThreshold: Int) {
        self.inThreshold = inThreshold
    }

    var outThreshold: Int { inThreshold - hysteresis }

    var median: Int? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.map(\.rssi).sorted()
        return sorted[(sorted.count - 1) / 2]   // lower median: cautious with an even count
    }

    mutating func add(_ rssi: Int, at now: Date = Date()) -> Change {
        samples.append((now, rssi))
        samples.removeAll { now.timeIntervalSince($0.date) > windowSeconds }
        guard let median else { return .none }

        if inRange {
            guard median < outThreshold else {
                belowSince = nil
                return .none
            }
            let since = belowSince ?? now
            belowSince = since
            if now.timeIntervalSince(since) >= outHoldSeconds {
                inRange = false
                belowSince = nil
                return .wentOutOfRange
            }
            return .none
        }

        if median >= inThreshold {
            inRange = true
            belowSince = nil
            return .cameInRange
        }
        return .none
    }

    mutating func reset() {
        inRange = false
        samples.removeAll()
        belowSince = nil
    }
}
