import AppKit
import ApplicationServices
import CoreGraphics

final class EventTapManager {
    static func appendLog(_ msg: String) {
        let line = "\(Date()): \(msg)\n"
        if let data = line.data(using: .utf8) {
            let url = URL(fileURLWithPath: "/tmp/psvswitcher.log")
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
    static let syntheticSource: CGEventSource = {
        let s = CGEventSource(stateID: .privateState)!
        s.userData = 0x50535756 // marker "PSV"
        return s
    }()

    private static let syntheticMarker: Int64 = 0x50535756

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let buffer = BufferManager()
    private var lastCapsTime: TimeInterval = 0
    private var isEnabled: Bool = true
    private var isPosting: Bool = false

    private var tapRetryScheduled: Bool = false

    func start() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        if !trusted {
            NSLog("PSVSwitcher: Accessibility not granted")
            EventTapManager.appendLog("Accessibility not granted")
        } else {
            EventTapManager.appendLog("Accessibility granted")
        }

        attemptCreateTap()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.buffer.reset()
        }
    }

    private func attemptCreateTap() {
        guard eventTap == nil else { return }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        // Try HID-level tap first so Caps Lock can be suppressed before the system toggles it.
        var tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        if tap == nil {
            NSLog("PSVSwitcher: HID tap failed, falling back to session tap")
            EventTapManager.appendLog("HID tap failed, falling back to session tap")
            tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: eventTapCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        } else {
            NSLog("PSVSwitcher: HID event tap created")
            EventTapManager.appendLog("HID event tap created")
        }
        guard let createdTap = tap else {
            NSLog("PSVSwitcher: failed to create event tap (grant Accessibility)")
            EventTapManager.appendLog("failed to create event tap (grant Accessibility)")
            scheduleTapRetry()
            return
        }
        self.eventTap = createdTap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)
        self.runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: createdTap, enable: true)
        EventTapManager.appendLog("Event tap created successfully")
    }

    private func scheduleTapRetry() {
        guard !tapRetryScheduled else { return }
        tapRetryScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.tapRetryScheduled = false
            self?.attemptCreateTap()
        }
    }

    func setEnabled(_ value: Bool) { isEnabled = value }

    // MARK: - Event handling
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // re-enable if disabled by system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // ignore our own synthetic events
        if isPosting || isSynthetic(event) {
            return Unmanaged.passUnretained(event)
        }

        // mouse click -> reset buffer
        if type == .leftMouseDown || type == .rightMouseDown {
            buffer.reset()
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 57 { // Caps Lock
                EventTapManager.appendLog("Caps Lock flagsChanged received")
                if isEnabled {
                    let now = CACurrentMediaTime()
                    if now - lastCapsTime > 0.3 {
                        lastCapsTime = now
                        DispatchQueue.main.async { [weak self] in
                            self?.convertOnCapsLock()
                        }
                    }
                }
                return nil // suppress Caps Lock (no caps-lock mode, layout switched manually)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        if !isEnabled {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // reset on navigation/editing keys
        // backspace(51) handled separately; others reset
        if keyCode == 51 {
            buffer.backspace()
            return Unmanaged.passUnretained(event)
        }

        if [123,124,125,126,115,119,116,121,117,53].contains(keyCode) {
            buffer.reset()
            return Unmanaged.passUnretained(event)
        }

        // get unicode
        var length = 0
        var buf = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &buf)
        if length == 0 {
            return Unmanaged.passUnretained(event)
        }
        let str = String(utf16CodeUnits: buf, count: length)

        // Enter / Tab / Space
        if str == "\r" || str == "\n" {
            buffer.append("\n")
            return Unmanaged.passUnretained(event)
        }
        if str == "\t" {
            buffer.append("\t")
            return Unmanaged.passUnretained(event)
        }
        if str == " " {
            buffer.append(" ")
            return Unmanaged.passUnretained(event)
        }

        // ignore control chars
        if str.unicodeScalars.contains(where: { $0.value < 0x20 }) {
            return Unmanaged.passUnretained(event)
        }

        buffer.append(str)
        return Unmanaged.passUnretained(event)
    }

    private static let sourceUserDataField = CGEventField(rawValue: 42)!

    private func isSynthetic(_ event: CGEvent) -> Bool {
        return event.getIntegerValueField(EventTapManager.sourceUserDataField) == EventTapManager.syntheticMarker
    }

    private func markSynthetic(_ event: CGEvent?) {
        event?.setIntegerValueField(EventTapManager.sourceUserDataField, value: EventTapManager.syntheticMarker)
    }

    // MARK: - Conversion
    private func convertOnCapsLock() {
        // 1. Try selected text first
        if let sel = SelectionManager.shared.selectedText(), !sel.isEmpty {
            let converted = TextConverter.convert(sel)
            isPosting = true
            let ok = SelectionManager.shared.replaceSelectedText(with: converted)
            isPosting = false
            if ok {
                buffer.clearAfterConvert()
                InputSourceManager.switchLayout()
                return
            }
        }

        // 2. Last word
        let (word, sep) = buffer.wordToConvert()
        guard !word.isEmpty else { return }
        let converted = TextConverter.convert(word)

        isPosting = true
        // delete original
        let deleteCount: Int
        if sep == nil {
            deleteCount = word.count
        } else {
            deleteCount = word.count + 1 // word + separator
        }
        pressBackspace(deleteCount)

        // type converted word
        insertText(converted)

        // restore separator if needed
        if let s = sep {
            insertText(s)
        }
        isPosting = false

        buffer.clearAfterConvert()
        InputSourceManager.switchLayout()
    }

    private func pressBackspace(_ count: Int) {
        let src = EventTapManager.syntheticSource
        for _ in 0..<count {
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0x33, keyDown: true)
            markSynthetic(down)
            down?.post(tap: .cgSessionEventTap)
            let up = CGEvent(keyboardEventSource: src, virtualKey: 0x33, keyDown: false)
            markSynthetic(up)
            up?.post(tap: .cgSessionEventTap)
        }
    }

    private func insertText(_ text: String) {
        let src = EventTapManager.syntheticSource
        for ch in text {
            var unichars = Array(String(ch).utf16)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: unichars.count, unicodeString: &unichars)
            markSynthetic(down)
            down?.post(tap: .cgSessionEventTap)
            let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            up?.keyboardSetUnicodeString(stringLength: unichars.count, unicodeString: &unichars)
            markSynthetic(up)
            up?.post(tap: .cgSessionEventTap)
        }
    }
}

private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleEvent(proxy: proxy, type: type, event: event)
}