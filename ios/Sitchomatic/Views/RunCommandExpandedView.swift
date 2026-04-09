import SwiftUI
import Combine

struct RunCommandExpandedView: View {
    @State private var vm = RunCommandViewModel.shared
    @State private var timerTick: Int = 0
    @State private var showSpeedPulse: Bool = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            progressSection
            statsGrid
            timeRow

            if vm.hasFailureStreak {
                failureAlert
            }

            controlRow
            expandButton
        }
        .padding(12)
        .frame(width: 250)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.35))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(vm.siteColor.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .onReceive(timer) { _ in timerTick += 1 }
        .onChange(of: vm.workingCount) { _, _ in
            withAnimation(.spring(duration: 0.3)) { showSpeedPulse = true }
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation { showSpeedPulse = false }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: vm.siteIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(vm.siteColor)
            Text(vm.siteLabel)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(vm.statusColor)
                .frame(width: 5, height: 5)
            Text(vm.statusLabel)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(vm.statusColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(vm.statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var progressSection: some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom) {
                Text("\(vm.completedCount)")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("/ \(vm.totalCount)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                if vm.speedPerMinute > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text(vm.speedPerMinuteFormatted)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    }
                    .foregroundStyle(.cyan.opacity(showSpeedPulse ? 1.0 : 0.6))
                }
            }

            ProgressView(value: vm.progress)
                .tint(vm.siteColor)
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 0) {
            statCell(value: "\(vm.workingCount)", label: "HIT", color: .green)
            Spacer()
            statCell(value: "\(vm.noAccCount)", label: "NA", color: .red)
            Spacer()
            statCell(value: "\(vm.tempDisCount)", label: "TD", color: .orange)
            Spacer()
            statCell(value: "\(vm.permDisCount)", label: "PD", color: .purple)
        }
    }

    private var timeRow: some View {
        HStack(spacing: 0) {
            let _ = timerTick
            statCell(value: vm.elapsedString, label: "TIME", color: .white)
            Spacer()
            statCell(value: vm.etaString, label: "ETA", color: .white.opacity(0.7))
            Spacer()
            statCell(value: "\(Int(vm.successRate * 100))%", label: "RATE", color: rateColor)
            Spacer()
            statCell(value: "×\(vm.activeWorkerCount)", label: "LIVE", color: .cyan)
        }
    }

    private var rateColor: Color {
        if vm.successRate >= 0.5 { return .green }
        if vm.successRate >= 0.2 { return .yellow }
        return .red
    }

    private var failureAlert: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.yellow)
            Text(vm.failureStreakMessage)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.yellow.opacity(0.9))
                .lineLimit(2)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.08))
        .clipShape(.rect(cornerRadius: 6))
    }

    private var controlRow: some View {
        HStack(spacing: 8) {
            if vm.isPaused {
                controlButton(icon: "play.fill", label: "RESUME", color: .green) {
                    vm.resumeQueue()
                }
            } else {
                controlButton(icon: "pause.fill", label: "PAUSE", color: .orange) {
                    vm.pauseQueue()
                }
            }

            controlButton(icon: "stop.fill", label: "STOP", color: .red) {
                vm.stopQueue()
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: vm.isPaused)
    }

    private func controlButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                Text(label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var expandButton: some View {
        Button {
            vm.isExpanded = false
            vm.showFullSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.expand.vertical")
                    .font(.system(size: 9, weight: .bold))
                Text("COMMAND CENTER")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
            }
            .foregroundStyle(vm.siteColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(vm.siteColor.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}
