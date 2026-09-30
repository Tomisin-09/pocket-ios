import SwiftUI

/// The screen a Toolkit row opens (ADR 0235 D6): one switch, so the hub and the Home tile beside Toolkit
/// open the same screen. Each sets the Toolkit's indigo itself, so it looks the same from either door.
struct ToolkitDestination: View {
    let section: ToolkitSection

    var body: some View {
        switch section {
        case .myChords: MyChordsView()
        case .myProgressions: MyProgressionsView()
        case .myTabs: MyTabsView()
        case .tuner: TunerView()
        case .glossary: GlossaryView()
        case .help: FAQView()
        }
    }
}
