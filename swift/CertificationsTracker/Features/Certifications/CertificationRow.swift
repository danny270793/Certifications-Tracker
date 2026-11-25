import CertsCore
import SwiftUI

/// ```
/// name          earn date
/// provider      expiration date
/// ```
struct CertificationRow: View {
  let certification: Certification
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    Group {
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 4) {
          name
          provider
          earned
          expiration
        }
      } else {
        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 2) {
          GridRow {
            name.frame(maxWidth: .infinity, alignment: .leading)
            earned.gridColumnAlignment(.trailing)
          }
          GridRow {
            provider.frame(maxWidth: .infinity, alignment: .leading)
            expiration
          }
        }
      }
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
  }

  private var name: some View {
    Text(certification.name).font(.headline).lineLimit(2)
  }

  private var provider: some View {
    Text(certification.provider).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
  }

  private var earned: some View {
    Text(dayText(certification.earnDate)).font(.subheadline).lineLimit(1)
  }

  private var expiration: some View {
    Text(certification.expirationText)
      .font(.subheadline)
      .foregroundStyle(certification.statusColor)
      .lineLimit(1)
  }
}
