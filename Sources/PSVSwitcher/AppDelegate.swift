import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var manager: EventTapManager?
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        manager = EventTapManager()
        manager?.start()
        if let m = manager {
            statusBar = StatusBarController(manager: m)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
    }
}