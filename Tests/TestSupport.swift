import Foundation

/// Minimal test harness: no XCTest target needed, runs with `scripts/run-tests.sh`.
enum TestRun {
    static var failures = 0
    static var passes = 0
}

func check(_ condition: Bool, _ name: String, file: String = #fileID, line: Int = #line) {
    if condition {
        TestRun.passes += 1
    } else {
        TestRun.failures += 1
        print("FAIL \(name)  (\(file):\(line))")
    }
}

func suite(_ name: String, _ body: () -> Void) {
    let before = TestRun.failures
    body()
    print(TestRun.failures == before ? "ok   \(name)" : "FAIL \(name)")
}
