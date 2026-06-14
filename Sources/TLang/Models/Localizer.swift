import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case arabic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Auto"
        case .english: return "English"
        case .arabic: return "العربية"
        }
    }
}

/// Resolved UI language (after applying System → device preference).
enum ResolvedLanguage {
    case english
    case arabic

    var layoutDirection: LayoutDirection { self == .arabic ? .rightToLeft : .leftToRight }
}

/// Lightweight in-app localization. Keys are the English source strings, so any
/// string without an Arabic entry gracefully falls back to English.
enum Localizer {
    static func resolve(_ language: AppLanguage) -> ResolvedLanguage {
        switch language {
        case .english: return .english
        case .arabic: return .arabic
        case .system:
            let pref = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return pref.hasPrefix("ar") ? .arabic : .english
        }
    }

    static func string(_ key: String, _ language: ResolvedLanguage) -> String {
        guard language == .arabic else { return key }
        return arabic[key] ?? key
    }

    /// English source string → Arabic translation.
    static let arabic: [String: String] = [
        // App / general
        "TLang": "TLang",
        "Translate": "ترجمة",
        "Stop": "إيقاف",
        "Settings": "الإعدادات",
        "Translation history": "سجل الترجمة",
        "Swap — translate the result back": "تبديل — ترجمة النتيجة عكسيًا",
        "Open main window": "فتح النافذة الرئيسية",
        "Quit TLang": "إنهاء TLang",
        "Translation appears here": "تظهر الترجمة هنا",
        "Translating…": "جارٍ الترجمة…",
        "thinking…": "يفكّر…",
        "retrying…": "إعادة المحاولة…",
        "finding alternatives…": "البحث عن بدائل…",
        "Copy": "نسخ",
        "Dictate": "إملاء",
        "Stop dictation": "إيقاف الإملاء",
        "Speak aloud": "النطق بصوت",
        "Stop speaking": "إيقاف النطق",
        "Clear": "مسح",
        "Alternatives": "بدائل",
        "Original": "الأصل",
        "Auto-translate": "ترجمة تلقائية",
        "Watch clipboard": "مراقبة الحافظة",
        "Type or paste — or just copy text anywhere":
            "اكتب أو ألصق — أو انسخ أي نص في أي مكان",
        "Type, paste, or copy text anywhere":
            "اكتب أو ألصق أو انسخ النص في أي مكان",

        // Appearance / quick controls
        "Appearance: %@ — click to switch": "المظهر: %@ — انقر للتبديل",
        "Auto": "تلقائي",
        "Light": "فاتح",
        "Dark": "داكن",

        // Floating panel
        "Replace": "استبدال",
        "Paste the translation over the original selection":
            "لصق الترجمة فوق النص المحدد الأصلي",
        "Open in TLang": "فتح في TLang",
        "Close (Esc)": "إغلاق (Esc)",

        // History
        "History": "السجل",
        "Search history": "البحث في السجل",
        "No translations yet": "لا توجد ترجمات بعد",
        "No matches": "لا توجد نتائج",
        "Remove all unpinned entries": "إزالة كل العناصر غير المثبتة",
        "Pin": "تثبيت",
        "Unpin": "إلغاء التثبيت",
        "Copy Translation": "نسخ الترجمة",
        "Delete": "حذف",

        // Settings — tabs & common
        "Provider": "المزوّد",
        "Behavior": "السلوك",
        "About": "حول",
        "Model": "النموذج",
        "Base URL": "عنوان الخادم",
        "API Key": "مفتاح الـ API",
        "Browse models from the server": "تصفّح النماذج من الخادم",
        "Test Connection": "اختبار الاتصال",
        "Testing…": "جارٍ الاختبار…",
        "OpenAI-compatible endpoint": "نقطة وصول متوافقة مع OpenAI",
        "The API key is stored in the macOS Keychain. Local servers (Ollama, LM Studio, vLLM) don't need a key.":
            "يُحفظ مفتاح الـ API في سلسلة مفاتيح macOS. الخوادم المحلية (Ollama وLM Studio وvLLM) لا تحتاج إلى مفتاح.",
        "Reasoning": "الاستدلال",
        "Disable model thinking / reasoning": "تعطيل تفكير/استدلال النموذج",
        "Connection": "الاتصال",

        // Settings — behavior
        "Translation": "الترجمة",
        "Auto-translate while typing": "ترجمة تلقائية أثناء الكتابة",
        "Watch clipboard and translate copied text": "مراقبة الحافظة وترجمة النص المنسوخ",
        "Hotkey": "اختصار لوحة المفاتيح",
        "Double ⌘C hotkey": "اختصار ⌘C المزدوج",
        "Replace in place": "الاستبدال في المكان",
        "Permissions": "الأذونات",
        "Accessibility access granted": "تم منح إذن الإتاحة",
        "Accessibility access required for the hotkey and replace-in-place":
            "إذن الإتاحة مطلوب للاختصار وللاستبدال في المكان",
        "Grant…": "منح…",
        "Save translation history": "حفظ سجل الترجمة",
        "entries stored locally": "عنصرًا محفوظًا محليًا",
        "Clear History…": "مسح السجل…",
        "Version": "الإصدار",
        "App": "التطبيق",
        "Appearance": "المظهر",
        "UI Language": "لغة الواجهة",
        "Launch at login": "التشغيل عند تسجيل الدخول",
        "Hide Dock icon (menu bar only)": "إخفاء أيقونة Dock (شريط القائمة فقط)",
        "Updates": "التحديثات",
        "Automatically check for updates": "التحقق من التحديثات تلقائيًا",
        "Check Now": "تحقق الآن",
        "Check for Updates…": "التحقق من التحديثات…",
        "TLang checks GitHub Releases for new versions and installs them in place.":
            "يتحقق TLang من إصدارات GitHub للنسخ الجديدة ويثبّتها في مكانها.",
        "History is saved to ~/Library/Application Support/TLang/history.json and never leaves this Mac.":
            "يُحفظ السجل في ~/Library/Application Support/TLang/history.json ولا يغادر هذا الجهاز.",

        // About
        "Arabic ⇄ English translation, powered by any\nOpenAI-compatible chat-completions API.":
            "ترجمة عربي ⇄ إنجليزي، مدعومة بأي واجهة\nمحادثة متوافقة مع OpenAI.",
        "Copy text anywhere — TLang translates it automatically":
            "انسخ أي نص — يترجمه TLang تلقائيًا",
        "Hold ⌘ and double-tap C for the floating translator":
            "اضغط ⌘ مع النقر مرتين على C للمترجم العائم",
        "History is stored locally on this Mac": "يُخزَّن السجل محليًا على هذا الجهاز",
        "Made with Claude by Raad Kasem": "صُنع باستخدام Claude بواسطة رعد كاسم",
    ]
}
