import CertsCore
import SwiftUI

/// Multi-select tags. Selected tags show as removable chips; while typing, existing tags
/// that match are offered, and a tag that does not exist yet can be created.
struct TagPicker: View {
  @Binding var tags: [String]
  @Binding var query: String
  /// Tags already used by other certifications, most used first.
  let known: [String]

  private var normalizedQuery: String { TagTools.normalize(query) }

  private var suggestions: [String] {
    TagTools.suggestions(for: query, known: known, selected: tags, limit: 10)
  }

  /// Offer to create the typed text when it is not an existing or selected tag.
  private var canCreate: Bool {
    !normalizedQuery.isEmpty && !known.contains(normalizedQuery) && !tags.contains(normalizedQuery)
  }

  var body: some View {
    if !tags.isEmpty {
      FlowLayout(spacing: 8) {
        ForEach(tags, id: \.self) { tag in
          Button {
            withAnimation(.snappy) { tags.removeAll { $0 == tag } }
          } label: {
            HStack(spacing: 4) {
              Text(tag)
              Image(systemName: "xmark.circle.fill").imageScale(.small).symbolRenderingMode(.hierarchical)
            }
            .tagChip(filled: true)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(tag)
          .accessibilityHint(L("removeTagHint"))
        }
      }
      .padding(.vertical, 4)
    }

    TextField(L("addTag"), text: $query)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .submitLabel(.done)
      .onSubmit { add(query) }

    if canCreate || !suggestions.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(L(normalizedQuery.isEmpty ? "popularTags" : "suggestions"))
          .font(.footnote).foregroundStyle(.secondary)
        FlowLayout(spacing: 8) {
          if canCreate {
            Button { add(query) } label: {
              Label(L("createTag", normalizedQuery), systemImage: "plus").tagChip(filled: false)
            }
            .buttonStyle(.plain)
          }
          ForEach(suggestions, id: \.self) { tag in
            Button { add(tag) } label: { Text(tag).tagChip() }
              .buttonStyle(.plain)
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func add(_ raw: String) {
    let tag = TagTools.normalize(raw)
    guard !tag.isEmpty else { return }
    withAnimation(.snappy) {
      tags = TagTools.normalized(tags + [tag])
      query = ""
    }
  }
}
