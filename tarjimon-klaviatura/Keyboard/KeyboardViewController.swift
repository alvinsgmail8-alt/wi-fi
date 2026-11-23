import UIKit

// MARK: - Tugma turlari

enum KeyKind {
    case char(String)
    case shift
    case delete
    case space
    case ret
    case layer
    case globe
}

struct KeySpec {
    let kind: KeyKind
    let title: String
    /// Harf tugmasiga nisbatan kenglik. nil = qolgan joyni egallaydi.
    let width: CGFloat?

    static func char(_ s: String, width: CGFloat? = 1) -> KeySpec { KeySpec(kind: .char(s), title: s, width: width) }
}

final class KeyButton: UIButton {
    var kind: KeyKind = .space
    var normalColor: UIColor = .white { didSet { backgroundColor = normalColor } }
    var pressedColor: UIColor = .lightGray
    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? pressedColor : normalColor }
    }
}

// MARK: - Klaviatura

final class KeyboardViewController: UIInputViewController {

    // Holat
    private var buffer = "" { didSet { refreshPreview() } }
    private var status: String?
    private var shiftOn = true
    private var numbersLayer = false
    private var busy = false
    private var language = Language.saved

    // Ko'rinishlar
    private let root = UIStackView()
    private let chipsStack = UIStackView()
    private var chipButtons: [UIButton] = []
    private let preview = UITextView()
    private let translateButton = UIButton(type: .custom)
    private let incomingButton = UIButton(type: .custom)
    private let keysContainer = UIView()
    private var keysStack: UIStackView?
    private var letterButtons: [KeyButton] = []
    private let settingsPanel = UIStackView()
    private let keyStatusLabel = UILabel()
    private var deleteTimer: Timer?

    // Ranglar
    private let keyColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white }
    private let specialKeyColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.27, alpha: 1) : UIColor(red: 0.67, green: 0.69, blue: 0.73, alpha: 1) }
    private let pressedColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.55, alpha: 1) : UIColor(white: 0.82, alpha: 1) }
    private let panelColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : UIColor(white: 1, alpha: 0.9) }

    // MARK: Hayot sikli

    override func viewDidLoad() {
        super.viewDidLoad()
        let height = view.heightAnchor.constraint(equalToConstant: 340)
        height.priority = UILayoutPriority(999)
        height.isActive = true
        buildUI()
        rebuildKeys()
        refreshPreview()
        updateLanguageUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !hasFullAccess {
            showStatus("⚠️ Sozlamalar → Umumiy → Klaviatura → Klaviaturalar → Tarjimon → «Toʻliq ruxsat» ni yoqing. Usiz internet ishlamaydi.")
        } else if KeyStore.load() == nil {
            showStatus("Birinchi marta: ⚙︎ ni bosib Gemini API kalitini kiriting.")
        }
    }

    // MARK: Interfeys

    private func buildUI() {
        root.axis = .vertical
        root.spacing = 6
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])

        // 1) Til tanlash qatori
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        chipsStack.axis = .horizontal
        chipsStack.spacing = 6
        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(chipsStack)
        NSLayoutConstraint.activate([
            chipsStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            chipsStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            chipsStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            chipsStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            chipsStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
        for (index, lang) in Language.all.enumerated() {
            let chip = UIButton(type: .custom)
            chip.tag = index
            chip.addTarget(self, action: #selector(languageTapped(_:)), for: .touchUpInside)
            chipButtons.append(chip)
            chipsStack.addArrangedSubview(chip)
            styleChip(chip, lang: lang, selected: false)
        }
        let gear = UIButton(type: .custom)
        styleFlat(gear, title: "⚙︎", color: specialKeyColor, font: .systemFont(ofSize: 20))
        gear.widthAnchor.constraint(equalToConstant: 40).isActive = true
        gear.addTarget(self, action: #selector(toggleSettings), for: .touchUpInside)
        let topBar = UIStackView(arrangedSubviews: [scroll, gear])
        topBar.spacing = 6
        topBar.heightAnchor.constraint(equalToConstant: 32).isActive = true
        root.addArrangedSubview(topBar)

        // 2) Yozilgan matn / natija oynasi
        preview.isEditable = false
        preview.isSelectable = false
        preview.font = .systemFont(ofSize: 16)
        preview.backgroundColor = panelColor
        preview.layer.cornerRadius = 8
        preview.textContainerInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        preview.heightAnchor.constraint(equalToConstant: 62).isActive = true
        root.addArrangedSubview(preview)

        // 3) Amal tugmalari
        styleFlat(incomingButton, title: "📋 → 🇺🇿", color: specialKeyColor, font: .systemFont(ofSize: 15, weight: .semibold))
        incomingButton.addTarget(self, action: #selector(incomingTapped), for: .touchUpInside)
        styleFlat(translateButton, title: "", color: .systemBlue, font: .systemFont(ofSize: 16, weight: .bold))
        translateButton.setTitleColor(.white, for: .normal)
        translateButton.addTarget(self, action: #selector(translateTapped), for: .touchUpInside)
        let actions = UIStackView(arrangedSubviews: [incomingButton, translateButton])
        actions.spacing = 6
        incomingButton.widthAnchor.constraint(equalTo: actions.widthAnchor, multiplier: 0.3).isActive = true
        actions.heightAnchor.constraint(equalToConstant: 40).isActive = true
        root.addArrangedSubview(actions)

        // 4) Tugmalar + sozlamalar paneli (bir joyda, navbat bilan ko'rinadi)
        root.addArrangedSubview(keysContainer)
        buildSettingsPanel()
    }

    private func styleFlat(_ b: UIButton, title: String, color: UIColor, font: UIFont) {
        b.setTitle(title, for: .normal)
        b.setTitleColor(.label, for: .normal)
        b.titleLabel?.font = font
        b.backgroundColor = color
        b.layer.cornerRadius = 8
    }

    private func styleChip(_ chip: UIButton, lang: Language, selected: Bool) {
        var config = UIButton.Configuration.filled()
        config.title = "\(lang.flag) \(lang.uzName)"
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        config.baseBackgroundColor = selected ? .systemBlue : keyColor
        config.baseForegroundColor = selected ? .white : .label
        chip.configuration = config
    }

    private func buildSettingsPanel() {
        settingsPanel.axis = .vertical
        settingsPanel.spacing = 8
        settingsPanel.isHidden = true
        settingsPanel.translatesAutoresizingMaskIntoConstraints = false
        keysContainer.addSubview(settingsPanel)
        NSLayoutConstraint.activate([
            settingsPanel.leadingAnchor.constraint(equalTo: keysContainer.leadingAnchor, constant: 4),
            settingsPanel.trailingAnchor.constraint(equalTo: keysContainer.trailingAnchor, constant: -4),
            settingsPanel.topAnchor.constraint(equalTo: keysContainer.topAnchor),
        ])

        let info = UILabel()
        info.numberOfLines = 0
        info.font = .systemFont(ofSize: 13)
        info.text = """
        Gemini API kaliti (bepul):
        1. Safari'da aistudio.google.com/apikey ni oching
        2. «Create API key» → kalitni nusxalang (Copy)
        3. Shu yerga qaytib, pastdagi tugmani bosing
        """
        keyStatusLabel.numberOfLines = 0
        keyStatusLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let paste = UIButton(type: .custom)
        styleFlat(paste, title: "📋 Kalitni saqlash", color: .systemBlue, font: .systemFont(ofSize: 16, weight: .semibold))
        paste.setTitleColor(.white, for: .normal)
        paste.titleLabel?.adjustsFontSizeToFitWidth = true
        paste.addTarget(self, action: #selector(pasteKeyTapped), for: .touchUpInside)

        let back = UIButton(type: .custom)
        styleFlat(back, title: "Orqaga", color: specialKeyColor, font: .systemFont(ofSize: 16))
        back.widthAnchor.constraint(equalToConstant: 90).isActive = true
        back.addTarget(self, action: #selector(toggleSettings), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [back, paste])
        buttons.spacing = 6
        buttons.heightAnchor.constraint(equalToConstant: 40).isActive = true
        [info, keyStatusLabel, buttons].forEach(settingsPanel.addArrangedSubview)
    }

    // MARK: Tugmalar

    private func chars(_ s: String) -> [KeySpec] { s.map { KeySpec.char(String($0)) } }

    private static func isLetter(_ s: String) -> Bool { s.lowercased() != s.uppercased() }

    private var layout: [[KeySpec]] {
        let globe: [KeySpec] = needsInputModeSwitchKey ? [KeySpec(kind: .globe, title: "🌐", width: 1.2)] : []
        let delete = KeySpec(kind: .delete, title: "⌫", width: nil)
        let space = KeySpec(kind: .space, title: "boʻsh joy", width: nil)
        let ret = KeySpec(kind: .ret, title: "⏎", width: 1.6)
        let layer = KeySpec(kind: .layer, title: numbersLayer ? "ABC" : "123", width: 1.5)
        var bottom: [KeySpec] = [layer]
        bottom += globe
        bottom += [KeySpec.char(","), space, KeySpec.char("."), ret]

        if numbersLayer {
            var r2: [KeySpec] = chars("-/:;()\"@!")
            r2.append(KeySpec.char("?", width: nil))
            var r3: [KeySpec] = [KeySpec.char("%", width: 1.4)]
            r3 += chars("+=#*&_$")
            r3.append(delete)
            return [chars("1234567890"), r2, r3, bottom]
        }
        var r2: [KeySpec] = chars("asdfghjkl")
        r2.append(KeySpec.char("ʻ", width: nil))
        var r3: [KeySpec] = [KeySpec(kind: .shift, title: "⇧", width: 1.4)]
        r3 += chars("zxcvbnm")
        r3.append(delete)
        return [chars("qwertyuiop"), r2, r3, bottom]
    }

    private func rebuildKeys() {
        keysStack?.removeFromSuperview()
        letterButtons.removeAll()

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        keysContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: keysContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: keysContainer.trailingAnchor),
            stack.topAnchor.constraint(equalTo: keysContainer.topAnchor),
            stack.bottomAnchor.constraint(equalTo: keysContainer.bottomAnchor),
        ])

        var unit: UIView?   // birinchi qatorning birinchi tugmasi = 1 birlik kenglik
        for specs in layout {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 5
            row.distribution = .fill
            for spec in specs {
                let b = makeKey(spec)
                row.addArrangedSubview(b)
                if let w = spec.width {
                    if let unit = unit {
                        b.widthAnchor.constraint(equalTo: unit.widthAnchor, multiplier: w).isActive = true
                    } else {
                        unit = b
                    }
                } else {
                    b.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
                    b.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
                }
            }
            stack.addArrangedSubview(row)
        }
        keysStack = stack
        stack.isHidden = !settingsPanel.isHidden
        keysContainer.bringSubviewToFront(settingsPanel)
        updateLetterTitles()
    }

    private func makeKey(_ spec: KeySpec) -> KeyButton {
        let b = KeyButton(type: .custom)
        b.kind = spec.kind
        b.setTitle(spec.title, for: .normal)
        b.setTitleColor(.label, for: .normal)
        b.layer.cornerRadius = 5
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.25
        b.layer.shadowRadius = 0
        b.layer.shadowOffset = CGSize(width: 0, height: 1)
        b.pressedColor = pressedColor

        switch spec.kind {
        case .char:
            b.normalColor = keyColor
            b.titleLabel?.font = .systemFont(ofSize: 22)
            b.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            if case .char(let s) = spec.kind, Self.isLetter(s) { letterButtons.append(b) }
        case .space:
            b.normalColor = keyColor
            b.titleLabel?.font = .systemFont(ofSize: 15)
            b.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        case .delete:
            b.normalColor = specialKeyColor
            b.titleLabel?.font = .systemFont(ofSize: 20)
            b.addTarget(self, action: #selector(deleteDown), for: .touchDown)
            b.addTarget(self, action: #selector(deleteUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        case .globe:
            b.normalColor = specialKeyColor
            b.titleLabel?.font = .systemFont(ofSize: 18)
            b.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        case .shift, .layer, .ret:
            b.normalColor = specialKeyColor
            b.titleLabel?.font = .systemFont(ofSize: 17)
            b.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        }
        return b
    }

    private func updateLetterTitles() {
        for b in letterButtons {
            guard case .char(let s) = b.kind else { continue }
            b.setTitle(shiftOn ? s.uppercased() : s, for: .normal)
        }
    }

    private func setShift(_ on: Bool) {
        guard shiftOn != on else { return }
        shiftOn = on
        updateLetterTitles()
    }

    @objc private func keyTapped(_ b: KeyButton) {
        status = nil
        switch b.kind {
        case .char(let s):
            let isLetter = Self.isLetter(s)
            buffer += (shiftOn && isLetter) ? s.uppercased() : s
            if isLetter { setShift(false) }
        case .space:
            buffer += " "
            if let last = buffer.dropLast().last, ".!?".contains(last) { setShift(true) }
        case .ret:
            if buffer.isEmpty { textDocumentProxy.insertText("\n") } else { buffer += "\n"; setShift(true) }
        case .shift:
            setShift(!shiftOn)
        case .layer:
            numbersLayer.toggle()
            rebuildKeys()
        case .delete, .globe:
            break
        }
        refreshPreview()
    }

    // ⌫ bosib turilsa takrorlanadi
    @objc private func deleteDown() {
        deleteOnce()
        deleteTimer?.invalidate()
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                self?.deleteOnce()
            }
        }
    }

    @objc private func deleteUp() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }

    private func deleteOnce() {
        status = nil
        if buffer.isEmpty {
            textDocumentProxy.deleteBackward()
            refreshPreview()
        } else {
            buffer.removeLast()
            if buffer.isEmpty { setShift(true) }
        }
    }

    // MARK: Til

    @objc private func languageTapped(_ chip: UIButton) {
        language = Language.all[chip.tag]
        Language.saved = language
        updateLanguageUI()
    }

    private func updateLanguageUI() {
        for (i, chip) in chipButtons.enumerated() {
            styleChip(chip, lang: Language.all[i], selected: Language.all[i] == language)
        }
        if !busy { translateButton.setTitle("Tarjima → \(language.flag) \(language.uzName)", for: .normal) }
    }

    // MARK: Oyna

    private func refreshPreview() {
        if let status = status {
            preview.text = status
            preview.textColor = .secondaryLabel
        } else if buffer.isEmpty {
            preview.text = "Oʻzbekcha yozing, tilni tanlang va «Tarjima» ni bosing. Tarjima matn maydoniga oʻzi tushadi."
            preview.textColor = .tertiaryLabel
        } else {
            preview.text = buffer + "▏"
            preview.textColor = .label
            let end = NSRange(location: (preview.text as NSString).length, length: 0)
            preview.scrollRangeToVisible(end)
        }
    }

    private func showStatus(_ text: String) {
        status = text
        refreshPreview()
        preview.setContentOffset(.zero, animated: false)
    }

    private func setBusy(_ on: Bool, title: String = "Tarjima qilinmoqda…") {
        busy = on
        translateButton.isEnabled = !on
        incomingButton.isEnabled = !on
        translateButton.alpha = on ? 0.6 : 1
        if on { translateButton.setTitle(title, for: .normal) } else { updateLanguageUI() }
    }

    // MARK: Tarjima

    private func readyKey() -> String? {
        guard hasFullAccess else {
            showStatus("⚠️ Avval «Toʻliq ruxsat» ni yoqing: Sozlamalar → Umumiy → Klaviatura → Klaviaturalar → Tarjimon.")
            return nil
        }
        guard let key = KeyStore.load() else {
            showStatus("API kalit yoʻq. Pastdagi koʻrsatmani bajaring.")
            if settingsPanel.isHidden { toggleSettings() }
            return nil
        }
        return key
    }

    /// O'zbekcha → tanlangan til, natija matn maydoniga yoziladi.
    @objc private func translateTapped() {
        guard !busy, let key = readyKey() else { return }

        let typed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        // Klaviatura ichida hech narsa yozilmagan bo'lsa — maydondagi (kursor oldidagi) matnni tarjima qilamiz.
        let fieldText = textDocumentProxy.documentContextBeforeInput ?? ""
        let fromField = typed.isEmpty
        let source = fromField ? fieldText.trimmingCharacters(in: .whitespacesAndNewlines) : typed
        guard !source.isEmpty else {
            showStatus("Avval oʻzbekcha biror narsa yozing.")
            return
        }

        let target = language
        setBusy(true)
        Task { @MainActor in
            defer { self.setBusy(false) }
            do {
                let result = try await GeminiTranslator(apiKey: key).translate(source, to: target)
                if fromField {
                    for _ in 0..<fieldText.count { self.textDocumentProxy.deleteBackward() }
                } else {
                    self.buffer = ""
                    self.setShift(true)
                }
                self.textDocumentProxy.insertText(result)
                self.showStatus("✓ Joylandi (\(target.flag)): \(result)\n\nAsli: \(source)")
            } catch {
                self.showStatus("⚠️ " + (error.localizedDescription))
            }
        }
    }

    /// Nusxalangan (suhbatdoshning) xabarini o'zbekchaga o'girib, oynada ko'rsatadi.
    @objc private func incomingTapped() {
        guard !busy, let key = readyKey() else { return }
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            showStatus("Suhbatdoshning xabarini bosib turib «Nusxalash» (Copy) qiling, keyin 📋 → 🇺🇿 ni bosing.")
            return
        }
        setBusy(true, title: "Oʻqilmoqda…")
        Task { @MainActor in
            defer { self.setBusy(false) }
            do {
                let result = try await GeminiTranslator(apiKey: key).translateToUzbek(text)
                self.showStatus("🇺🇿 \(result)")
            } catch {
                self.showStatus("⚠️ " + error.localizedDescription)
            }
        }
    }

    // MARK: Sozlamalar

    @objc private func toggleSettings() {
        let opening = settingsPanel.isHidden
        settingsPanel.isHidden = !opening
        keysStack?.isHidden = opening
        if opening { refreshKeyStatus() }
    }

    private func refreshKeyStatus() {
        if !hasFullAccess {
            keyStatusLabel.text = "⚠️ «Toʻliq ruxsat» yoqilmagan — kalitni saqlab boʻlmaydi."
            keyStatusLabel.textColor = .systemRed
        } else if let key = KeyStore.load() {
            keyStatusLabel.text = "✓ Kalit saqlangan: …\(key.suffix(4))"
            keyStatusLabel.textColor = .systemGreen
        } else {
            keyStatusLabel.text = "Kalit hali kiritilmagan."
            keyStatusLabel.textColor = .systemOrange
        }
    }

    @objc private func pasteKeyTapped() {
        guard hasFullAccess else { refreshKeyStatus(); return }
        let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard text.hasPrefix("AIza"), text.count >= 30, !text.contains(" ") else {
            keyStatusLabel.text = "Nusxada API kalit topilmadi. Kalit «AIza…» bilan boshlanadi."
            keyStatusLabel.textColor = .systemRed
            return
        }
        if KeyStore.save(text) {
            UIPasteboard.general.string = ""   // kalit nusxada qolib ketmasin
            refreshKeyStatus()
            showStatus("✓ Kalit saqlandi. Endi yozib, «Tarjima» ni bosing.")
        } else {
            keyStatusLabel.text = "Kalitni saqlab boʻlmadi. Qayta urinib koʻring."
            keyStatusLabel.textColor = .systemRed
        }
    }
}
