import ActivityKit
import Foundation

nonisolated struct CommandCenterActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var completedCount: Int
        var totalCount: Int
        var workingCount: Int
        var failedCount: Int
        var noAccCount: Int
        var tempDisCount: Int
        var permDisCount: Int
        var statusLabel: String
        var elapsedSeconds: Int
        var isPaused: Bool
        var isStopping: Bool
        var successRate: Double
        var speedPerMinute: Double
        var activeWorkers: Int
        var currentCredential: String
        var networkMode: String
    }

    var siteLabel: String
    var siteMode: String
    var startedAt: Date
}
