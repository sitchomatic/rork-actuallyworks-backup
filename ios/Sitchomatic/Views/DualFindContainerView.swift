import SwiftUI

struct DualFindContainerView: View {
    @State private var vm = DualFindViewModel.shared
    @State private var showDeveloperSettings: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isRunning {
                    DualFindRunningView(vm: vm, showDeveloperSettings: $showDeveloperSettings)
                } else {
                    DualFindSetupView(
                        vm: vm,
                        onStart: { vm.startRun() },
                        onResume: { vm.resumeRun() },
                        onSettings: { showDeveloperSettings = true }
                    )
                }
            }
        }
        .withMainMenuButton()
        .preferredColorScheme(.dark)
        .tint(.purple)
        .sheet(isPresented: $showDeveloperSettings) {
            NavigationStack {
                DeveloperSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showDeveloperSettings = false }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
    }
}
