import SwiftUI
import Combine

struct RunCommandSheetView: View {
    @State private var vm = RunCommandViewModel.shared
    @State private var timerTick: Int = 0
    @State private var selectedTab: CommandTab = .overview

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    nonisolated enum CommandTab: String, CaseIterable, Sendable {
        case overview = "Overview"
        case sessions = "Sessions"
        case results = "Results"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    batchHeader
                    tabSelector
                    
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .sessions:
                        sessionsContent
                    case .results:
                        resultsContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Command Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: vm.siteIcon)
                            .foregroundStyle(vm.siteColor)
                        Text(vm.siteLabel)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { vm.showFullSheet = false }
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .onReceive(timer) { _ in timerTick += 1 }
    }

    private var batchHeader: some View {
        VStack(spacing: 10) {
            HStack {
                statusPill
                Spacer()
                if vm.speedPerMinute > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(vm.speedPerMinuteFormatted)
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.cyan.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            HStack(alignment: .bottom) {
                Text("\(vm.completedCount)")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("/ \(vm.totalCount)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("\(Int(vm.successRate * 100))%")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(rateColor(vm.successRate))
            }

            ProgressView(value: vm.progress)
                .tint(vm.siteColor)
                .scaleEffect(y: 1.5)

            HStack {
                let _ = timerTick
                timeLabel(icon: "clock", label: "Elapsed", value: vm.elapsedString)
                Spacer()
                timeLabel(icon: "hourglass", label: "ETA", value: vm.etaString)
                Spacer()
                timeLabel(icon: "person.2.fill", label: "Workers", value: "×\(vm.activeWorkerCount)")
                Spacer()
                timeLabel(icon: "network", label: "Network", value: vm.networkModeLabel)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(vm.statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: vm.statusColor.opacity(0.6), radius: 4)
            Text(vm.statusLabel)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(vm.statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(vm.statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private func timeLabel(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(CommandTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? vm.siteColor.opacity(0.2) : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var overviewContent: some View {
        statsSection
        controlSection
        concurrencyAdjuster

        if vm.hasFailureStreak {
            failureStreakBanner
        }
    }

    @ViewBuilder
    private var sessionsContent: some View {
        activeSessionsSection
    }

    @ViewBuilder
    private var resultsContent: some View {
        recentResultsSection
        recentFailuresSection
    }

    private var statsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                statCard(value: vm.workingCount, label: "Working", color: .green, icon: "checkmark.circle.fill")
                statCard(value: vm.noAccCount, label: "No Acc", color: .red, icon: "xmark.circle.fill")
            }
            HStack(spacing: 8) {
                statCard(value: vm.tempDisCount, label: "Temp Dis", color: .orange, icon: "clock.badge.exclamationmark")
                statCard(value: vm.permDisCount, label: "Perm Dis", color: .purple, icon: "lock.fill")
            }
        }
    }

    private func statCard(value: Int, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var controlSection: some View {
        HStack(spacing: 10) {
            if vm.isPaused {
                controlActionButton(icon: "play.fill", label: "Resume", color: .green) {
                    vm.resumeQueue()
                }
            } else {
                controlActionButton(icon: "pause.fill", label: "Pause", color: .orange) {
                    vm.pauseQueue()
                }
            }

            controlActionButton(icon: "stop.fill", label: "Stop", color: .red) {
                vm.stopQueue()
            }

            controlActionButton(icon: "arrow.uturn.right", label: "Jump To", color: vm.siteColor) {
                vm.showFullSheet = false
                vm.navigateToActiveMode()
            }
        }
    }

    private func controlActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(label)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: vm.isPaused)
    }

    private var concurrencyAdjuster: some View {
        HStack(spacing: 12) {
            Text("CONCURRENCY")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()

            Button {
                if vm.maxConcurrency > 1 { vm.maxConcurrency -= 1 }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Text("\(vm.maxConcurrency)")
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .frame(minWidth: 30)
                .contentTransition(.numericText())

            Button {
                if vm.maxConcurrency < 12 { vm.maxConcurrency += 1 }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var failureStreakBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)
            Text(vm.failureStreakMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.yellow.opacity(0.9))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var activeSessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "bolt.fill", title: "ACTIVE SESSIONS (\(vm.activeSessionItems.count))")

            if vm.activeSessionItems.isEmpty {
                emptyState(text: "No active sessions")
            } else {
                ForEach(vm.activeSessionItems) { item in
                    ActiveSessionRowView(item: item)
                }
            }
        }
    }

    private var recentResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "list.bullet.rectangle", title: "RECENT RESULTS (\(vm.recentResults.count))")

            if vm.recentResults.isEmpty {
                emptyState(text: "No results yet")
            } else {
                ForEach(vm.recentResults) { result in
                    resultRow(result)
                }
            }
        }
    }

    private var recentFailuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "exclamationmark.triangle.fill", title: "FAILURES (\(vm.recentFailures.count))")

            if vm.recentFailures.isEmpty {
                emptyState(text: "No failures yet")
            } else {
                ForEach(vm.recentFailures) { failure in
                    failureRow(failure)
                }
            }
        }
    }

    private func resultRow(_ item: RecentResultItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(item.isSuccess ? .green : .red.opacity(0.7))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.reason)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            Text(item.resultStatus)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(resultStatusColor(item.resultStatus))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(resultStatusColor(item.resultStatus).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(item.isSuccess ? Color.green.opacity(0.04) : Color.white.opacity(0.03))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func failureRow(_ item: RecentFailureItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.red.opacity(0.7))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.reason)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            Text(item.resultStatus)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(resultStatusColor(item.resultStatus))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(resultStatusColor(item.resultStatus).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.04))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func resultStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "working": .green
        case "no acc": .red
        case "temp disabled": .orange
        case "perm disabled": .purple
        case "unsure": .yellow
        case "dead": .red
        default: .gray
        }
    }

    private func emptyState(text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
        }
        .padding(.vertical, 16)
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(vm.siteColor.opacity(0.7))
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func rateColor(_ rate: Double) -> Color {
        if rate >= 0.5 { return .green }
        if rate >= 0.2 { return .yellow }
        return .red
    }
}
