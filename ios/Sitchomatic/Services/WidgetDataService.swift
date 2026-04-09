import Foundation
import WidgetKit

@MainActor
class WidgetDataService {
    static let shared = WidgetDataService()

    private let suiteName = "group.app.rork.ve5l1conjgc135kle8kuj"

    private var shared: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    func pushUpdate() {
        guard let defaults = shared else { return }

        let vm = RunCommandViewModel.shared
        let loginVM = LoginViewModel.shared
        let ppsrVM = PPSRAutomationViewModel.shared
        let unifiedVM = UnifiedSessionViewModel.shared

        defaults.set(vm.isAnyRunning, forKey: "widget_isRunning")
        defaults.set(vm.activeMode.rawValue, forKey: "widget_activeMode")
        defaults.set(vm.siteLabel, forKey: "widget_siteLabel")
        defaults.set(vm.completedCount, forKey: "widget_completed")
        defaults.set(vm.totalCount, forKey: "widget_total")
        defaults.set(vm.workingCount, forKey: "widget_working")
        defaults.set(vm.failedCount, forKey: "widget_failed")
        defaults.set(vm.noAccCount, forKey: "widget_noAcc")
        defaults.set(vm.tempDisCount, forKey: "widget_tempDis")
        defaults.set(vm.permDisCount, forKey: "widget_permDis")
        defaults.set(vm.successRate, forKey: "widget_successRate")
        defaults.set(vm.isPaused, forKey: "widget_isPaused")
        defaults.set(vm.isStopping, forKey: "widget_isStopping")
        defaults.set(vm.statusLabel, forKey: "widget_statusLabel")
        defaults.set(vm.elapsedString, forKey: "widget_elapsed")
        defaults.set(vm.etaString, forKey: "widget_eta")
        defaults.set(vm.maxConcurrency, forKey: "widget_concurrency")
        defaults.set(vm.networkModeLabel, forKey: "widget_networkMode")
        defaults.set(vm.speedPerMinute, forKey: "widget_speedPerMin")

        let totalCredentials = loginVM.credentials.count + unifiedVM.sessions.count
        let totalCards = ppsrVM.cards.count
        let workingCredentials = loginVM.credentials.filter { $0.status == .working }.count + unifiedVM.successSessions.count
        let workingCards = ppsrVM.workingCards.count

        defaults.set(totalCredentials, forKey: "widget_totalCredentials")
        defaults.set(totalCards, forKey: "widget_totalCards")
        defaults.set(workingCredentials, forKey: "widget_workingCredentials")
        defaults.set(workingCards, forKey: "widget_workingCards")
        defaults.set(Date().timeIntervalSince1970, forKey: "widget_lastUpdate")

        Task {
            let stats = StatsTrackingService.shared
            let lifetimeTested = await stats.lifetimeTested
            let lifetimeWorking = await stats.lifetimeWorking
            let lifetimeRate = await stats.lifetimeSuccessRate
            let totalBatches = await stats.totalBatches

            defaults.set(lifetimeTested, forKey: "widget_lifetimeTested")
            defaults.set(lifetimeWorking, forKey: "widget_lifetimeWorking")
            defaults.set(lifetimeRate, forKey: "widget_lifetimeRate")
            defaults.set(totalBatches, forKey: "widget_totalBatches")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    func pushIdleUpdate() {
        guard let defaults = shared else { return }
        defaults.set(false, forKey: "widget_isRunning")
        defaults.set(Date().timeIntervalSince1970, forKey: "widget_lastUpdate")

        let loginVM = LoginViewModel.shared
        let ppsrVM = PPSRAutomationViewModel.shared
        let unifiedVM = UnifiedSessionViewModel.shared

        let totalCredentials = loginVM.credentials.count + unifiedVM.sessions.count
        let workingCredentials = loginVM.credentials.filter { $0.status == .working }.count + unifiedVM.successSessions.count
        let totalCards = ppsrVM.cards.count
        let workingCards = ppsrVM.workingCards.count

        defaults.set(totalCredentials, forKey: "widget_totalCredentials")
        defaults.set(totalCards, forKey: "widget_totalCards")
        defaults.set(workingCredentials, forKey: "widget_workingCredentials")
        defaults.set(workingCards, forKey: "widget_workingCards")

        Task {
            let stats = StatsTrackingService.shared
            defaults.set(await stats.lifetimeTested, forKey: "widget_lifetimeTested")
            defaults.set(await stats.lifetimeWorking, forKey: "widget_lifetimeWorking")
            defaults.set(await stats.lifetimeSuccessRate, forKey: "widget_lifetimeRate")
            defaults.set(await stats.totalBatches, forKey: "widget_totalBatches")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
