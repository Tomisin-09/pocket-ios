import Foundation

/// A stable presentation identity for a SwiftData `@Model` driven through `.sheet(item:)` /
/// `.fullScreenCover(item:)`, keyed on the model's business `uid` rather than its
/// `persistentModelID`.
///
/// **Why this exists:** SwiftData's default `Identifiable` id (`persistentModelID`) is
/// *temporary* for a freshly `insert`ed model and flips to a permanent value on the next save
/// (autosave included). Binding a sheet directly to the model makes that flip read as an identity
/// change, so an autosave firing while the sheet is open dismisses it — the loop/marker edit sheet
/// "regenerating mid-edit" defect, only reproducible on loops created this session (older loops
/// already carry a permanent id). Wrapping the model in a `uid`-keyed ref keeps the sheet put; `uid`
/// is the stable business id introduced for exactly this reason (see `Loop.uid` / `Marker.uid`).
///
/// Used across features — loop/marker edit on the waveform, the planner goal editor, the routine
/// reps editor — i.e. any `@Model` that carries a `uid` and drives an edit sheet. Models that lack a
/// `uid` (e.g. `Song`) present by a `Bool` (`.sheet(isPresented:)`) instead — see `docs/swiftdata-gotchas.md`.
protocol UIDIdentified: AnyObject {
    var uid: UUID { get }
}

extension Loop: UIDIdentified {}
extension Marker: UIDIdentified {}
extension Goal: UIDIdentified {}
extension LongTermGoal: UIDIdentified {}
extension RoutineItem: UIDIdentified {}
extension Recording: UIDIdentified {}   // takes are renamed through a `StableRef` (ADR 0069 amendment)

/// `Identifiable` wrapper whose `id` is the wrapped model's stable `uid`.
struct StableRef<Model: UIDIdentified>: Identifiable {
    let value: Model
    var id: UUID { value.uid }
}

/// Identity **is** the `uid`, which is what the whole type exists to say — so equality and hashing
/// go through it and never through the wrapped model, whose own `persistentModelID` is the unstable
/// value this wrapper was written to route around.
///
/// Needed because `navigationDestination(item:)` requires `Hashable` where `.sheet(item:)` only
/// requires `Identifiable`, and takes are pushed rather than presented (ADR 0174).
extension StableRef: Hashable {
    static func == (lhs: StableRef<Model>, rhs: StableRef<Model>) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
