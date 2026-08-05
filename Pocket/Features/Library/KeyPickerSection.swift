import SwiftUI

/// Choosing a song's key as the **two independent choices it actually is** — a root and a tonality —
/// rather than one 25-row menu over every combination of them (v2 close-out N10).
///
/// The old control was a `Picker` over `MusicalKey.pickerOrder`: a menu long enough to scroll, in
/// which finding "E♭ minor" meant reading past "E♭ major" and twenty-two others. Nobody thinks of a
/// key that way. They know the letter, and they know whether it's major or minor.
///
/// **The roots re-spell when the tonality flips**, and that is the point rather than a glitch: the
/// spelling of a root is decided by the key it belongs to (ADR 0123), so pitch class 3 is E♭ in major
/// and D♯ in minor. Splitting the control is what makes that rule visible — a flat menu of 24 could
/// only ever show one spelling of each pitch and leave the other unexplained.
///
/// Value-only: it edits a `MusicalKey` binding and knows nothing about `Song` or SwiftData, so it
/// previews and could serve any other surface that needs a key.
struct KeyPickerSection: View {
    @Binding var key: MusicalKey
    var tint: Color = PocketColor.library

    /// The tonality the **roots are labelled for**, which is not the same as the key's own quality:
    /// while the key is Unknown there is no quality to read, and the twelve buttons still have to be
    /// spelled somehow. Seeded from the key when there is one, then held here.
    @State private var quality: MusicalKey.Quality

    init(key: Binding<MusicalKey>, tint: Color = PocketColor.library) {
        _key = key
        self.tint = tint
        _quality = State(initialValue: key.wrappedValue.quality ?? .major)
    }

    /// Six per row → a stable 2×6 grid whatever the labels come out as. A wrapping layout would
    /// reflow when "C" became "D♭" on a tonality flip, which is movement with no meaning behind it.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        Section {
            Picker("Tonality", selection: $quality) {
                Text("Major").tag(MusicalKey.Quality.major)
                Text("Minor").tag(MusicalKey.Quality.minor)
            }
            .pickerStyle(.segmented)
            .onChange(of: quality) { _, updated in
                // Re-make the key in the new tonality, but only when a root is already chosen —
                // flipping the control while Unknown re-labels the buttons and commits nothing.
                guard let pitchClass = key.pitchClass else { return }
                key = .make(pitchClass: pitchClass, quality: updated)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<12, id: \.self) { pitchClass in
                    rootChip(pitchClass)
                }
            }
            .padding(.vertical, 4)

            if key != .unknown {
                Button("Clear") { key = .unknown }
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        } header: {
            Text("Key")
        } footer: {
            Text(key == .unknown ? "Not set." : "\(key.displayName).")
                .font(.futura(.caption))
        }
    }

    private func rootChip(_ pitchClass: Int) -> some View {
        let candidate = MusicalKey.make(pitchClass: pitchClass, quality: quality)
        return ToggleChip(isOn: candidate == key, tint: tint) {
            // Tapping the selected root again clears it — the same "tap the current value to unset"
            // grammar the mastery dots use, and the only other way out is the Clear button below.
            key = candidate == key ? .unknown : candidate
        } content: {
            Text(candidate.rootLabel)
                .font(.futura(.subheadline))
                .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(candidate.displayName)
    }
}

#Preview("Key picker") {
    @Previewable @State var key = MusicalKey.aSharpMinor
    Form {
        KeyPickerSection(key: $key)
    }
}

#Preview("Key picker · unknown") {
    @Previewable @State var key = MusicalKey.unknown
    Form {
        KeyPickerSection(key: $key)
    }
}
