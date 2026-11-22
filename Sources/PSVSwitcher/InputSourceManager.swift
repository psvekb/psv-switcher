import Carbon
import Foundation

final class InputSourceManager {
    static func currentSourceID() -> String? {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        guard let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    static func switchLayout() {
        guard let currentID = currentSourceID() else { return }
        let targetRussian = !currentID.lowercased().contains("russian")

        guard let list = TISCreateInputSourceList(nil, true)?.takeRetainedValue() else { return }
        let count = CFArrayGetCount(list)
        for i in 0..<count {
            let raw = CFArrayGetValueAtIndex(list, i)
            let src = unsafeBitCast(raw, to: TISInputSource.self)
            guard let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { continue }
            let id = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
            let isRussian = id.lowercased().contains("russian")
            if isRussian == targetRussian {
                TISSelectInputSource(src)
                return
            }
        }
    }
}