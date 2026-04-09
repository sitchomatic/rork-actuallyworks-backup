import SwiftUI

@Observable
final class GrokAIStatusViewModel {
    var isTestingText: Bool = false
    var isTestingVision: Bool = false
    var textTestResult: RorkToolkitService.GrokConnectionTestResult?
    var visionTestResult: RorkToolkitService.GrokConnectionTestResult?

    func runConnectionTest() async {
        isTestingText = true
        textTestResult = nil
        let result = await RorkToolkitService.shared.testConnection()
        textTestResult = result
        isTestingText = false
    }

    func runVisionTest() async {
        isTestingVision = true
        visionTestResult = nil
        let result = await RorkToolkitService.shared.testVisionConnection()
        visionTestResult = result
        isTestingVision = false
    }
}

struct GrokAIStatusView: View {
    @State private var vm = GrokAIStatusViewModel()

    private var stats: GrokUsageStats { GrokUsageStats.shared }
    private var isConfigured: Bool { GrokAISetup.isConfigured }

    var body: some View {
        List {
            statusSection
            usageSection
            modelsSection
            testSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Grok AI Status")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isConfigured ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: isConfigured ? "brain.head.profile.fill" : "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(isConfigured ? .green : .red)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(isConfigured ? "Grok AI Active" : "Grok AI Not Configured")
                        .font(.headline)
                    Text(isConfigured ? "API key loaded from environment" : "EXPO_PUBLIC_GROK_API_KEY not set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 4)

            if isConfigured {
                statusPill(label: "Primary Engine", value: "Grok API", color: .green)
                statusPill(label: "Screenshot Vision", value: GrokModel.vision.rawValue, color: .blue)
                statusPill(label: "Fallback Engine", value: "Apple Intelligence / Heuristic", color: .orange)
                if let visionStatus = stats.lastVisionSuccess {
                    statusPill(
                        label: "Last Vision Call",
                        value: visionStatus ? "Success" : "Failed",
                        color: visionStatus ? .green : .red
                    )
                    if let visionError = stats.lastVisionError, !visionError.isEmpty, visionStatus == false {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("Vision error: \(visionError)")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(3)
                        }
                        .padding(.top, 2)
                    }
                }
            } else {
                statusPill(label: "Active Engine", value: "Heuristic Only", color: .orange)
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("Set EXPO_PUBLIC_GROK_API_KEY in environment variables to enable Grok AI.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Connection Status", systemImage: "antenna.radiowaves.left.and.right")
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        Section {
            usageRow(icon: "arrow.up.circle.fill", label: "Total API Calls", value: "\(stats.totalCalls)", color: .blue)
            usageRow(icon: "checkmark.circle.fill", label: "Successful Calls", value: "\(stats.successfulCalls)", color: .green)
            usageRow(icon: "xmark.circle.fill", label: "Failed Calls", value: "\(stats.failedCalls)", color: .red)
            usageRow(
                icon: "percent",
                label: "Success Rate",
                value: stats.totalCalls > 0 ? "\(Int(stats.successRate * 100))%" : "—",
                color: stats.successRate > 0.8 ? Color.green : stats.successRate > 0.5 ? Color.orange : Color.red
            )
            usageRow(icon: "textformat.characters", label: "Tokens Used", value: stats.totalTokensUsed > 0 ? "\(stats.totalTokensUsed.formatted())" : "—", color: .purple)

            if let lastCall = stats.lastCallTime {
                usageRow(icon: "clock.fill", label: "Last Call", value: lastCall.formatted(.relative(presentation: .named)), color: .secondary)
            }

            if let lastError = stats.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text("Last error: \(lastError)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                }
                .padding(.vertical, 2)
            }

            Button(role: .destructive) {
                GrokUsageStats.shared.reset()
            } label: {
                Label("Reset Stats", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        } header: {
            Label("Usage Statistics", systemImage: "chart.bar.fill")
        }
    }

    // MARK: - Models Section

    private var modelsSection: some View {
        Section {
            modelRow(
                name: GrokModel.standard.rawValue,
                usage: "Login analysis, PPSR decisions, flow prediction",
                icon: "bolt.fill",
                color: .yellow
            )
            modelRow(
                name: GrokModel.mini.rawValue,
                usage: "OCR field mapping, email variants, lightweight tasks",
                icon: "hare.fill",
                color: .mint
            )
            modelRow(
                name: GrokModel.vision.rawValue,
                usage: "Screenshot analysis — login results, payment outcomes",
                icon: "eye.fill",
                color: .indigo
            )
            modelRow(
                name: "Apple Intelligence (iOS 26+)",
                usage: "On-device fallback when Grok API unavailable",
                icon: "apple.logo",
                color: .gray
            )
        } header: {
            Label("AI Model Stack", systemImage: "square.stack.3d.up.fill")
        } footer: {
            Text("Grok Vision is the primary analysis engine. Apple Intelligence and heuristics activate as fallbacks when needed.")
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        Section {
            testButton(
                label: "Test Text Model",
                systemImage: "network.badge.shield.half.filled",
                isLoading: vm.isTestingText
            ) {
                await vm.runConnectionTest()
            }

            if let textResult = vm.textTestResult {
                testResultView(title: "Text connectivity", result: textResult)
            }

            testButton(
                label: "Test Vision",
                systemImage: "eye.trianglebadge.exclamationmark.fill",
                isLoading: vm.isTestingVision
            ) {
                await vm.runVisionTest()
            }

            if let visionResult = vm.visionTestResult {
                testResultView(title: "Vision connectivity", result: visionResult)
            }
        } header: {
            Label("Connection Test", systemImage: "wifi")
        } footer: {
            Text("Runs lightweight text and vision pings to verify Grok connectivity. Shows exact errors for quick debugging.")
        }
    }

    // MARK: - Helpers

    private func statusPill(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func usageRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private func testButton(
        label: String,
        systemImage: String,
        isLoading: Bool,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Label(label, systemImage: systemImage)
                    .font(.subheadline.bold())
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .disabled(isLoading || !isConfigured)
    }

    private func testResultView(title: String, result: RorkToolkitService.GrokConnectionTestResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.success ? .green : .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(result.success ? "Connected in \(result.latencyMs) ms via \(result.model)" : failureText(for: result))
                        .font(.subheadline)
                        .foregroundStyle(result.success ? Color.primary : Color.red)
                        .multilineTextAlignment(.leading)
                }
            }
            if let code = result.statusCode, code > 0 {
                Text("HTTP \(code)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let error = result.error, !result.success {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 4)
    }

    private func failureText(for result: RorkToolkitService.GrokConnectionTestResult) -> String {
        let code: String
        if let status = result.statusCode, status > 0 {
            code = " (HTTP \(status))"
        } else {
            code = ""
        }
        return "Failed\(code) in \(result.latencyMs) ms"
    }

    private func modelRow(name: String, usage: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.bold())
                Text(usage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
