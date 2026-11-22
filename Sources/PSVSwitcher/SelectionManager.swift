import AppKit
import ApplicationServices

final class SelectionManager {
    static let shared = SelectionManager()

    private init() {}

    // Returns selected text of the focused element, if any.
    func selectedText() -> String? {
        guard let element = focusedElement() else { return nil }
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard err == .success, let str = value as? String, !str.isEmpty else { return nil }
        return str
    }

    // Tries to replace selected text. Returns true on success.
    func replaceSelectedText(with text: String) -> Bool {
        guard let element = focusedElement() else { return false }
        let err = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        if err == .success {
            return true
        }
        // Fallback via clipboard
        return replaceViaClipboard(text)
    }

    private func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let err = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard err == .success, let el = focused else { return nil }
        return (el as! AXUIElement)
    }

    // MARK: - Clipboard fallback
    private func replaceViaClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        // save current
        let savedItems = pasteboard.pasteboardItems?.map { item -> [NSPasteboard.PasteboardType: Data] in
            var d: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { d[type] = data }
            }
            return d
        }

        // copy current selection
        postKeyCombo(keyCode: 0x08, flags: .maskCommand) // Cmd+C (C=0x08)
        Thread.sleep(forTimeInterval: 0.12)
        guard let copied = pasteboard.string(forType: .string), !copied.isEmpty else {
            restorePasteboard(savedItems)
            return false
        }

        // write converted
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        postKeyCombo(keyCode: 0x09, flags: .maskCommand) // Cmd+V (V=0x09)
        Thread.sleep(forTimeInterval: 0.12)

        // restore
        restorePasteboard(savedItems)
        return true
    }

    private func restorePasteboard(_ items: [[NSPasteboard.PasteboardType: Data]]?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        guard let items = items else { return }
        for itemData in items {
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            pb.writeObjects([item])
        }
    }

    private func postKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags) {
        let src = EventTapManager.syntheticSource
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.setIntegerValueField(CGEventField(rawValue: 42)!, value: 0x50535756)
        down?.post(tap: .cgSessionEventTap)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.setIntegerValueField(CGEventField(rawValue: 42)!, value: 0x50535756)
        up?.post(tap: .cgSessionEventTap)
    }
}