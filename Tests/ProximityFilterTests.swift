import Foundation

func proximityFilterTests() {
    let t0 = Date(timeIntervalSince1970: 0)

    suite("Watch: comes in range at the threshold") {
        var f = ProximityFilter(inThreshold: -70)
        check(f.add(-75, at: t0) == .none, "below threshold stays out")
        check(f.add(-60, at: t0 + 1) == .none, "median still low")
        check(f.add(-60, at: t0 + 2) == .cameInRange, "median above threshold -> in range")
    }

    suite("Watch: jitter around the threshold never flaps (Firefox bug)") {
        var f = ProximityFilter(inThreshold: -70)
        _ = f.add(-65, at: t0)
        check(f.inRange, "starts in range")
        var changes = 0
        // 10 minutes of -69/-70/-71/-72/-73 every 5 s, like the real log.
        let pattern = [-71, -70, -72, -69, -71, -73, -70, -71]
        for i in 0..<120 {
            if f.add(pattern[i % pattern.count], at: t0 + Double(5 * (i + 1))) != .none { changes += 1 }
        }
        check(changes == 0, "no range change while hovering at -70 (got \(changes))")
        check(f.inRange, "still in range")
    }

    suite("Watch: a single bad spike is ignored") {
        var f = ProximityFilter(inThreshold: -70)
        _ = f.add(-60, at: t0)
        for i in 1...20 {
            let rssi = (i == 10) ? -95 : -62
            check(f.add(rssi, at: t0 + Double(i)) == .none, "spike \(i) ignored")
        }
        check(f.inRange, "still in range after spike")
    }

    suite("Watch: walking away goes out of range within ~30 s") {
        var f = ProximityFilter(inThreshold: -70)
        _ = f.add(-60, at: t0)
        var wentOutAt: Double?
        for i in 1...12 {
            let time = Double(5 * i)
            if f.add(-88, at: t0 + time) == .wentOutOfRange { wentOutAt = time; break }
        }
        check(wentOutAt != nil, "went out of range")
        check((wentOutAt ?? 999) <= 30, "within 30 s (took \(wentOutAt ?? -1) s)")
    }

    suite("Watch: coming back needs the full threshold, not just the dead band") {
        var f = ProximityFilter(inThreshold: -70)
        _ = f.add(-60, at: t0)
        for i in 1...10 { _ = f.add(-90, at: t0 + Double(5 * i)) }
        check(!f.inRange, "out of range")
        var t = t0 + 100
        for _ in 0..<6 { t += 5; check(f.add(-75, at: t) == .none, "-75 is in the dead band: stays out") }
        for _ in 0..<4 { t += 5; _ = f.add(-65, at: t) }
        check(f.inRange, "back in range at -65")
    }

    suite("Watch: reset forgets everything") {
        var f = ProximityFilter(inThreshold: -70)
        _ = f.add(-60, at: t0)
        f.reset()
        check(!f.inRange && f.median == nil, "reset")
    }
}
