import ActivityKit
import SwiftUI
import WidgetKit

struct CommandCenterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CommandCenterActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                compactLeading(context: context)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimal(context: context)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<CommandCenterActivityAttributes>) -> some View {
        let state = context.state
        let progress = state.totalCount > 0 ? Double(state.completedCount) / Double(state.totalCount) : 0

        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: siteIcon(context.attributes.siteMode))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(siteColor(context.attributes.siteMode))
                    Text(context.attributes.siteLabel)
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                statusBadge(state: state)
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text("\(state.completedCount)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("/ \(state.totalCount)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer()

                if state.speedPerMinute > 0 {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(String(format: "%.1f", state.speedPerMinute))
                            .font(.system(size: 16, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("/MIN")
                            .font(.system(size: 7, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }

            ProgressView(value: progress)
                .tint(siteColor(context.attributes.siteMode))
                .scaleEffect(y: 1.5)

            HStack(spacing: 0) {
                statPill(value: "\(state.workingCount)", label: "HIT", color: .green, icon: "checkmark.circle.fill")
                Spacer()
                statPill(value: "\(state.noAccCount)", label: "NA", color: .red, icon: "xmark.circle.fill")
                Spacer()
                statPill(value: "\(state.tempDisCount)", label: "TD", color: .orange, icon: "clock.badge.exclamationmark")
                Spacer()
                statPill(value: "\(state.permDisCount)", label: "PD", color: .purple, icon: "lock.fill")
                Spacer()
                statPill(value: formatElapsed(state.elapsedSeconds), label: "TIME", color: .white.opacity(0.7), icon: "clock")
                Spacer()
                statPill(value: "\(Int(state.successRate * 100))%", label: "RATE", color: rateColor(state.successRate), icon: "chart.line.uptrend.xyaxis")
            }

            if !state.currentCredential.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(state.currentCredential)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 8))
                        Text("×\(state.activeWorkers)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.9))
    }

    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<CommandCenterActivityAttributes>) -> some View {
        HStack(spacing: 4) {
            Image(systemName: siteIcon(context.attributes.siteMode))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(siteColor(context.attributes.siteMode))
            Text(context.attributes.siteLabel)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<CommandCenterActivityAttributes>) -> some View {
        statusBadge(state: context.state)
    }

    @ViewBuilder
    private func expandedCenter(context: ActivityViewContext<CommandCenterActivityAttributes>) -> some View {
        let state = context.state
        let progress = state.totalCount > 0 ? Double(state.completedCount) / Double(state.totalCount) : 0

        VStack(spacing: 4) {
            HStack {
                Text("\(state.completedCount) / \(state.totalCount)")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                if state.speedPerMinute > 0 {
                    Text(String(format: "%.1f/m", state.speedPerMinute))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(formatElapsed(state.elapsedSeconds))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            ProgressView(value: progress)
                .tint(siteColor(context.attributes.siteMode))
        }
    }

    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<CommandCenterActivityAttributes>) -> some View {
        let state = context.state
        HStack(spacing: 10) {
            expandedStat(icon: "checkmark.circle.fill", value: "\(state.workingCount)", color: .green)
            expandedStat(icon: "xmark.circle.fill", value: "\(state.noAccCount + state.failedCount)", color: .red)
            expandedStat(icon: "clock.badge.exclamationmark", value: "\(state.tempDisCount)", color: .orange)
            expandedStat(icon: "lock.fill", value: "\(state.permDisCount)", color: .purple)
            expandedStat(icon: "chart.line.uptrend.xyaxis", value: "\(Int(state.successRate * 100))%", color: rateColor(state.successRate))
        }
    }

    @ViewBuilder
    private func compactLeading(context: ActivityViewContext<CommandCenterActivityAttributes>) -> some View {
        HStack(spacing: 3) {
            statusDot(state: context.state)
            Image(systemName: siteIcon(context.attributes.siteMode))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(siteColor(context.attributes.siteMode))
        }
    }

    @ViewBuilder
    private func compactTrailing(context: ActivityViewContext<CommandCenterActivityAttributes>) -> some View {
        HStack(spacing: 2) {
            Text("\(context.state.completedCount)/\(context.state.totalCount)")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
            if context.state.workingCount > 0 {
                Text("✓\(context.state.workingCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private func minimal(context: ActivityViewContext<CommandCenterActivityAttributes>) -> some View {
        ZStack {
            let progress = context.state.totalCount > 0
                ? Double(context.state.completedCount) / Double(context.state.totalCount)
                : 0

            Circle()
                .trim(from: 0, to: progress)
                .stroke(siteColor(context.attributes.siteMode), lineWidth: 2.5)
                .rotationEffect(.degrees(-90))

            Image(systemName: siteIcon(context.attributes.siteMode))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(siteColor(context.attributes.siteMode))
        }
    }

    private func statusBadge(state: CommandCenterActivityAttributes.ContentState) -> some View {
        HStack(spacing: 3) {
            statusDot(state: state)
            Text(state.statusLabel)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(statusColor(state: state))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(statusColor(state: state).opacity(0.15))
        .clipShape(Capsule())
    }

    private func statusDot(state: CommandCenterActivityAttributes.ContentState) -> some View {
        Circle()
            .fill(statusColor(state: state))
            .frame(width: 6, height: 6)
    }

    private func statusColor(state: CommandCenterActivityAttributes.ContentState) -> Color {
        if state.isStopping { return .red }
        if state.isPaused { return .orange }
        return .green
    }

    private func statPill(value: String, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private func expandedStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func siteIcon(_ mode: String) -> String {
        switch mode {
        case "joe": "suit.spade.fill"
        case "ignition": "flame.fill"
        case "ppsr": "bolt.shield.fill"
        case "double": "arrow.triangle.branch"
        default: "circle"
        }
    }

    private func siteColor(_ mode: String) -> Color {
        switch mode {
        case "joe": .green
        case "ignition": .orange
        case "ppsr": .teal
        case "double": .cyan
        default: .secondary
        }
    }

    private func rateColor(_ rate: Double) -> Color {
        if rate >= 0.5 { return .green }
        if rate >= 0.2 { return .yellow }
        return .red
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
