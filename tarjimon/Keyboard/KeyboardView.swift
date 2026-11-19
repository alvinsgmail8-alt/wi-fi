import SwiftUI
import UIKit

@MainActor
struct KeyboardView: View {
    @ObservedObject var state: KeyboardState

    private let letters1 = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    private let letters2 = ["a", "s", "d", "f", "g", "h", "j", "k", "l", "gʻ"]
    private let letters3 = ["z", "x", "c", "v", "b", "n", "m", "oʻ"]

    private let symbols1 = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let symbols2 = ["-", "/", ":", ";", "(", ")", "?", "!", "\"", "@"]
    private let symbols3 = ["'", "%", "+", "=", "*", "#", "&", "_"]

    private let rowHeight: CGFloat = 42

    var body: some View {
        VStack(spacing: 6) {
            toolbar
            textArea
            if state.symbols {
                row(symbols1)
                row(symbols2)
                thirdRow(symbols3)
            } else {
                row(letters1)
                row(letters2)
                thirdRow(letters3)
            }
            bottomRow
        }
        .padding(.horizontal, 3)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            ForEach(TargetLang.allCases) { item in
                Chip(text: "\(item.flag) \(item.short)", selected: state.lang == item) {
                    state.lang = item
                }
            }
            Chip(text: "\(state.tone.icon) \(state.tone.title)", selected: false) {
                state.tone = state.tone == .casual ? .formal : .casual
            }
            Spacer(minLength: 0)
            Chip(text: "📋→🇺🇿", selected: false) { state.translateClipboard() }
            Chip(text: "✏️⇄", selected: false) { state.translateField() }
        }
        .frame(height: 30)
    }

    // MARK: - Text area

    private var textArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Palette.field)

            if let message = state.message {
                HStack(alignment: .top, spacing: 8) {
                    ScrollView {
                        Text(message)
                            .font(.system(size: 15))
                            .foregroundColor(state.messageIsError ? .red : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button { state.dismissMessage() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
                .padding(8)
            } else if !state.hasKey {
                HStack {
                    Text("Kalit yo'q. Ilovada kiriting yoki kalitni nusxa olib bosing →")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer(minLength: 4)
                    Button("📋 Joylash") { state.pasteKey() }
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 10)
            } else {
                HStack(spacing: 8) {
                    Text(state.buffer.isEmpty ? "O'zbekcha yozing…" : state.buffer)
                        .font(.system(size: 16))
                        .foregroundColor(state.buffer.isEmpty ? .secondary : .primary)
                        .lineLimit(2)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !state.buffer.isEmpty {
                        Button("🇺🇿↵") { state.insertOriginal() }
                            .font(.system(size: 14))
                        Button { state.clear() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }

            if state.busy {
                RoundedRectangle(cornerRadius: 10).fill(Palette.field.opacity(0.85))
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Tarjima qilinmoqda…").font(.system(size: 14)).foregroundColor(.secondary)
                }
            }
        }
        .frame(height: state.message == nil ? 46 : 58)
    }

    // MARK: - Rows

    private func row(_ keys: [String]) -> some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { key in
                letterKey(key)
            }
        }
        .frame(height: rowHeight)
    }

    private func thirdRow(_ keys: [String]) -> some View {
        HStack(spacing: 5) {
            if state.symbols {
                Key(label: ".", kind: .special, width: 42) { state.tap(".") }
            } else {
                Key(label: state.capsLock ? "⇪" : "⇧",
                    kind: state.isUpper ? .normal : .special,
                    width: 42) { state.toggleShift() }
            }
            ForEach(keys, id: \.self) { key in
                letterKey(key)
            }
            Key(label: "⌫", kind: .special, width: 42) { state.backspace() }
        }
        .frame(height: rowHeight)
    }

    private var bottomRow: some View {
        HStack(spacing: 5) {
            Key(label: state.symbols ? "ABC" : "123", kind: .special, width: 44, fontSize: 15) {
                state.symbols.toggle()
            }
            if state.showGlobe {
                Key(label: "🌐", kind: .special, width: 36, fontSize: 17) { state.nextKeyboard() }
            }
            Key(label: ",", kind: .normal, width: 30) { state.tap(",") }
            Key(label: "probel", kind: .normal, fontSize: 15) { state.space() }
            Key(label: state.symbols ? "↵" : "ʼ", kind: .normal, width: 30) {
                if state.symbols { state.newline() } else { state.tap("ʼ") }
            }
            Key(label: ".", kind: .normal, width: 30) { state.tap(".") }
            Key(label: "\(state.lang.flag) Tarjima", kind: .accent, width: 96, fontSize: 15) {
                state.translateBuffer()
            }
        }
        .frame(height: rowHeight)
    }

    private func letterKey(_ key: String) -> some View {
        let label = (!state.symbols && state.isUpper) ? key.uppercased() : key
        return Key(label: label, kind: .normal) { state.tap(key) }
    }
}

// MARK: - Building blocks

enum KeyKind {
    case normal, special, accent
}

enum Palette {
    static let key = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white })
    static let special = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.27, alpha: 1)
        : UIColor(red: 0.67, green: 0.70, blue: 0.75, alpha: 1) })
    static let field = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : .white })
    static let accent = Color(red: 0.10, green: 0.45, blue: 0.95)
}

struct Key: View {
    let label: String
    var kind: KeyKind = .normal
    var width: CGFloat? = nil
    var fontSize: CGFloat = 21
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: fontSize, weight: kind == .accent ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .buttonStyle(KeyButtonStyle(kind: kind))
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil)
    }
}

struct KeyButtonStyle: ButtonStyle {
    let kind: KeyKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .foregroundColor(kind == .accent ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(fill(pressed: configuration.isPressed))
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
            )
    }

    private func fill(pressed: Bool) -> Color {
        switch kind {
        case .normal: return pressed ? Palette.special : Palette.key
        case .special: return pressed ? Palette.key : Palette.special
        case .accent: return pressed ? Palette.accent.opacity(0.7) : Palette.accent
        }
    }
}

struct Chip: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .frame(maxHeight: .infinity)
                .foregroundColor(selected ? .white : .primary)
                .background(Capsule().fill(selected ? Palette.accent : Palette.key))
        }
        .buttonStyle(.plain)
    }
}
