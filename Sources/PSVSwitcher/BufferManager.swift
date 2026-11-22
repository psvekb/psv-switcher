import Foundation

final class BufferManager {
    private(set) var currentWord: String = ""
    private(set) var lastWord: String = ""
    private(set) var lastSeparator: String = " "
    private(set) var lastHadSeparator: Bool = false

    func reset() {
        currentWord = ""
        lastWord = ""
        lastSeparator = " "
        lastHadSeparator = false
    }

    func append(_ ch: String) {
        // separator handling
        if ch == " " || ch == "\n" || ch == "\t" {
            if !currentWord.isEmpty {
                lastWord = currentWord
                lastSeparator = ch
                lastHadSeparator = true
            } else {
                // consecutive separator: keep last separator updated
                lastSeparator = ch
            }
            currentWord = ""
            return
        }
        // punctuation that should stay attached to word but not reset
        currentWord += ch
    }

    func backspace() {
        if !currentWord.isEmpty {
            currentWord.removeLast()
        } else {
            // unknown state; drop last word info
            lastWord = ""
            lastHadSeparator = false
        }
    }

    // Returns the word to convert and the separator to restore (if any)
    func wordToConvert() -> (word: String, separator: String?) {
        if !currentWord.isEmpty {
            return (currentWord, nil)
        }
        if lastHadSeparator && !lastWord.isEmpty {
            return (lastWord, lastSeparator)
        }
        return ("", nil)
    }

    func clearAfterConvert() {
        currentWord = ""
        lastWord = ""
        lastHadSeparator = false
        lastSeparator = " "
    }
}