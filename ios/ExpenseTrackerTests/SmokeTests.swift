import Foundation
import Testing
@testable import ExpenseTracker

@Suite struct SmokeTests {
    @Test func appModuleLoads() { #expect(Bundle.main.bundleIdentifier != nil) }
}
