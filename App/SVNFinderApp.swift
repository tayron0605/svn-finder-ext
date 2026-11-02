import AppKit
import SwiftUI

@main
struct SVNFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("SVN Finder 1.0")
                .padding()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        showMainWindow()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showMainWindow()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        showMainWindow()
        urls.forEach(model.handle)
    }

    private func showMainWindow() {
        if mainWindow == nil {
            let rootView = ContentView()
                .environmentObject(model)
                .frame(minWidth: 720, minHeight: 520)
            let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
            window.title = "SVN Finder"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.minSize = NSSize(width: 720, height: 520)
            window.setContentSize(NSSize(width: 900, height: 560))
            window.setFrameAutosaveName("SVNFinderMainWindow")
            window.isReleasedWhenClosed = false
            window.center()
            mainWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }
}
