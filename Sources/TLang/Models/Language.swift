import Foundation

enum Direction: String, Codable, CaseIterable {
    case enToAr
    case arToEn

    var sourceName: String { self == .enToAr ? "English" : "العربية" }
    var targetName: String { self == .enToAr ? "العربية" : "English" }

    /// English names used inside the LLM prompt.
    var sourcePromptName: String { self == .enToAr ? "English" : "Arabic" }
    var targetPromptName: String { self == .enToAr ? "Arabic" : "English" }

    var flipped: Direction { self == .enToAr ? .arToEn : .enToAr }
    var sourceIsRTL: Bool { self == .arToEn }
    var targetIsRTL: Bool { self == .enToAr }
}

enum LanguageDetector {
    /// Detects translation direction by comparing Arabic vs Latin letter counts.
    static func detect(_ text: String) -> Direction {
        var arabic = 0
        var latin = 0
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF,
                 0xFB50...0xFDFF, 0xFE70...0xFEFF:
                arabic += 1
            case 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F:
                latin += 1
            default:
                break
            }
        }
        return arabic > latin ? .arToEn : .enToAr
    }
}
