import SwiftData
import SwiftUI

/// The drill a goal skill's fix makes (ADR 0216 D4): a type that works on the skill by default, or
/// a freeform block that **states** it. One value, and one sheet below, shared by both goal editors
/// so the two tiers can't offer different drills for the same skill.
struct SkillFixExercise: Equatable {
    let template: ExerciseTemplate
    /// The skills the new drill states. Empty for a type that works on the skill by default — it
    /// follows its type like any other drill. The skill itself for a freeform block.
    let statedSkillIDs: [String]

    init(template: ExerciseTemplate, statedSkillIDs: [String]) {
        self.template = template
        self.statedSkillIDs = statedSkillIDs
    }

    /// The drill for `fix`, tapped under `skillID` — `nil` for a fix that is a line of text.
    init?(fix: SkillAssociation.Fix, skillID: String) {
        switch fix {
        case .makeExercise(let template): self.init(template: template, statedSkillIDs: [])
        case .makeFreeform: self.init(template: .freeform, statedSkillIDs: [skillID])
        case .runLoopIn, .pickTargetSong: return nil
        }
    }
}

extension View {
    /// The create sheet a skill's fix opens — straight onto the configure step for the fix's type,
    /// made through the one insert path (ADR 0128). The skill's reach line updates when it lands.
    func skillFixSheet(_ request: Binding<SkillFixExercise?>, profile: Profile?,
                       context: ModelContext) -> some View {
        sheet(isPresented: Binding(get: { request.wrappedValue != nil },
                                   set: { if !$0 { request.wrappedValue = nil } })) {
            if let fix = request.wrappedValue {
                NewExerciseSheet(initialCommand: profile?.experience?.defaultCommandTempo
                                     ?? StandaloneMetronomeEngine.defaultCommandBPM,
                                 fixedTemplate: fix.template,
                                 defaultInstrument: profile?.preferredInstrument ?? .guitar,
                                 statedSkillIDs: fix.statedSkillIDs,
                                 onCreate: { $0.finalise(in: context) })
            }
        }
    }
}
