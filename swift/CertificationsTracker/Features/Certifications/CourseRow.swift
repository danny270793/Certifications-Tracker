import CertsCore
import SwiftUI

/// ```
/// name          earn date
/// provider      hours
/// ```
struct CourseRow: View {
  let course: Course
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    Group {
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 4) {
          name
          provider
          earned
          hours
        }
      } else {
        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 2) {
          GridRow {
            name.frame(maxWidth: .infinity, alignment: .leading)
            earned.gridColumnAlignment(.trailing)
          }
          GridRow {
            provider.frame(maxWidth: .infinity, alignment: .leading)
            hours
          }
        }
      }
    }
    .padding(.vertical, 2)
    .accessibilityElement(children: .combine)
  }

  private var name: some View {
    Text(course.name).font(.headline).lineLimit(2)
  }

  private var provider: some View {
    Text(course.provider).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
  }

  private var earned: some View {
    Text(dayText(course.earnDate)).font(.subheadline).lineLimit(1)
  }

  private var hours: some View {
    Text(hoursText(course.hours)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
  }
}

struct CourseRoute: Hashable {
  let id: String
}
