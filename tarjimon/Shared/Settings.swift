import Foundation

/// Tarjima qilinadigan til.
enum TargetLang: String, CaseIterable, Identifiable {
    case ru, en

    var id: String { rawValue }
    var flag: String { self == .ru ? "🇷🇺" : "🇬🇧" }
    var short: String { self == .ru ? "RU" : "EN" }
    var title: String { self == .ru ? "Ruscha" : "Inglizcha" }
    var englishName: String { self == .ru ? "Russian" : "English" }
}

/// Tarjima uslubi.
enum Tone: String, CaseIterable, Identifiable {
    case casual, formal

    var id: String { rawValue }
    var icon: String { self == .casual ? "😊" : "🎩" }
    var title: String { self == .casual ? "Do'stona" : "Rasmiy" }

    var instruction: String {
        switch self {
        case .casual:
            return "Use a friendly, casual chat style, the way a native speaker texts a friend. Use informal address (for example «ты» in Russian)."
        case .formal:
            return "Use a polite, formal style suitable for work, elders or strangers. Use formal address (for example «Вы» in Russian)."
        }
    }
}

/// Ilova va klaviatura o'rtasida umumiy sozlamalar (App Group orqali).
enum AppSettings {
    static let defaultModel = "gemini-flash-latest"

    enum Keys {
        static let apiKey = "apiKey"
        static let model = "model"
        static let lang = "lang"
        static let tone = "tone"
    }

    static let groupID: String = (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String) ?? ""

    static let defaults: UserDefaults = {
        if !groupID.isEmpty, let shared = UserDefaults(suiteName: groupID) {
            return shared
        }
        return .standard
    }()

    static var apiKey: String {
        get { (defaults.string(forKey: Keys.apiKey) ?? "").trimmed }
        set { defaults.set(newValue.trimmed, forKey: Keys.apiKey) }
    }

    static var model: String {
        get {
            let value = (defaults.string(forKey: Keys.model) ?? "").trimmed
            return value.isEmpty ? defaultModel : value
        }
        set { defaults.set(newValue.trimmed, forKey: Keys.model) }
    }

    static var lang: TargetLang {
        get { TargetLang(rawValue: defaults.string(forKey: Keys.lang) ?? "") ?? .ru }
        set { defaults.set(newValue.rawValue, forKey: Keys.lang) }
    }

    static var tone: Tone {
        get { Tone(rawValue: defaults.string(forKey: Keys.tone) ?? "") ?? .casual }
        set { defaults.set(newValue.rawValue, forKey: Keys.tone) }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
