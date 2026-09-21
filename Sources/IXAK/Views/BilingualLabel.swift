import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, ru
    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .en: "EN"
        case .ru: "RU"
        }
    }
}

/// A status/result message kept as separate EN and RU strings so the app
/// can show whichever one the user picked in the language switcher.
struct BilingualText {
    let en: String
    let ru: String

    func string(for language: AppLanguage) -> String {
        switch language {
        case .en: en
        case .ru: ru
        }
    }
}

/// Renders one line of text in whichever language is currently selected
/// (see the EN/RU switcher in ContentView). All bilingual copy in the app
/// goes through this so a single toggle changes everything at once.
struct BilingualLabel: View {
    @AppStorage("ixak.language") private var language: AppLanguage = .ru
    let text: BilingualText

    init(en: String, ru: String) {
        self.text = BilingualText(en: en, ru: ru)
    }

    init(_ text: BilingualText) {
        self.text = text
    }

    var body: some View {
        Text(text.string(for: language))
    }
}
