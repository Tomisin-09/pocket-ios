import SwiftData
import SwiftUI

/// The metronome screen's bottom action row (ADR 0043, slice 7) — exercise actions as direct
/// taps rather than buried in the library sheet (which stays a pure browser). Laid out as a
/// clean split with the session timer centred between:
///
/// - **Trailing, always:** **+** (save the current settings as a new named preset — the
///   prominent accent button) and **📚** (open the library to load / rename / delete).
/// - **Leading, only when an exercise is loaded:** **✕** (leave it, back to the free-play
///   default) and **save** (update *this* preset, with a confirmation of what will be stored).
///
/// So the left cluster acts on the loaded exercise and the right cluster is the global
/// new/library pair.
struct ExerciseActionBar: View {
    let engine: StandaloneMetronomeEngine
    @Binding var loadedExercise: MetronomeExercise?
    /// Opens the presets library (state lives on the screen, which owns the sheet).
    let showLibrary: () -> Void

    @Environment(\.modelContext) private var context

    @State private var savingNew = false
    @State private var confirmingUpdate = false
    /// Captured when "save" is tapped so the confirmation shows exactly what will overwrite
    /// the preset (what-you-see-is-what-is-stored).
    @State private var pendingSummary = ""

    var body: some View {
        HStack(spacing: 10) {
            // Leading — actions on the loaded exercise; absent in free play.
            if loadedExercise != nil {
                iconButton(symbol: "xmark", tint: .red,
                           label: "Leave exercise, back to default", action: leaveExercise)
                iconButton(symbol: "square.and.arrow.down", tint: PocketColor.metronome,
                           label: "Save into this preset", action: startUpdate)
            }
            Spacer()
            // Trailing — global: save-as-new (prominent) and the library.
            saveNewButton
            iconButton(symbol: "books.vertical", tint: PocketColor.metronome,
                       label: "Exercise presets", action: showLibrary)
        }
        .sheet(isPresented: $savingNew) {
            SaveExerciseSheet(initialWorking: defaultWorking, initialTarget: defaultTarget,
                              onSave: saveNew)
        }
        .confirmationDialog("Update “\(loadedExercise?.name ?? "")”?",
                            isPresented: $confirmingUpdate, titleVisibility: .visible) {
            Button("Save these settings", action: commitUpdate)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(pendingSummary)
        }
    }

    /// The prominent **save current settings as a new preset** button — filled accent, so it
    /// reads as the primary save affordance against the translucent icon buttons.
    private var saveNewButton: some View {
        Button(action: startSave) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PocketColor.background)
                .frame(width: 44, height: 44)
                .background(Circle().fill(PocketColor.metronome))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save current settings as a preset")
    }

    private func iconButton(symbol: String, tint: Color, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(PocketColor.metronome.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func startSave() {
        savingNew = true
        haptic(.light)
    }

    /// Defaults for the save sheet: when a ramp is armed, the floor and ceiling already frame
    /// working→target; otherwise the current tempo with a sensible goal above it (so the
    /// progress bar isn't born "At target").
    private var defaultWorking: Int {
        engine.automatorEnabled ? engine.automatorStartBPM : engine.bpm
    }

    private var defaultTarget: Int {
        let base = engine.automatorEnabled ? engine.automatorCeiling : engine.bpm + 20
        return min(StandaloneMetronomeEngine.bpmRange.upperBound, base)
    }

    private func startUpdate() {
        pendingSummary = MetronomeExerciseBridge.preview(from: engine).configurationSummary
        confirmingUpdate = true
        haptic(.light)
    }

    private func saveNew(name: String, working: Int, target: Int) {
        guard !name.isEmpty else { return }
        let exercise = MetronomeExerciseBridge.capture(named: name, from: engine)
        exercise.currentTempo = working
        exercise.targetTempo = target
        // Keep an armed ramp climbing toward the chosen goal (ADR 0043 — ceiling tracks target).
        if exercise.automatorEnabled { exercise.automatorCeiling = target }
        context.insert(exercise)
        loadedExercise = exercise
        haptic(.medium)
    }

    private func commitUpdate() {
        guard let loaded = loadedExercise else { return }
        MetronomeExerciseBridge.update(loaded, from: engine)
        haptic(.medium)
    }

    private func leaveExercise() {
        engine.reset()
        loadedExercise = nil
        haptic(.medium)
    }
}
