import CertsCore
import SwiftUI

struct CourseDetailView: View {
  let id: String
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var editing = false
  @State private var confirmDelete = false
  @State private var showFile = false

  var body: some View {
    if let course = model.course(id) {
      content(course)
    } else {
      ContentUnavailableView(L("courseNotFound"), systemImage: "graduationcap")
    }
  }

  private func content(_ course: Course) -> some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text(course.name).font(.title2.bold())
          Text(course.provider).font(.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
      }

      Section(L("details")) {
        LabeledContent(L("earnDate"), value: dayText(course.earnDate))
        LabeledContent(L("hours"), value: hoursText(course.hours))
        LabeledContent(L("price"), value: priceText(course.price))
      }

      if !course.tags.isEmpty {
        Section(L("tags")) {
          FlowLayout(spacing: 8) {
            ForEach(course.tags, id: \.self) { TagChip(tag: $0) }
          }
          .padding(.vertical, 4)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(course.tags.joined(separator: ", "))
        }
      }

      if course.filePath != nil {
        Section(L("courseFile")) {
          Button {
            showFile = true
          } label: {
            Label(L("viewFile"), systemImage: course.fileExtension == "pdf" ? "doc.richtext" : "photo")
          }
        }
      }

      Section {
        Button(L("deleteCourse"), role: .destructive) { confirmDelete = true }
          .frame(maxWidth: .infinity)
      }
    }
    .navigationTitle(course.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) { Button(L("edit")) { editing = true } }
    }
    .sheet(isPresented: $editing) { CourseEditorView(existing: course) }
    .sheet(isPresented: $showFile) {
      FileViewerView(title: course.name) {
        guard let url = try await model.repo?.courseFile(for: course) else { throw CocoaError(.fileNoSuchFile) }
        return url
      }
    }
    .confirmationDialog(L("deleteCourseTitle"), isPresented: $confirmDelete, titleVisibility: .visible) {
      Button(L("delete"), role: .destructive) {
        Task {
          if await model.deleteCourse(course) { dismiss() }
        }
      }
    } message: {
      Text(L("deleteCourseMessage", course.name))
    }
  }
}
