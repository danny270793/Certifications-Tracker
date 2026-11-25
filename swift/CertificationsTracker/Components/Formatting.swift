import CertsCore
import SwiftUI

/// "Jul 5, 2021" in the app's language.
func dayText(_ date: Date) -> String {
  date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale))
}

/// "$12.50" in the app's language. Prices are in US dollars.
func priceText(_ value: Double) -> String {
  value.formatted(.currency(code: "USD").locale(L10n.locale))
}

/// "12.5" / "8": at most one decimal.
func numberText(_ value: Double) -> String {
  value.formatted(.number.precision(.fractionLength(0...1)).locale(L10n.locale))
}

/// "12.5 h"
func hoursText(_ hours: Double) -> String { L("hoursShort", numberText(hours)) }

/// Parses what the user typed in a price or hours field. Empty means 0; nil means invalid.
func parseAmount(_ text: String) -> Double? {
  let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
  if trimmed.isEmpty { return 0 }
  guard let value = Double(trimmed), value >= 0, value < 1_000_000 else { return nil }
  return value
}

/// The plain text of a number for an edit field.
func amountField(_ value: Double) -> String { value == 0 ? "" : String(format: "%g", value) }

extension Certification {
  var statusColor: Color {
    switch expirationStatus() {
    case .expired: .red
    case .expiringSoon: .orange
    case .valid, .noExpiration: .secondary
    }
  }

  /// Just the expiration date, or "No expiration". Expired dates are shown in red.
  var expirationText: String {
    guard let expirationDate else { return L("noExpiration") }
    return dayText(expirationDate)
  }
}

/// A tag pill. `filled` is a selected tag, otherwise it is a soft suggestion.
struct TagChipStyle: ViewModifier {
  var filled = false

  func body(content: Content) -> some View {
    content
      .font(.subheadline)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .foregroundStyle(filled ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
      .background(filled ? AnyShapeStyle(.tint) : AnyShapeStyle(.tint.opacity(0.15)), in: .capsule)
  }
}

extension View {
  func tagChip(filled: Bool = false) -> some View { modifier(TagChipStyle(filled: filled)) }
}

struct TagChip: View {
  let tag: String

  var body: some View {
    Text(tag).tagChip()
  }
}

/// Wraps its children onto new lines, like text.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
    let width = proposal.width ?? rows.map(\.width).max() ?? 0
    let height = rows.map(\.height).reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * spacing
    return CGSize(width: width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in arrange(width: bounds.width, subviews: subviews) {
      var x = bounds.minX
      for item in row.items {
        subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
        x += item.size.width + spacing
      }
      y += row.height + spacing
    }
  }

  private struct Item {
    var index: Int
    var size: CGSize
  }

  private struct Row {
    var items: [Item] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = []
    var row = Row()
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
      let needed = row.items.isEmpty ? size.width : row.width + spacing + size.width
      if needed > width, !row.items.isEmpty {
        rows.append(row)
        row = Row()
      }
      row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
      row.height = max(row.height, size.height)
      row.items.append(Item(index: index, size: size))
    }
    if !row.items.isEmpty { rows.append(row) }
    return rows
  }
}
