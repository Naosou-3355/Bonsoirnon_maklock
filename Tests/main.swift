import Foundation

proximityFilterTests()
passwordTests()
lockoutAndStorageTests()

print("\n\(TestRun.passes) checks passed, \(TestRun.failures) failed")
exit(TestRun.failures == 0 ? 0 : 1)
