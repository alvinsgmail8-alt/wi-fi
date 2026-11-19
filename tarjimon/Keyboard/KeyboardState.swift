import SwiftUI
import UIKit

@MainActor
final class KeyboardState: ObservableObject {
    weak var controller: UIInputViewController?

    @Published var buffer = ""
    @Published var shift = true
    @Published var capsLock = false
    @Published var symbols = false
    @Published var busy = false
    @Published var message: String?
    @Published var messageIsError = false
    @Published var showGlobe = true
    @Published var lang: TargetLang = AppSettings.lang {
        didSet { AppSettings.lang = lang }
    }
    @Published var tone: Tone = AppSettings.tone {
        didSet { AppSettings.tone = tone }
    }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }

    var hasKey: Bool { !AppSettings.apiKey.isEmpty }
    var isUpper: Bool { shift || capsLock }

    func reload() {
        if lang != AppSettings.lang { lang = AppSettings.lang }
        if tone != AppSettings.tone { tone = AppSettings.tone }
        objectWillChange.send()
    }

    // MARK: - Typing

    func tap(_ key: String) {
        buffer += isUpper ? key.uppercased() : key
        if shift && !capsLock { shift = false }
        message = nil
    }

    func space() {
        buffer += " "
        if buffer.hasSuffix(". ") || buffer.hasSuffix("? ") || buffer.hasSuffix("! ") {
            shift = true
        }
    }

    func newline() {
        if buffer.isEmpty {
            proxy?.insertText("\n")
        } else {
            buffer += "\n"
            shift = true
        }
    }

    func toggleShift() {
        if capsLock {
            capsLock = false
            shift = false
        } else if shift {
            capsLock = true
        } else {
            shift = true
        }
    }

    func backspace() {
        if buffer.isEmpty {
            proxy?.deleteBackward()
        } else {
            buffer.removeLast()
            if buffer.isEmpty { shift = true }
        }
    }

    func clear() {
        buffer = ""
        shift = true
        message = nil
    }

    func nextKeyboard() {
        controller?.advanceToNextInputMode()
    }

    /// Tarjimasiz, o'zbekcha matnni o'zini yuborish.
    func insertOriginal() {
        guard !buffer.isEmpty else { return }
        proxy?.insertText(buffer)
        clear()
    }

    // MARK: - Translation

    /// Klaviaturada yozilgan o'zbekcha matnni tarjima qilib, chatga qo'yadi.
    func translateBuffer() {
        let original = buffer
        let text = original.trimmed
        guard !busy else { return }
        guard !text.isEmpty else {
            show("Avval o'zbekcha yozing ✍️")
            return
        }
        guard checkReady() else { return }

        busy = true
        message = nil
        let targetLang = self.lang, targetTone = self.tone
        Task {
            defer { busy = false }
            do {
                let result = try await Translator.toForeign(text, lang: targetLang, tone: targetTone)
                proxy?.insertText(result)
                if buffer.hasPrefix(original) {
                    buffer.removeFirst(original.count)
                }
                if buffer.isEmpty { shift = true }
            } catch {
                show(error.localizedDescription, isError: true)
            }
        }
    }

    /// Chat maydonida (boshqa klaviaturada) yozilgan matnni tarjimaga almashtiradi.
    func translateField() {
        guard !busy, checkReady() else { return }
        let before = proxy?.documentContextBeforeInput ?? ""
        let text = before.trimmed
        guard !text.isEmpty else {
            show("Maydonda matn yo'q. Oddiy klaviaturada yozib, keyin ✏️ tugmasini bosing.")
            return
        }

        busy = true
        message = nil
        let targetLang = self.lang, targetTone = self.tone
        Task {
            defer { busy = false }
            do {
                let result = try await Translator.toForeign(text, lang: targetLang, tone: targetTone)
                guard (proxy?.documentContextBeforeInput ?? "") == before else {
                    show("Matn o'zgardi, qayta bosing.")
                    return
                }
                for _ in 0..<before.count { proxy?.deleteBackward() }
                proxy?.insertText(result)
            } catch {
                show(error.localizedDescription, isError: true)
            }
        }
    }

    /// Nusxa olingan (Copy) xorijiy xabarni o'zbekchaga tarjima qilib ko'rsatadi.
    func translateClipboard() {
        guard !busy, checkReady() else { return }
        guard let text = UIPasteboard.general.string?.trimmed, !text.isEmpty else {
            show("Avval xabarni nusxa oling (Copy), keyin 📋 tugmasini bosing.")
            return
        }

        busy = true
        message = nil
        Task {
            defer { busy = false }
            do {
                let result = try await Translator.toUzbek(text)
                show("🇺🇿 " + result)
            } catch {
                show(error.localizedDescription, isError: true)
            }
        }
    }

    /// Kalitni klaviaturaning o'zidan (nusxadan) saqlash — zaxira yo'l.
    func pasteKey() {
        guard controller?.hasFullAccess != false else {
            show("Avval «Allow Full Access» ni yoqing.", isError: true)
            return
        }
        let text = UIPasteboard.general.string?.trimmed ?? ""
        guard text.hasPrefix("AIza") else {
            show("Nusxada Gemini kaliti topilmadi. Kalitni nusxa olib, qayta bosing.", isError: true)
            return
        }
        AppSettings.apiKey = text
        show("✅ Kalit saqlandi!")
    }

    func dismissMessage() {
        message = nil
    }

    // MARK: - Helpers

    private func checkReady() -> Bool {
        if controller?.hasFullAccess == false {
            show("Sozlamalarda «Allow Full Access» ni yoqing: Settings → Tarjimon → Keyboards.", isError: true)
            return false
        }
        if !hasKey {
            show(TranslateError.noKey.localizedDescription, isError: true)
            return false
        }
        return true
    }

    private func show(_ text: String, isError: Bool = false) {
        message = text
        messageIsError = isError
    }
}
