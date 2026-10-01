import SwiftUI

/// **Beside Toolkit** in Settings ▸ Practice (ADR 0235 D6): what the Home tile beside Toolkit opens. The
/// second of its two ways in, as Jump back in has (0193 D4); holding the tile is the other, and both write
/// one key. A card of its own under Jump back in's, so its footer can say what it does.
struct HomeToolSection: View {
    // Bound to the named default, never a literal (see `AppSettings.homeToolDefault`). `HomeView` binds
    // the same keys the same way.
    @AppStorage(AppSettings.Key.homeTool) private var toolRaw = AppSettings.homeToolDefault.rawValue
    @AppStorage(AppSettings.Key.homeToolChosen) private var chosen = false

    private var selection: Binding<ToolkitSection> {
        Binding(get: { AppSettings.resolvedHomeTool(storedValue: toolRaw) },
                set: { toolRaw = $0.rawValue; chosen = true })
    }

    var body: some View {
        Section {
            Picker("Beside Toolkit", selection: selection) {
                ForEach(ToolkitSection.allCases) { section in
                    Text(section.info.title).tag(section)
                }
            }
        } footer: {
            Text("The tile beside Toolkit on Home opens the tool you pick here. You can also hold the tile to "
                 + "change it.")
        }
    }
}

#Preview {
    Form { HomeToolSection() }
}
