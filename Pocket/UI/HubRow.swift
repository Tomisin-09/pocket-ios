import SwiftUI

/// One row of a hub (ADR 0162 D1): an icon, a title, and — where a single fact dominates the
/// destination — that fact. The Settings hub was the first; the detail sheets' category rows are the
/// same row (ADR 0258).
///
/// **The value is optional on purpose (D3).** A row like *Song player* holds four unranked toggles;
/// electing one of them to display would be arbitrary and would misreport the screen. A blank
/// trailing slot is more honest than a confident summary of a quarter of the truth.
///
/// The value is usually words (`init(icon:title:value:)`). Where the fact is better shown than said —
/// a loop's colour, a drill's mastery dots — it is a view.
struct HubRow<Value: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let value: () -> Value

    var body: some View {
        LabeledContent {
            value()
        } label: {
            Label {
                Text(title).foregroundStyle(PocketColor.textPrimary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }
}

extension HubRow where Value == HubRowText {
    init(icon: String, title: String, value: String? = nil) {
        self.init(icon: icon, title: title) { HubRowText(text: value) }
    }
}

/// A hub row's value in words: secondary, one line, or nothing at all.
struct HubRowText: View {
    let text: String?

    var body: some View {
        if let text {
            Text(text)
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
        }
    }
}
