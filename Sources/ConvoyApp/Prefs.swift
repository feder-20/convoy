import AppKit
import Carbon.HIToolbox

/// Preferencias de Convoy (UserDefaults). Las pantallas usan las mismas claves con @AppStorage.
enum Prefs {
    static let stripAccentsKey = "stripAccents"
    static let includeNameKey = "includeProjectName"
    static let selectedTemplateKey = "selectedTemplate"
    static let hotKeyCodeKey = "hotKeyCode"
    static let hotKeyModsKey = "hotKeyMods"
    static let onboardingKey = "onboardingDone"
    static let changed = Notification.Name("ConvoyPrefsChanged")

    /// ⌥⌘N, configurable (convoy.md §4.2).
    static let defaultHotKey: (code: UInt32, mods: UInt32) = (UInt32(kVK_ANSI_N), UInt32(optionKey | cmdKey))

    static var stripAccents: Bool { UserDefaults.standard.bool(forKey: stripAccentsKey) }
    static var includeName: Bool {
        get { UserDefaults.standard.object(forKey: includeNameKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: includeNameKey) }
    }
    static var selectedTemplate: UUID? {
        get { UserDefaults.standard.string(forKey: selectedTemplateKey).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: selectedTemplateKey) }
    }

    static var hotKey: (code: UInt32, mods: UInt32)? {
        get {
            let d = UserDefaults.standard
            if d.object(forKey: hotKeyCodeKey) == nil { return defaultHotKey }
            let code = d.integer(forKey: hotKeyCodeKey)
            return code < 0 ? nil : (UInt32(code), UInt32(d.integer(forKey: hotKeyModsKey)))   // -1 = sin atajo
        }
        set {
            let d = UserDefaults.standard
            if let n = newValue { d.set(Int(n.code), forKey: hotKeyCodeKey); d.set(Int(n.mods), forKey: hotKeyModsKey) }
            else { d.set(-1, forKey: hotKeyCodeKey) }
            NotificationCenter.default.post(name: changed, object: nil)
        }
    }

    static var onboardingDone: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    private static let keyNames: [Int: String] = {
        var m: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
            kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
            kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z", kVK_Space: "Espacio", kVK_Return: "↩", kVK_Tab: "⇥",
        ]
        let digits = [kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        for (i, k) in digits.enumerated() { m[k] = "\(i)" }
        let fkeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12]
        for (i, k) in fkeys.enumerated() { m[k] = "F\(i + 1)" }
        return m
    }()

    static func label(code: UInt32, mods: UInt32) -> String {
        var s = ""
        if mods & UInt32(controlKey) != 0 { s += "⌃" }
        if mods & UInt32(optionKey) != 0 { s += "⌥" }
        if mods & UInt32(shiftKey) != 0 { s += "⇧" }
        if mods & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + (keyNames[Int(code)] ?? "Tecla \(code)")
    }

    static var hotKeyLabel: String {
        guard let h = hotKey else { return "—" }
        return label(code: h.code, mods: h.mods)
    }
}
