import SwiftUI

/// Which shape the Arpeggios exercise generates (ADR 0313 D2): the CAGED **box** it has always played, or
/// **triads** on three strings. Editor state only: what's stored is the content case it writes,
/// `.arpeggio` or `.triads`.
enum ArpeggioShape: String, CaseIterable, Identifiable, Hashable {
    case box, triads

    var id: String { rawValue }

    var label: String {
        switch self {
        case .box: return "Box"
        case .triads: return "Triads"
        }
    }

    /// The shape stored content opens on: Triads for a Triads run, the box for anything else.
    init(content: FretboardContent?) {
        self = content?.triadsValue == nil ? .box : .triads
    }
}

/// The Arpeggios exercise's **Generate** rows (ADR 0313 D2): first a choice of shape, then the box editor
/// or the Triads editor. Shared by the create form and *Edit shape*, so the two can't drift.
///
/// **Triads is guitar only** (D2): on a bass exercise the Shape row doesn't show and the box editor is all
/// there is.
struct ArpeggioGenerateRows: View {
    @Binding var shape: ArpeggioShape
    @Binding var box: ArpeggioRun
    @Binding var triads: TriadRun
    var instrument: Instrument = .guitar
    /// The exercise's bar, which a progression's chords hold for (D4).
    var beatsPerBar: Int = 4
    /// Whether switching to Triads carries the box's key (D2). True for a box the player has: one saved
    /// with the exercise, or one they've changed here. A new exercise's untouched box isn't one, so its
    /// first switch opens on the run D10 describes.
    var carriesBoxKey: Bool
    var tint: Color = PocketColor.practice

    var body: some View {
        if instrument == .guitar {
            Picker("Shape", selection: shapeBinding) {
                ForEach(ArpeggioShape.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Shape")
            // The editor's own rows hide theirs; a line here would split Generate from what it generates.
            .listRowSeparator(.hidden)
        }
        if instrument == .guitar && shape == .triads {
            TriadRunEditor(run: $triads, tint: tint, beatsPerBar: beatsPerBar)
        } else {
            ArpeggioRunEditor(run: $box, instrument: instrument, tint: tint)
        }
    }

    private var shapeBinding: Binding<ArpeggioShape> {
        Binding(get: { shape }, set: { newShape in
            if newShape == .triads, shape == .box, carriesBoxKey { triads = triads.carryingKey(from: box) }
            shape = newShape
            haptic(.light)
        })
    }
}
