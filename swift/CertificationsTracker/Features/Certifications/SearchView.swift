import CertsCore
import SwiftUI

/// The search tab: one field that looks through certifications and courses.
struct SearchView: View {
  @Environment(AppModel.self) private var model
  @State private var query = ""

  private var certifications: [Certification] {
    model.certifications.matching(query).sorted(by: model.sort)
  }

  private var courses: [Course] {
    model.courses.matching(query).sorted(by: model.courseSort)
  }

  var body: some View {
    content
      .navigationTitle(L("search"))
      .navigationDestination(for: String.self) { CertificationDetailView(id: $0) }
      .navigationDestination(for: CourseRoute.self) { CourseDetailView(id: $0.id) }
      .searchable(text: $query, prompt: L("searchPrompt"))
  }

  @ViewBuilder
  private var content: some View {
    if query.trimmingCharacters(in: .whitespaces).isEmpty {
      ContentUnavailableView(L("searchPrompt"), systemImage: "magnifyingglass")
    } else if certifications.isEmpty && courses.isEmpty {
      ContentUnavailableView.search(text: query)
    } else {
      List {
        if !certifications.isEmpty {
          Section(L("navCertifications")) {
            ForEach(certifications) { cert in
              NavigationLink(value: cert.id) { CertificationRow(certification: cert) }
            }
          }
        }
        if !courses.isEmpty {
          Section(L("navCourses")) {
            ForEach(courses) { course in
              NavigationLink(value: CourseRoute(id: course.id)) { CourseRow(course: course) }
            }
          }
        }
      }
    }
  }
}
