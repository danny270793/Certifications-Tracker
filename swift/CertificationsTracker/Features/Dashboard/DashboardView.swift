import CertsCore
import Charts
import SwiftUI

private enum DashboardMode: String, CaseIterable, Identifiable {
  case certifications, courses
  var id: String { rawValue }
  var title: String { L(self == .certifications ? "navCertifications" : "navCourses") }
}

struct DashboardView: View {
  @Environment(AppModel.self) private var model
  @State private var mode = DashboardMode.certifications
  @State private var expanded: Set<String> = []

  var body: some View {
    Group {
      if !model.loaded && model.loadError == nil {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          Section {
            Picker(L("navDashboard"), selection: $mode) {
              ForEach(DashboardMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
          }
          switch mode {
          case .certifications: certificationSections
          case .courses: courseSections
          }
        }
        .refreshable { await model.reload() }
      }
    }
    .navigationTitle(L("navDashboard"))
    .toolbar { SettingsToolbar() }
    .safeAreaInset(edge: .top, spacing: 0) { OfflineHeader() }
  }

  private func isExpanded(_ key: String) -> Binding<Bool> {
    Binding(
      get: { expanded.contains(key) },
      set: { if $0 { expanded.insert(key) } else { expanded.remove(key) } })
  }

  // MARK: Certifications

  @ViewBuilder
  private var certificationSections: some View {
    if model.certifications.isEmpty {
      Section { emptyState(L("dashboardEmptyBody")) }
    } else {
      let stats = model.stats
      Section {
        HStack {
          StatTile(value: numberText(Double(stats.total)), title: L("statTotal"), tint: .primary)
          StatTile(value: numberText(Double(stats.expiringSoon)), title: L("statusExpiringSoon"), tint: .orange)
          StatTile(value: numberText(Double(stats.expired)), title: L("statusExpired"), tint: .red)
          if stats.totalSpent > 0 {
            StatTile(value: priceText(stats.totalSpent), title: L("statSpent"), tint: .primary)
          }
        }
        .accessibilityElement(children: .combine)
      }
      Section(L("byTag")) {
        BarChart(
          items: stats.byTag.map { ChartItem(label: $0.label, value: Double($0.count)) },
          tint: .accentColor, expanded: isExpanded("cert-tag"), emptyText: L("noTagsYet"))
      }
      Section(L("byProvider")) {
        BarChart(
          items: stats.byProvider.map { ChartItem(label: $0.label, value: Double($0.count)) },
          tint: .indigo, expanded: isExpanded("cert-provider"), emptyText: nil)
      }
    }
  }

  // MARK: Courses

  @ViewBuilder
  private var courseSections: some View {
    if model.courses.isEmpty {
      Section { emptyState(L("dashboardEmptyCourses")) }
    } else {
      let stats = model.courseStats
      Section {
        HStack {
          StatTile(value: numberText(Double(stats.totalCourses)), title: L("navCourses"), tint: .primary)
          StatTile(value: numberText(stats.totalHours), title: L("hours"), tint: .accentColor)
          if stats.totalSpent > 0 {
            StatTile(value: priceText(stats.totalSpent), title: L("statSpent"), tint: .primary)
          }
        }
        .accessibilityElement(children: .combine)
      }
      Section(L("hoursByCategory")) {
        BarChart(
          items: stats.byTag.sortedByHours().map { ChartItem(label: $0.label, value: $0.hours) },
          tint: .accentColor, expanded: isExpanded("hours-tag"), emptyText: L("noTagsYet"), decimals: true)
      }
      Section(L("coursesByCategory")) {
        BarChart(
          items: stats.byTag.sortedByCourses().map { ChartItem(label: $0.label, value: Double($0.courses)) },
          tint: .teal, expanded: isExpanded("courses-tag"), emptyText: L("noTagsYet"))
      }
      Section(L("hoursByProvider")) {
        BarChart(
          items: stats.byProvider.sortedByHours().map { ChartItem(label: $0.label, value: $0.hours) },
          tint: .indigo, expanded: isExpanded("hours-provider"), emptyText: nil, decimals: true)
      }
      Section(L("coursesByProvider")) {
        BarChart(
          items: stats.byProvider.sortedByCourses().map { ChartItem(label: $0.label, value: Double($0.courses)) },
          tint: .purple, expanded: isExpanded("courses-provider"), emptyText: nil)
      }
    }
  }

  private func emptyState(_ text: String) -> some View {
    Text(text).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 24)
  }
}

private struct StatTile: View {
  let value: String
  let title: String
  let tint: Color

  var body: some View {
    VStack(spacing: 2) {
      Text(value).font(.title2.bold()).foregroundStyle(tint).monospacedDigit()
        .lineLimit(1).minimumScaleFactor(0.6)
      Text(title).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }
}

struct ChartItem: Identifiable, Hashable {
  var label: String
  var value: Double
  var id: String { label }
}

/// Horizontal bars, biggest first. Shows the top few with a toggle for the rest.
private struct BarChart: View {
  let items: [ChartItem]
  let tint: Color
  @Binding var expanded: Bool
  let emptyText: String?
  var decimals = false

  private static let collapsedCount = 8

  private var shown: [ChartItem] { expanded ? items : Array(items.prefix(Self.collapsedCount)) }

  private func valueText(_ value: Double) -> String {
    decimals ? numberText(value) : String(Int(value.rounded()))
  }

  var body: some View {
    if items.isEmpty {
      if let emptyText { Text(emptyText).foregroundStyle(.secondary) }
    } else {
      let maxValue = items.map(\.value).max() ?? 1
      Chart(shown) { item in
        BarMark(x: .value(L("certifications"), item.value), y: .value("", item.label))
          .foregroundStyle(tint.gradient)
          .cornerRadius(4)
          .annotation(position: .trailing, spacing: 4) {
            Text(valueText(item.value)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
          }
      }
      .chartYScale(domain: shown.map(\.label))
      .chartXScale(domain: 0...(maxValue * 1.18 + 0.5))
      .chartXAxis(.hidden)
      .chartYAxis {
        AxisMarks { _ in AxisValueLabel().font(.footnote) }
      }
      .frame(height: CGFloat(shown.count) * 34 + 8)
      .padding(.vertical, 4)

      if items.count > Self.collapsedCount {
        Button(expanded ? L("showLess") : L("showAll", items.count)) {
          withAnimation(.smooth) { expanded.toggle() }
        }
      }
    }
  }
}
