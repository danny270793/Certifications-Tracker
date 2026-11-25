import CertsCore
import CertsData
import SwiftUI
import UniformTypeIdentifiers

struct CourseEditorView: View {
  let existing: Course?
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss

  @State private var name: String
  @State private var provider: String
  @State private var priceInput: String
  @State private var hoursInput: String
  @State private var earnDate: Date
  @State private var tags: [String]
  @State private var tagQuery = ""
  @State private var fileData: Data?
  @State private var fileName: String?
  @State private var fileExtension = "pdf"
  @State private var fileRemoved = false
  @State private var importing = false
  @State private var saving = false
  @State private var fileError: String?

  private static let maxFileBytes = 20 * 1024 * 1024

  init(existing: Course?) {
    self.existing = existing
    _name = State(initialValue: existing?.name ?? "")
    _provider = State(initialValue: existing?.provider ?? "")
    _priceInput = State(initialValue: amountField(existing?.price ?? 0))
    _hoursInput = State(initialValue: amountField(existing?.hours ?? 0))
    _earnDate = State(initialValue: existing?.earnDate ?? Calendar.current.startOfDay(for: .now))
    _tags = State(initialValue: existing?.tags ?? [])
  }

  private var price: Double? { parseAmount(priceInput) }
  private var hours: Double? { parseAmount(hoursInput) }
  private var canSave: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && price != nil && hours != nil && !saving
  }
  private var hasFile: Bool { fileData != nil || (existing?.filePath != nil && !fileRemoved) }

  /// Providers already used, filtered by what is typed, so the same name isn't spelled two ways.
  private var providerSuggestions: [String] {
    let typed = provider.trimmingCharacters(in: .whitespaces).lowercased()
    return model.knownProviders.filter { known in
      let lower = known.lowercased()
      return lower != typed && (typed.isEmpty || lower.contains(typed))
    }.prefix(6).map { $0 }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent(L("name")) {
            TextField(L("courseNamePlaceholder"), text: $name)
              .multilineTextAlignment(.trailing)
              .textInputAutocapitalization(.words)
          }
          LabeledContent(L("provider")) {
            TextField(L("courseProviderPlaceholder"), text: $provider)
              .multilineTextAlignment(.trailing)
              .textInputAutocapitalization(.words)
          }
          if !providerSuggestions.isEmpty {
            FlowLayout(spacing: 8) {
              ForEach(providerSuggestions, id: \.self) { suggestion in
                Button { provider = suggestion } label: { Text(suggestion).tagChip() }
                  .buttonStyle(.plain)
              }
            }
            .padding(.vertical, 2)
          }
        }

        Section {
          DatePicker(L("earnDate"), selection: $earnDate, displayedComponents: .date)
          LabeledContent(L("hours")) {
            TextField("0", text: $hoursInput)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
          LabeledContent(L("price")) {
            TextField("0.00", text: $priceInput)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
        } footer: {
          if price == nil || hours == nil {
            Text(L("invalidNumber")).foregroundStyle(.red)
          }
        }

        Section(L("tags")) {
          TagPicker(tags: $tags, query: $tagQuery, known: model.knownCourseTags)
        }

        Section {
          if hasFile {
            HStack {
              Label(fileName ?? L("fileAttached"), systemImage: "doc.richtext.fill")
              Spacer()
              Button(role: .destructive) {
                fileData = nil
                fileName = nil
                fileRemoved = existing?.filePath != nil
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .symbolRenderingMode(.hierarchical)
                  .font(.title3)
              }
              .buttonStyle(.borderless)
              .accessibilityLabel(L("removeFile"))
            }
          } else {
            Button { importing = true } label: { Label(L("attachFile"), systemImage: "paperclip") }
          }
        } header: {
          Text(L("courseFile"))
        } footer: {
          if let fileError { Text(fileError).foregroundStyle(.red) }
        }
      }
      .navigationTitle(L(existing == nil ? "addCourse" : "editCourse"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(L("cancel")) { dismiss() }.disabled(saving) }
        ToolbarItem(placement: .confirmationAction) {
          if saving {
            ProgressView()
          } else {
            Button(L("save")) { Task { await save() } }.disabled(!canSave)
          }
        }
      }
      .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .jpeg, .png]) { result in
        loadFile(result)
      }
      .interactiveDismissDisabled(saving)
    }
  }

  private func loadFile(_ result: Result<URL, Error>) {
    fileError = nil
    guard case .success(let url) = result else { return }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let data = try Data(contentsOf: url)
      guard data.count <= Self.maxFileBytes else {
        fileError = L("pdfTooLarge")
        return
      }
      let ext = url.pathExtension.lowercased()
      fileData = data
      fileName = url.lastPathComponent
      fileExtension = ext == "jpeg" ? "jpg" : (["jpg", "png"].contains(ext) ? ext : "pdf")
      fileRemoved = false
    } catch {
      fileError = L("pdfReadFailed")
    }
  }

  private func save() async {
    guard let price, let hours else { return }
    saving = true
    defer { saving = false }
    var course = existing ?? Course(name: "", provider: "", earnDate: earnDate)
    course.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    course.provider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
    course.price = price
    course.hours = hours
    course.earnDate = earnDate
    // Text left in the tag field counts as a tag, so it is not lost on save.
    course.tags = TagTools.normalized(tags + [tagQuery])
    let change: CourseFileChange =
      if let fileData { .replace(fileData, fileExtension: fileExtension) } else if fileRemoved { .remove } else { .keep }
    if await model.saveCourse(course, file: change) != nil { dismiss() }
  }
}
