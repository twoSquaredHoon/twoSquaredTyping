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
            CommandMenu("Desktop") {
                Toggle(
                    "Pass clicks through",
                    isOn: Binding(
                        get: { appModel.clickThrough },
                        set: { appModel.clickThrough = $0 }
                    )
                )
                .keyboardShortcut("t", modifiers: [.command, .option])
            }
        }
    }
}
