import AppKit

/// Plain SwiftUI WindowGroup apps aren't reliably reopened by clicking the
/// Dock icon once the last window is fully closed (as opposed to merely
/// miniaturized) — observed as "closed the window, clicking the Dock icon
/// does nothing". This delegate re-triggers window creation via the
/// captured `openWindow` action (see ContentView) whenever the app is
/// reactivated with no visible windows.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
            if sender.windows.isEmpty {
                WindowOpener.shared.action?()
            }
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
}

/// Holds the SwiftUI `openWindow` action so it can be called from outside
/// a View (the AppDelegate above), which has no environment of its own.
final class WindowOpener {
    static let shared = WindowOpener()
    var action: (() -> Void)?
}
