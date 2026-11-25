import CertsCore
import SwiftUI

struct CoursesView: View {
  @Environment(AppModel.self) private var model
  @State private var adding = false
  @State private var pendingDelete: Course?

  private var visible: [Course] { model.courses.sorted(by: model.courseSort) }

  var body: some View {
    content
      .navigationTitle(L("navCourses"))
      .navigationSubtitle(L("sortedBy", courseSortLabel(model.courseSort.field)))
      .navigationDestination(for: CourseRoute.self) { CourseDetailView(id: $0.id) }
      .toolbar { toolbarContent }
      .safeAreaInset(edge: .top, spacing: 0) { OfflineHeader() }
      .sheet(isPresented: $adding) { CourseEditorView(existing: nil) }
      .confirmationDialog(
        L("deleteCourseTitle"), isPresented: showingDelete, titleVisibility: .visible, presenting: pendingDelete
      ) { course in
        Button(L("delete"), role: .destructive) { Task { await model.deleteCourse(course) } }
      } message: { course in
        Text(L("deleteCourseMessage", course.name))
      }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    SettingsToolbar()
    ToolbarItem(placement: .primaryAction) { sortMenu }
    ToolbarItem(placement: .primaryAction) {
      Button { adding = true } label: { Image(systemName: "plus") }
        .accessibilityLabel(L("addCourse"))
    }
  }

  private var content: some View {
    Group {
      if !model.loaded && model.loadError == nil {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if model.courses.isEmpty {
        ContentUnavailableView {
          Label(L("noCoursesTitle"), systemImage: "graduationcap")
        } description: {
          Text(L("noCoursesBody"))
        } actions: {
          Button(L("addCourse")) { adding = true }.buttonStyle(.glassProminent)
        }
      } else {
        list
      }
    }
  }

  private var showingDelete: Binding<Bool> {
    Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
  }

  private var list: some View {
    List {
      ForEach(visible) { course in
        NavigationLink(value: CourseRoute(id: course.id)) { CourseRow(course: course) }
          .swipeActions(edge: .trailing) {
            Button(L("delete"), systemImage: "trash", role: .destructive) { pendingDelete = course }
          }
      }
    }
    .refreshable { await model.reload() }
  }

  private var sortMenu: some View {
    @Bindable var model = model
    return Menu {
      Picker(L("sortBy"), selection: $model.courseSort.field) {
        ForEach(CourseSortField.allCases) { Text(courseSortLabel($0)).tag($0) }
      }
      .pickerStyle(.inline)
      Picker(L("sortOrder"), selection: $model.courseSort.order) {
        ForEach(CertificationSortOrder.allCases) {
          Text(courseOrderLabel($0, for: model.courseSort.field)).tag($0)
        }
      }
      .pickerStyle(.inline)
    } label: {
      Image(systemName: "arrow.up.arrow.down")
    }
    .accessibilityLabel(L("sortBy"))
  }
}

func courseSortLabel(_ field: CourseSortField) -> String {
  switch field {
  case .name: L("name")
  case .provider: L("provider")
  case .earnDate: L("earnDate")
  case .hours: L("hours")
  case .price: L("price")
  }
}

func courseOrderLabel(_ order: CertificationSortOrder, for field: CourseSortField) -> String {
  switch (field, order) {
  case (.name, .ascending), (.provider, .ascending): L("orderAZ")
  case (.name, .descending), (.provider, .descending): L("orderZA")
  case (.earnDate, .ascending): L("orderOldest")
  case (.earnDate, .descending): L("orderNewest")
  case (.hours, .ascending), (.price, .ascending): L("orderLowest")
  case (.hours, .descending), (.price, .descending): L("orderHighest")
  }
}
