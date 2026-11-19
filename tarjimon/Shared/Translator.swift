import Foundation

enum TranslateError: LocalizedError {
    case noKey
    case badKey
    case rateLimited
    case offline
    case empty
    case server(String)

    var errorDescription: String? {
        switch self {
        case .noKey:
            return "Gemini kaliti kiritilmagan. Tarjimon ilovasini ochib, kalitni kiriting."
        case .badKey:
            return "Gemini kaliti noto'g'ri. Ilovada kalitni tekshiring."
        case .rateLimited:
            return "Bepul limit vaqtincha tugadi. Bir daqiqadan keyin qayta urinib ko'ring."
        case .offline:
            return "Internetga ulanib bo'lmadi. Internetni va «Full Access» yoqilganini tekshiring."
        case .empty:
            return "Tarjima bo'sh qaytdi. Qayta urinib ko'ring."
        case .server(let message):
            return "Xatolik: \(message)"
        }
    }
}

/// Google Gemini (bepul) orqali tarjima.
enum Translator {
    /// O'zbekchadan ruscha/inglizchaga.
    static func toForeign(_ text: String, lang: TargetLang, tone: Tone) async throws -> String {
        let system = """
        You are a professional translator helping an Uzbek speaker chat with people. \
        The user's message is written in Uzbek (Latin or Cyrillic script). It may be informal and contain typos, slang \
        or missing apostrophes (for example "o" instead of "oʻ", "g" instead of "gʻ"). Understand the intended meaning \
        and translate it into natural, fluent \(lang.englishName). \(tone.instruction) \
        Keep emojis, names, numbers and links unchanged. \
        Output ONLY the translated message: no quotes, notes, transliteration or explanations.
        """
        return try await run(system: system, text: text)
    }

    /// Istalgan tildan o'zbekchaga (kelgan xabarni tushunish uchun).
    static func toUzbek(_ text: String) async throws -> String {
        let system = """
        You are a professional translator. Translate the user's message (usually Russian or English) into natural, \
        simple Uzbek using the Latin alphabet (with oʻ and gʻ). Keep emojis, names and numbers. \
        Output ONLY the translation: no quotes, notes or explanations.
        """
        return try await run(system: system, text: text)
    }

    private static func run(system: String, text: String) async throws -> String {
        let key = AppSettings.apiKey
        guard !key.isEmpty else { throw TranslateError.noKey }

        let model = AppSettings.model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? AppSettings.defaultModel
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw TranslateError.server("Model nomi noto'g'ri")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [["text": text]]]],
            "generationConfig": ["temperature": 0.3],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch {
            throw TranslateError.offline
        }
        let (data, response) = result

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard status == 200 else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(status)"
            if status == 429 { throw TranslateError.rateLimited }
            if message.localizedCaseInsensitiveContains("API key") { throw TranslateError.badKey }
            throw TranslateError.server(message)
        }

        let candidates = json?["candidates"] as? [[String: Any]]
        let parts = (candidates?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
        let output = parts
            .filter { ($0["thought"] as? Bool) != true }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmed

        guard !output.isEmpty else { throw TranslateError.empty }
        return output
    }
}
