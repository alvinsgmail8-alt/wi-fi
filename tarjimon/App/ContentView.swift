import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage(AppSettings.Keys.apiKey, store: AppSettings.defaults) private var apiKey = ""
    @AppStorage(AppSettings.Keys.lang, store: AppSettings.defaults) private var langRaw = TargetLang.ru.rawValue
    @AppStorage(AppSettings.Keys.tone, store: AppSettings.defaults) private var toneRaw = Tone.casual.rawValue
    @AppStorage(AppSettings.Keys.model, store: AppSettings.defaults) private var model = AppSettings.defaultModel

    @State private var input = ""
    @State private var output = ""
    @State private var errorText: String?
    @State private var busy = false
    @State private var toUzbek = false

    private var lang: TargetLang { TargetLang(rawValue: langRaw) ?? .ru }
    private var tone: Tone { Tone(rawValue: toneRaw) ?? .casual }

    var body: some View {
        NavigationStack {
            Form {
                keySection
                keyboardSection
                settingsSection
                testSection
                advancedSection
            }
            .navigationTitle("Tarjimon")
        }
    }

    // MARK: - Sections

    private var keySection: some View {
        Section {
            TextField("AIza…", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
            Button {
                if let text = UIPasteboard.general.string { apiKey = text.trimmed }
            } label: {
                Label("Nusxadan joylash", systemImage: "doc.on.clipboard")
            }
            Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                Label("Bepul kalit olish (Google AI Studio)", systemImage: "key")
            }
        } header: {
            Text("1. Gemini kaliti")
        } footer: {
            Text(apiKey.trimmed.isEmpty ? "Kalit yo'q — tarjima ishlamaydi." : "✅ Kalit saqlandi.")
        }
    }

    private var keyboardSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("① Pastdagi tugmani bosing")
                Text("② Keyboards → Tarjimon ni yoqing")
                Text("③ «Allow Full Access» ni yoqing (internet uchun kerak)")
                Text("④ Chatda 🌐 tugmasini bosib, Tarjimon klaviaturasini tanlang")
            }
            .font(.callout)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Sozlamalarni ochish", systemImage: "gear")
            }
        } header: {
            Text("2. Klaviaturani yoqish")
        }
    }

    private var settingsSection: some View {
        Section {
            Picker("Tarjima tili", selection: $langRaw) {
                ForEach(TargetLang.allCases) { item in
                    Text("\(item.flag) \(item.title)").tag(item.rawValue)
                }
            }
            Picker("Uslub", selection: $toneRaw) {
                ForEach(Tone.allCases) { item in
                    Text("\(item.icon) \(item.title)").tag(item.rawValue)
                }
            }
        } header: {
            Text("3. Sozlamalar")
        } footer: {
            Text("Bularni klaviaturaning o'zida ham almashtirish mumkin.")
        }
    }

    private var testSection: some View {
        Section {
            Picker("Yo'nalish", selection: $toUzbek) {
                Text("🇺🇿 → \(lang.flag)").tag(false)
                Text("Xorijiy → 🇺🇿").tag(true)
            }
            .pickerStyle(.segmented)

            ZStack(alignment: .topLeading) {
                if input.isEmpty {
                    Text(toUzbek ? "Ruscha yoki inglizcha matn…" : "O'zbekcha yozing…")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $input)
                    .frame(minHeight: 90)
            }

            Button {
                Task { await translate() }
            } label: {
                HStack {
                    if busy { ProgressView() }
                    Text("Tarjima qilish")
                }
            }
            .disabled(busy || input.trimmed.isEmpty)

            if let errorText {
                Text(errorText)
                    .foregroundColor(.red)
                    .font(.callout)
            }

            if !output.isEmpty {
                Text(output)
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = output
                } label: {
                    Label("Nusxa olish", systemImage: "doc.on.doc")
                }
            }
        } header: {
            Text("Sinab ko'rish")
        }
    }

    private var advancedSection: some View {
        Section {
            TextField(AppSettings.defaultModel, text: $model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Qo'shimcha")
        } footer: {
            Text("Gemini modeli nomi. Odatda o'zgartirish shart emas.")
        }
    }

    // MARK: - Actions

    @MainActor
    private func translate() async {
        busy = true
        errorText = nil
        output = ""
        defer { busy = false }
        do {
            let text = input.trimmed
            if toUzbek {
                output = try await Translator.toUzbek(text)
            } else {
                output = try await Translator.toForeign(text, lang: lang, tone: tone)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
