import Foundation
import Security

// MARK: - Tillar

struct Language: Equatable {
    let code: String
    let flag: String
    let uzName: String
    let englishName: String

    static let all: [Language] = [
        Language(code: "ru", flag: "🇷🇺", uzName: "Rus", englishName: "Russian"),
        Language(code: "en", flag: "🇬🇧", uzName: "Ingliz", englishName: "English"),
        Language(code: "tr", flag: "🇹🇷", uzName: "Turk", englishName: "Turkish"),
        Language(code: "ko", flag: "🇰🇷", uzName: "Koreys", englishName: "Korean"),
        Language(code: "kk", flag: "🇰🇿", uzName: "Qozoq", englishName: "Kazakh"),
        Language(code: "de", flag: "🇩🇪", uzName: "Nemis", englishName: "German"),
        Language(code: "ar", flag: "🇸🇦", uzName: "Arab", englishName: "Arabic"),
        Language(code: "zh", flag: "🇨🇳", uzName: "Xitoy", englishName: "Simplified Chinese"),
        Language(code: "ja", flag: "🇯🇵", uzName: "Yapon", englishName: "Japanese"),
        Language(code: "fr", flag: "🇫🇷", uzName: "Fransuz", englishName: "French"),
    ]

    private static let defaultsKey = "targetLanguage"

    static var saved: Language {
        get {
            let code = UserDefaults.standard.string(forKey: defaultsKey)
            return all.first { $0.code == code } ?? all[0]
        }
        set { UserDefaults.standard.set(newValue.code, forKey: defaultsKey) }
    }
}

// MARK: - API kalitini saqlash (Keychain)

enum KeyStore {
    private static let base: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "tarjimon.keyboard",
        kSecAttrAccount as String: "gemini-api-key",
    ]

    static func load() -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(key.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
}

// MARK: - Xatolar

enum TranslateError: LocalizedError {
    case noKey
    case badKey
    case quota
    case http(Int, String)
    case empty
    case network(String)

    var errorDescription: String? {
        switch self {
        case .noKey: return "API kalit kiritilmagan. ⚙︎ tugmasini bosing."
        case .badKey: return "API kalit noto'g'ri yoki o'chirilgan. ⚙︎ orqali yangisini kiriting."
        case .quota: return "Bepul limit vaqtincha tugadi. Bir daqiqadan keyin qayta urinib ko'ring."
        case .http(let code, let msg): return "Xato \(code): \(msg)"
        case .empty: return "Javob bo'sh keldi. Qaytadan urinib ko'ring."
        case .network(let msg): return "Internet bilan muammo: \(msg)"
        }
    }
}

// MARK: - Gemini orqali tarjima

struct GeminiTranslator {
    /// Birinchisi topilmasa (404), keyingisi sinab ko'riladi.
    static let models = ["gemini-flash-latest", "gemini-2.5-flash"]

    let apiKey: String

    /// O'zbekchadan tanlangan tilga.
    func translate(_ text: String, to target: Language) async throws -> String {
        let system = """
        You are a professional interpreter helping an Uzbek speaker chat with people.
        The user writes in Uzbek: Latin or Cyrillic script, often informal, with typos, \
        missing apostrophes (o' g' written as o g), dialect words or mixed Russian words.
        First understand what the person really means, then translate it into natural, \
        conversational \(target.englishName), the way a native speaker would say it in a chat.
        Keep names, numbers, emojis and line breaks. Keep the same politeness level \
        (Uzbek "siz" is polite, "sen" is informal).
        Output ONLY the \(target.englishName) translation. No quotes, no explanations, no transliteration.
        """
        return try await generate(system: system, user: text)
    }

    /// Istalgan tildan o'zbekchaga (suhbatdoshning xabarini tushunish uchun).
    func translateToUzbek(_ text: String) async throws -> String {
        let system = """
        You are a professional interpreter. Detect the language of the user's message and \
        translate it into natural, everyday Uzbek written in the Latin alphabet \
        (use oʻ and gʻ correctly). Keep names, numbers, emojis and line breaks.
        Output ONLY the Uzbek translation, nothing else.
        """
        return try await generate(system: system, user: text)
    }

    private func generate(system: String, user: String) async throws -> String {
        guard !apiKey.isEmpty else { throw TranslateError.noKey }
        var lastError: Error = TranslateError.empty
        for model in Self.models {
            do {
                return try await call(model: model, system: system, user: user)
            } catch TranslateError.http(let code, let msg) where code == 404 {
                lastError = TranslateError.http(code, msg)
                continue
            }
        }
        throw lastError
    }

    private func call(model: String, system: String, user: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [["text": user]]]],
            "generationConfig": ["temperature": 0.2],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch {
            throw TranslateError.network(error.localizedDescription)
        }
        let (data, response) = result
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard status == 200 else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "noma'lum xato"
            if status == 403 || (status == 400 && message.localizedCaseInsensitiveContains("API key")) {
                throw TranslateError.badKey
            }
            if status == 429 { throw TranslateError.quota }
            throw TranslateError.http(status, message)
        }

        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]] ?? []
        let text = parts
            .filter { ($0["thought"] as? Bool) != true }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranslateError.empty }
        return text
    }
}
