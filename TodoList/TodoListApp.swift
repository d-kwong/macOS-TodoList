import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct SimpleTodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Native modifier that forces the exact initial window size on fresh compilation launches
        .defaultSize(width: 600, height: 500)
        .restorationBehavior(.disabled)
        .windowResizability(.automatic)
    }
}
