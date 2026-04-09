import ActivityKit
import Foundation
import Observation

@Observable
@MainActor
class LiveActivityService {
    static let shared = LiveActivityService()

    private var currentActivity: Activity<CommandCenterActivityAttributes>?
    private var updateTimer: Timer?
    private var startDate: Date?
    private var widgetSyncTimer: Timer?

    var isActivityActive: Bool {
        currentActivity != nil
    }

    func startActivity(siteLabel: String, siteMode: String, totalCount: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            DebugLogger.shared.log("Live Activities not enabled by user", category: .system, level: .warning)
            return
        }

        endActivity()

        let now = Date()
        let attributes = CommandCenterActivityAttributes(
            siteLabel: siteLabel,
            siteMode: siteMode,
            startedAt: now
        )

        let initialState = CommandCenterActivityAttributes.ContentState(
            completedCount: 0,
            totalCount: totalCount,
            workingCount: 0,
            failedCount: 0,
            noAccCount: 0,
            tempDisCount: 0,
            permDisCount: 0,
            statusLabel: "LIVE",
            elapsedSeconds: 0,
            isPaused: false,
            isStopping: false,
            successRate: 0,
            speedPerMinute: 0,
            activeWorkers: 0,
            currentCredential: "",
            networkMode: ""
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: Date().addingTimeInterval(120)),
                pushType: nil
            )
            currentActivity = activity
            startDate = now
            startPeriodicUpdates()
            WidgetDataService.shared.pushUpdate()
            DebugLogger.shared.log("Live Activity started for \(siteLabel)", category: .system, level: .info)
        } catch {
            DebugLogger.shared.log("Failed to start Live Activity: \(error.localizedDescription)", category: .system, level: .error)
        }
    }

    func updateActivity() {
        guard let activity = currentActivity else { return }

        let vm = RunCommandViewModel.shared
        let elapsed = startDate.map { Int(Date().timeIntervalSince($0)) } ?? 0

        let state = CommandCenterActivityAttributes.ContentState(
            completedCount: vm.completedCount,
            totalCount: vm.totalCount,
            workingCount: vm.workingCount,
            failedCount: vm.failedCount,
            noAccCount: vm.noAccCount,
            tempDisCount: vm.tempDisCount,
            permDisCount: vm.permDisCount,
            statusLabel: vm.statusLabel,
            elapsedSeconds: elapsed,
            isPaused: vm.isPaused,
            isStopping: vm.isStopping,
            successRate: vm.successRate,
            speedPerMinute: vm.speedPerMinute,
            activeWorkers: vm.activeWorkerCount,
            currentCredential: vm.currentCredentialLabel,
            networkMode: vm.networkModeLabel
        )

        Task {
            await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(120)))
        }

        WidgetDataService.shared.pushUpdate()
    }

    func endActivity() {
        guard let activity = currentActivity else { return }

        stopPeriodicUpdates()

        let vm = RunCommandViewModel.shared
        let elapsed = startDate.map { Int(Date().timeIntervalSince($0)) } ?? 0

        let finalState = CommandCenterActivityAttributes.ContentState(
            completedCount: vm.completedCount,
            totalCount: vm.totalCount,
            workingCount: vm.workingCount,
            failedCount: vm.failedCount,
            noAccCount: vm.noAccCount,
            tempDisCount: vm.tempDisCount,
            permDisCount: vm.permDisCount,
            statusLabel: "DONE",
            elapsedSeconds: elapsed,
            isPaused: false,
            isStopping: false,
            successRate: vm.successRate,
            speedPerMinute: vm.speedPerMinute,
            activeWorkers: 0,
            currentCredential: "",
            networkMode: vm.networkModeLabel
        )

        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(120)))
            DebugLogger.shared.log("Live Activity ended", category: .system, level: .info)
        }

        currentActivity = nil
        startDate = nil

        WidgetDataService.shared.pushIdleUpdate()
    }

    func endAllStaleActivities() {
        Task {
            for activity in Activity<CommandCenterActivityAttributes>.activities {
                let finalState = CommandCenterActivityAttributes.ContentState(
                    completedCount: 0, totalCount: 0, workingCount: 0, failedCount: 0,
                    noAccCount: 0, tempDisCount: 0, permDisCount: 0,
                    statusLabel: "ENDED", elapsedSeconds: 0,
                    isPaused: false, isStopping: false, successRate: 0,
                    speedPerMinute: 0, activeWorkers: 0,
                    currentCredential: "", networkMode: ""
                )
                await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            }
        }
    }

    private func startPeriodicUpdates() {
        stopPeriodicUpdates()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateActivity()
            }
        }
    }

    private func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}
