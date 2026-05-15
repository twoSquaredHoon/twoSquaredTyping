import SwiftUI

@main
struct DesktopGifApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open…") {
                    appModel.openGIF()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Typing") {
                Button("Refresh typing detection") {
                    appModel.refreshTypingMonitors()
                }
                Button("Open Input Monitoring settings…") {
                    appModel.openInputMonitoringPrivacySettings()
                }
            }
        }
    }
}
