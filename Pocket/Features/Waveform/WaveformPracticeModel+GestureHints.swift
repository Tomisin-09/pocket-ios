import Foundation

// MARK: - Hold tips (ADR 0244)

extension WaveformPracticeModel {

    /// Whether the song player is in a state a hold tip may show in, before `GestureHintPolicy` has
    /// its say (D5): the song has loaded and is not playing, and nothing else has the screen.
    ///
    /// - **Not while playing.** The player's hands are on the guitar and their eyes on the waveform;
    ///   a tag arriving mid-take is a distraction with nobody free to act on it. It comes back paused.
    /// - **Not beside the walkthrough's card**, nor in selection, range editing or setting the 1 — each
    ///   re-points the controls the tags describe, so the tag would be describing the wrong gesture.
    var gestureHintsCanShow: Bool {
        !isPreview && !isLoadingAudio && !audioLoadFailed && !engine.isPlaying
            && walkthrough == nil
            && !loopSelection.isActive && !markerSelection.isActive
            && !isRangeEditing && !isSettingDownbeat
    }

    /// The song's name was held, in either orientation, or VoiceOver asked for the same: its details,
    /// and the title's tip retired. One door here so the two title bars cannot disagree.
    func holdTitle() {
        AppSettings.retireGestureHint(.songTitle)
        showingSongDetails = true
    }
}
