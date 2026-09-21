import SwiftUI

/// A status/result message kept as separate EN and RU strings so it can be
/// rendered as two properly styled lines instead of one "EN / RU" string.
struct BilingualText {
    let en: String
    let ru: String
}

/// Two-line EN/RU caption used everywhere IXAK shows bilingual text: the
/// English line on top, a smaller secondary-colored Russian line below.
///
/// Not used inside `.tabItem` or a `.segmented` Picker — both are backed by
/// native AppKit controls (NSTabView / NSSegmentedControl) that only render
/// a single line and silently drop custom multi-font content, so those two
/// spots keep the plain "EN / RU" string instead.
struct BilingualLabel: View {
    let text: BilingualText
    var alignment: HorizontalAlignment = .leading

    init(en: String, ru: String, alignment: HorizontalAlignment = .leading) {
        self.text = BilingualText(en: en, ru: ru)
        self.alignment = alignment
    }

    init(_ text: BilingualText, alignment: HorizontalAlignment = .leading) {
        self.text = text
        self.alignment = alignment
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(text.en)
            Text(text.ru)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
