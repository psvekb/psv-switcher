import Foundation

enum TextConverter {
    // ЙЦУКЕН -> QWERTY
    static let ruToEn: [Character: Character] = [
        "й":"q","ц":"w","у":"e","к":"r","е":"t","н":"y","г":"u","ш":"i","щ":"o","з":"p","х":"[","ъ":"]",
        "ф":"a","ы":"s","в":"d","а":"f","п":"g","р":"h","о":"j","л":"k","д":"l","ж":";","э":"'","ё":"`",
        "я":"z","ч":"x","с":"c","м":"v","и":"b","т":"n","ь":"m","б":",","ю":".",".":"/",
        "Й":"Q","Ц":"W","У":"E","К":"R","Е":"T","Н":"Y","Г":"U","Ш":"I","Щ":"O","З":"P","Х":"[","Ъ":"]",
        "Ф":"A","Ы":"S","В":"D","А":"F","П":"G","Р":"H","О":"J","Л":"K","Д":"L","Ж":";","Э":"'","Ё":"`",
        "Я":"Z","Ч":"X","С":"C","М":"V","И":"B","Т":"N","Ь":"M","Б":",","Ю":".","/":"?"
    ]

    static let enToRu: [Character: Character] = {
        var d: [Character: Character] = [:]
        for (k, v) in ruToEn { d[v] = k }
        return d
    }()

    static func containsCyrillic(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
    }

    static func convert(_ word: String) -> String {
        guard !word.isEmpty else { return word }
        let dict = containsCyrillic(word) ? ruToEn : enToRu
        return String(word.map { dict[$0] ?? $0 })
    }
}