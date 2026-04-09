import SwiftUI

@Observable
final class GrokAIStatusViewModel {
    var isTestingConnection: Bool = false
    var isTestingVision: Bool = false
    var testResult: String? = nil
    var testSuccess: Bool = false
    var testLatencyMs: Int = 0
    var visionTestResult: String? = nil
    var visionTestSuccess: Bool = false
    var visionTestLatencyMs: Int = 0

    func runConnectionTest() async {
        isTestingConnection = true
        testResult = nil
        let result = await RorkToolkitService.shared.testConnection()
        isTestingConnection = false
        testSuccess = result.success
        testLatencyMs = result.latencyMs
        if result.success {
            testResult = "Connected — \(result.latencyMs) ms via \(result.model)"
        } else {
            testResult = "Failed: \(result.errorDetail)"
        }
    }

    func runVisionTest() async {
        isTestingVision = true
        visionTestResult = nil
        let result = await RorkToolkitService.shared.testVisionConnection()
        isTestingVision = false
        visionTestSuccess = result.success
        visionTestLatencyMs = result.latencyMs
        if result.success {
            visionTestResult = "Vision OK — \(result.latencyMs) ms via \(result.model)"
        } else {
            visionTestResult = "Failed: \(result.errorDetail)"
        }
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
                statusPill(label: "Screenshot Vision", value: "grok-2-vision-1212", color: .blue)
                statusPill(label: "Fallback Engine", value: "Apple Intelligence / Heuristic", color: .orange)
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
                name: "grok-3",
                usage: "Login analysis, PPSR decisions, flow prediction",
                icon: "bolt.fill",
                color: .yellow
            )
            modelRow(
                name: "grok-3-mini",
                usage: "OCR field mapping, email variants, lightweight tasks",
                icon: "hare.fill",
                color: .mint
            )
            modelRow(
                name: "grok-2-vision-1212",
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
            Button {
                Task { await vm.runConnectionTest() }
            } label: {
                HStack {
                    Label("Test Connection", systemImage: "network.badge.shield.half.filled")
                        .font(.subheadline.bold())
                    Spacer()
                    if vm.isTestingConnection {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(vm.isTestingConnection || !isConfigured)

            if let result = vm.testResult {
                HStack(spacing: 8) {
                    Image(systemName: vm.testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(vm.testSuccess ? .green : .red)
                    Text(result)
                        .font(.subheadline)
                        .foregroundStyle(vm.testSuccess ? Color.primary : Color.red)
                        .lineLimit(3)
                }
            }

            Button {
                Task { await vm.runVisionTest() }
            } label: {
                HStack {
                    Label("Test Vision", systemImage: "eye.trianglebadge.exclamationmark")
                        .font(.subheadline.bold())
                    Spacer()
                    if vm.isTestingVision {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(vm.isTestingVision || !isConfigured)

            if let visionResult = vm.visionTestResult {
                HStack(spacing: 8) {
                    Image(systemName: vm.visionTestSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(vm.visionTestSuccess ? .green : .red)
                    Text(visionResult)
                        .font(.subheadline)
                        .foregroundStyle(vm.visionTestSuccess ? Color.primary : Color.red)
                        .lineLimit(3)
                }
            }

            if let visionStatus = stats.lastVisionCallSucceeded {
                HStack(spacing: 8) {
                    Image(systemName: visionStatus ? "eye.circle.fill" : "eye.slash.circle.fill")
                        .foregroundStyle(visionStatus ? .green : .orange)
                    Text(visionStatus ? "Last vision call succeeded" : "Last vision call failed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Connection Test", systemImage: "wifi")
        } footer: {
            Text("Sends minimal test requests to verify your Grok API key and vision pipeline are working.")
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
