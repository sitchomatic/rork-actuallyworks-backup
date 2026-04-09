import SwiftUI

nonisolated enum DevSectionID: String, CaseIterable, Hashable, Sendable, Identifiable {
    case detection = "detection"
    case typingInput = "typingInput"
    case submitClick = "submitClick"
    case resultEval = "resultEval"
    case delays = "delays"
    case retryRecovery = "retryRecovery"
    case securityChallenges = "securityChallenges"
    case fingerprinting = "fingerprinting"
    case sessionCookies = "sessionCookies"
    case concurrency = "concurrency"
    case networkProxy = "networkProxy"
    case urlManagement = "urlManagement"
    case screenshots = "screenshots"
    case blacklist = "blacklist"
    case aiTelemetry = "aiTelemetry"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .detection: "Detection & Selectors"
        case .typingInput: "Typing & Input"
        case .submitClick: "Submit & Click"
        case .resultEval: "Result Evaluation"
        case .delays: "All Delays"
        case .retryRecovery: "Retry & Recovery"
        case .securityChallenges: "Security Challenges"
        case .fingerprinting: "Fingerprinting & Stealth"
        case .sessionCookies: "Session & Cookies"
        case .concurrency: "Concurrency"
        case .networkProxy: "Network & Proxy"
        case .urlManagement: "URL Management"
        case .screenshots: "Screenshots & Debug"
        case .blacklist: "Blacklist & Auto-Actions"
        case .aiTelemetry: "AI, Viewport & Telemetry"
        }
    }

    var icon: String {
        switch self {
        case .detection: "target"
        case .typingInput: "keyboard.fill"
        case .submitClick: "hand.tap.fill"
        case .resultEval: "checkmark.diamond.fill"
        case .delays: "timer"
        case .retryRecovery: "arrow.clockwise"
        case .securityChallenges: "lock.shield.fill"
        case .fingerprinting: "eye.slash.fill"
        case .sessionCookies: "rectangle.stack.fill"
        case .concurrency: "cpu.fill"
        case .networkProxy: "network"
        case .urlManagement: "arrow.triangle.2.circlepath"
        case .screenshots: "camera.fill"
        case .blacklist: "xmark.shield.fill"
        case .aiTelemetry: "brain.fill"
        }
    }

    var color: Color {
        switch self {
        case .detection: .red
        case .typingInput: .indigo
        case .submitClick: .teal
        case .resultEval: .green
        case .delays: .yellow
        case .retryRecovery: .orange
        case .securityChallenges: .purple
        case .fingerprinting: .pink
        case .sessionCookies: .gray
        case .concurrency: .blue
        case .networkProxy: .cyan
        case .urlManagement: .mint
        case .screenshots: .pink
        case .blacklist: .red
        case .aiTelemetry: .green
        }
    }

    var category: DevCategory {
        switch self {
        case .detection, .typingInput, .submitClick, .resultEval: .coreEngine
        case .delays: .timing
        case .retryRecovery, .securityChallenges: .recovery
        case .fingerprinting, .sessionCookies: .stealth
        case .concurrency, .networkProxy, .urlManagement, .screenshots, .blacklist, .aiTelemetry: .performance
        }
    }

    var settingCount: Int {
        switch self {
        case .detection: 26
        case .typingInput: 24
        case .submitClick: 25
        case .resultEval: 13
        case .delays: 24
        case .retryRecovery: 19
        case .securityChallenges: 18
        case .fingerprinting: 11
        case .sessionCookies: 14
        case .concurrency: 6
        case .networkProxy: 5
        case .urlManagement: 5
        case .screenshots: 11
        case .blacklist: 3
        case .aiTelemetry: 8
        }
    }
}

nonisolated enum DevCategory: String, CaseIterable, Sendable {
    case coreEngine = "Core Engine"
    case timing = "Timing"
    case recovery = "Recovery"
    case stealth = "Stealth"
    case performance = "Performance & Debug"

    var icon: String {
        switch self {
        case .coreEngine: "gearshape.2.fill"
        case .timing: "clock.fill"
        case .recovery: "arrow.trianglehead.counterclockwise.rotate.90"
        case .stealth: "eye.slash.circle.fill"
        case .performance: "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .coreEngine: .red
        case .timing: .yellow
        case .recovery: .orange
        case .stealth: .purple
        case .performance: .blue
        }
    }

    var sections: [DevSectionID] {
        DevSectionID.allCases.filter { $0.category == self }
    }

    var subtitle: String {
        switch self {
        case .coreEngine: "How automation detects, types, clicks & evaluates"
        case .timing: "Every delay and wait duration"
        case .recovery: "Retry logic, fallbacks & challenge handling"
        case .stealth: "Fingerprinting, spoofing & session isolation"
        case .performance: "Concurrency, network, screenshots & telemetry"
        }
    }
}

struct DeveloperSettingsView: View {
    @State private var settings: AutomationSettings = AutomationSettingsPersistence.shared.load()
    @State private var showResetConfirm: Bool = false
    @State private var savedToast: Bool = false
    @State private var searchText: String = ""
    @State private var navPath = NavigationPath()

    private var filteredCategories: [DevCategory] {
        guard !searchText.isEmpty else { return DevCategory.allCases }
        return DevCategory.allCases.filter { cat in
            cat.sections.contains { sec in
                sec.title.localizedStandardContains(searchText) || sec.rawValue.localizedStandardContains(searchText)
            }
        }
    }

    private func filteredSections(for category: DevCategory) -> [DevSectionID] {
        guard !searchText.isEmpty else { return category.sections }
        return category.sections.filter { sec in
            sec.title.localizedStandardContains(searchText) || sec.rawValue.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        List {
            statusHeader

            ForEach(filteredCategories, id: \.self) { category in
                Section {
                    ForEach(filteredSections(for: category), id: \.self) { section in
                        NavigationLink(value: section) {
                            sectionRow(section)
                        }
                    }
                } header: {
                    categoryHeader(category)
                }
            }

            resetSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Developer Settings")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search settings...")
        .navigationDestination(for: DevSectionID.self) { section in
            destinationView(for: section)
        }
        .alert("Reset All Settings?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                AutomationSettingsPersistence.shared.reset()
                settings = AutomationSettings().normalizedTimeouts()
                let normalized = settings.normalizedTimeouts()
                UnifiedSessionViewModel.shared.automationSettings = normalized
                DualFindViewModel.shared.automationSettings = normalized
                LoginViewModel.shared.automationSettings = normalized
                withAnimation(.spring(duration: 0.3)) { savedToast = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { savedToast = false }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all automation settings to their defaults.")
        }
        .overlay(alignment: .top) {
            if savedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Settings Reset")
                }
                .font(.subheadline.bold()).foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.green.gradient, in: Capsule())
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
    }

    private var statusHeader: some View {
        Section {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("Automation Engine")
                            .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    }
                    let total = DevSectionID.allCases.reduce(0) { $0 + $1.settingCount }
                    Text("\(total) settings across \(DevSectionID.allCases.count) sections")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("5 categories")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Text("180s timeout floor")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        } footer: {
            Text("Tap a section to view and edit. Changes saved per-section.")
        }
    }

    private func categoryHeader(_ category: DevCategory) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(category.color)
            Text(category.rawValue.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(category.color)
            Spacer()
            Text("\(category.sections.count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(category.color.opacity(0.7))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(category.color.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func sectionRow(_ section: DevSectionID) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(section.color.gradient)
                    .frame(width: 30, height: 30)
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.subheadline.weight(.medium))
                Text("\(section.settingCount) settings")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) { showResetConfirm = true } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset All Settings to Defaults")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for section: DevSectionID) -> some View {
        switch section {
        case .detection: DevDetectionSection(settings: $settings)
        case .typingInput: DevTypingInputSection(settings: $settings)
        case .submitClick: DevSubmitClickSection(settings: $settings)
        case .resultEval: DevResultEvalSection(settings: $settings)
        case .delays: DevAllDelaysSection(settings: $settings)
        case .retryRecovery: DevRetryRecoverySection(settings: $settings)
        case .securityChallenges: DevSecurityChallengesSection(settings: $settings)
        case .fingerprinting: DevFingerprintingSection(settings: $settings)
        case .sessionCookies: DevSessionCookiesSection(settings: $settings)
        case .concurrency: DevConcurrencySection(settings: $settings)
        case .networkProxy: DevNetworkSection(settings: $settings)
        case .urlManagement: DevURLSection(settings: $settings)
        case .screenshots: DevScreenshotSection(settings: $settings)
        case .blacklist: DevBlacklistSection(settings: $settings)
        case .aiTelemetry: DevAITelemetrySection(settings: $settings)
        }
    }
}
