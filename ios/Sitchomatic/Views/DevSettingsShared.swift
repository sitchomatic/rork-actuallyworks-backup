import SwiftUI

struct DevSettingsEnvironmentKey: EnvironmentKey {
    static let defaultValue: Binding<AutomationSettings>? = nil
}

extension EnvironmentValues {
    var devSettings: Binding<AutomationSettings>? {
        get { self[DevSettingsEnvironmentKey.self] }
        set { self[DevSettingsEnvironmentKey.self] = newValue }
    }
}

struct DevSectionPage<Content: View>: View {
    let title: String
    @Binding var settings: AutomationSettings
    let content: Content
    @State private var savedToast: Bool = false

    init(_ title: String, settings: Binding<AutomationSettings>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._settings = settings
        self.content = content()
    }

    var body: some View {
        List {
            content
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .overlay(alignment: .top) { toastOverlay }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { save() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Save")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.blue.gradient, in: .rect(cornerRadius: 12))
            }
            .sensoryFeedback(.success, trigger: savedToast)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var toastOverlay: some View {
        Group {
            if savedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Settings Saved")
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

    private func save() {
        let persistence = AutomationSettingsPersistence.shared
        persistence.save(settings)
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
}

func devToggle(_ label: String, _ binding: Binding<Bool>) -> some View {
    Toggle(label, isOn: binding).font(.subheadline).tint(.blue)
}

func devInt(_ label: String, _ binding: Binding<Int>) -> some View {
    HStack {
        Text(label).font(.subheadline).lineLimit(1).minimumScaleFactor(0.7)
        Spacer()
        TextField("", value: binding, format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(.blue)
    }
}

func devDouble(_ label: String, _ binding: Binding<Double>) -> some View {
    HStack {
        Text(label).font(.subheadline).lineLimit(1).minimumScaleFactor(0.7)
        Spacer()
        TextField("", value: binding, format: .number.precision(.fractionLength(0...3)))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(.blue)
    }
}

func devString(_ label: String, _ binding: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label).font(.subheadline)
        TextField(label, text: binding)
            .font(.system(.caption, design: .monospaced))
            .textFieldStyle(.roundedBorder)
    }
}

func devStringArray(_ label: String, _ binding: Binding<[String]>) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label).font(.subheadline)
        Text(binding.wrappedValue.joined(separator: ", "))
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(3)
        TextField("Edit (comma-separated)", text: Binding(
            get: { binding.wrappedValue.joined(separator: ", ") },
            set: { newVal in
                binding.wrappedValue = newVal
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        ))
        .font(.system(.caption, design: .monospaced))
        .textFieldStyle(.roundedBorder)
    }
}

func devValidationWarning(_ message: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.caption2)
        Text(message).font(.caption2).foregroundStyle(.red)
    }
}

func devInfoNote(_ text: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: "info.circle").foregroundStyle(.blue).font(.caption2)
        Text(text).font(.caption2).foregroundStyle(.secondary)
    }
}
