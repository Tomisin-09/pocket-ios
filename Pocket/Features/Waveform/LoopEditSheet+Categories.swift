import SwiftUI

/// Edit loop's rows that open a screen (ADR 0258): **Range** in About, and the categories you open
/// rather than change in passing — **References**, **Works on & tags**, **Colour**. Each says what is
/// behind it, so the common visit ends on the sheet.
///
/// The screens edit the sheet's draft through bindings, so Cancel still takes back anything changed in
/// them; references are the exception they always were, written straight through.
extension LoopEditSheet {

    /// Where the loop sits, and the way to *How it got here* (ADR 0201) and to the waveform. Both of the
    /// screen's actions close this sheet, so they get this sheet's `dismiss`, not the pushed screen's.
    var rangeRow: some View {
        NavigationLink {
            LoopRangeScreen(loop: loop,
                            onAdjustRange: {
                                dismiss()
                                onAdjustRange()
                            },
                            onWiden: { start, end in
                                dismiss()
                                onWiden(start, end)
                            })
        } label: {
            LabeledContent("Range") {
                Text("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))")
                    .font(.pocketMono(.body))
            }
        }
    }

    var categoriesSection: some View {
        Section {
            referencesRow
            skillsRow
            colourRow
        }
    }

    private var referencesRow: some View {
        NavigationLink { ReferencesScreen(owner: loop, accent: PocketColor.practice) } label: {
            HubRow(icon: "link", title: "References", value: loop.referencesRowValue)
        }
    }

    private var skillsRow: some View {
        NavigationLink {
            LoopSkillsScreen(skillIDs: $skillIDs, tags: $tags, tagPool: tagPool, vocabulary: vocabulary)
        } label: {
            HubRow(icon: "scope", title: "Works on & tags", value: worksOnValue)
        }
    }

    /// The colour itself, not a word for it: the palette has no names, so the row shows the swatch,
    /// and says *Auto* when the colour follows the loop's place in the song (ADR 0031).
    private var colourRow: some View {
        NavigationLink { LoopColourScreen(autoColor: autoColor, choice: $colorChoice) } label: {
            HubRow(icon: "paintpalette", title: "Colour") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(colorChoice.color(auto: autoColor))
                        .frame(width: 14, height: 14)
                    if colorChoice == .auto {
                        Text("Auto").foregroundStyle(PocketColor.textSecondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(colorChoice.accessibilityName)
            }
        }
    }

    /// The skills the loop states, and the ones its tags carry, as Works on lists them — counted from
    /// the draft, so a change shows here before Done.
    private var worksOnValue: String {
        let stated = vocabulary.resolvable(skillIDs)
        let tagged = LoopSkillsScreen.taggedSkills(tags: tags, stated: stated)
        return DetailSheetText.worksOn(skills: stated.count + tagged.count, tags: tags.count)
    }
}
