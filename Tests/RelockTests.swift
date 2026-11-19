import Foundation

func relockTests() {
    let t0 = Date(timeIntervalSince1970: 0)

    suite("Re-lock delay: 5 min") {
        var r = RelockTracker()
        r.didLeave("ff", at: t0)
        check(!r.shouldRelockOnReturn("ff", delay: 300, at: t0 + 60), "back after 1 min: stays unlocked")
        r.didLeave("ff", at: t0 + 100)
        check(r.shouldRelockOnReturn("ff", delay: 300, at: t0 + 100 + 301), "back after 5 min: asks again")
    }

    suite("Re-lock delay: never, and app never left") {
        var r = RelockTracker()
        r.didLeave("ff", at: t0)
        check(!r.shouldRelockOnReturn("ff", delay: RelockDelay.never, at: t0 + 99_999), "never: stays unlocked")
        check(!r.shouldRelockOnReturn("chess", delay: 60, at: t0 + 99_999), "not left: stays unlocked")
    }

    suite("Re-lock delay: weaker / stronger") {
        check(RelockDelay.isWeaker(300, than: 0), "5 min weaker than immediately")
        check(RelockDelay.isWeaker(RelockDelay.never, than: 900), "never weaker than 15 min")
        check(!RelockDelay.isWeaker(0, than: RelockDelay.never), "immediately stronger than never")
        check(!RelockDelay.isWeaker(60, than: 60), "same is not weaker")
    }

    suite("Settings: the real settings from this Mac survive the update") {
        // Exactly what was stored before relockDelay existed.
        let json = #"{"lockOnSleep":true,"launchAtLogin":true,"useWatchUnlock":true,"lockOnIdle":false,"inactiveCloseMinutes":15,"requireAuthOnActivate":false,"requireAuthOnLaunch":true,"isProtectionEnabled":true,"idleTimeoutMinutes":5,"watchRssiThreshold":-70}"#
        let s = try? JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        check(s != nil, "decodes")
        check(s?.useWatchUnlock == true && s?.launchAtLogin == true, "keeps Watch and login settings")
        check(s?.relockDelay == RelockDelay.never, "app switch off -> never")
        let on = try? JSONDecoder().decode(AppSettings.self, from: Data(#"{"requireAuthOnActivate":true}"#.utf8))
        check(on?.relockDelay == 0, "app switch on -> immediately")
        check(on?.isProtectionEnabled == true && on?.watchRssiThreshold == -70, "missing keys get defaults")
    }
}

func activityTests() {
    suite("Journal: newest first, capped at 200") {
        var h = ActivityHistory()
        for i in 0..<250 {
            h.append(ActivityEvent(date: Date(timeIntervalSince1970: Double(i)), kind: .wrongPassword, appName: "\(i)"))
        }
        check(h.events.count == 200, "capped")
        check(h.events.first?.appName == "249", "newest first")
        check(h.events.last?.appName == "50", "oldest dropped")
        let back = try? JSONDecoder().decode(ActivityHistory.self, from: JSONEncoder().encode(h))
        check(back == h, "round-trips")
    }
    suite("Journal: suspicious events") {
        check(ActivityKind.wrongPassword.isSuspicious && ActivityKind.quitRefused.isSuspicious, "failures are suspicious")
        check(!ActivityKind.unlockTouchID.isSuspicious, "normal unlock is not")
    }
}
