import CertsCore
import CertsData
import SwiftUI
import UniformTypeIdentifiers

struct CertificationEditorView: View {
  let existing: Certification?
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss

  @State private var name: String
  @State private var provider: String
  @State private var earnDate: Date
  @State private var hasExpiration: Bool
  @State private var expirationDate: Date
  @State private var link: String
  @State private var priceInput: String
  @State private var tags: [String]
  @State private var tagQuery = ""
  @State private var pdfData: Data?
  @State private var pdfName: String?
  @State private var pdfRemoved = false
  @State private var importing = false
  @State private var saving = false
  @State private var pdfError: String?

  private static let maxPDFBytes = 20 * 1024 * 1024

  init(existing: Certification?) {
    self.existing = existing
    _name = State(initialValue: existing?.name ?? "")
    _provider = State(initialValue: existing?.provider ?? "")
    _earnDate = State(initialValue: existing?.earnDate ?? Calendar.current.startOfDay(for: .now))
    _hasExpiration = State(initialValue: existing?.expirationDate != nil)
    _expirationDate = State(
      initialValue: existing?.expirationDate
        ?? Calendar.current.date(byAdding: .year, value: 3, to: existing?.earnDate ?? .now) ?? .now)
    _link = State(initialValue: existing?.verificationLink ?? "")
    _priceInput = State(initialValue: amountField(existing?.price ?? 0))
    _tags = State(initialValue: existing?.tags ?? [])
  }

  private var trimmedLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var linkIsValid: Bool { trimmedLink.isEmpty || Certification.validURL(trimmedLink) != nil }
  private var canSave: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && linkIsValid && parseAmount(priceInput) != nil && !saving
  }
  private var hasPDF: Bool { pdfData != nil || (existing?.pdfPath != nil && !pdfRemoved) }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent(L("name")) {
            TextField(L("namePlaceholder"), text: $name)
              .multilineTextAlignment(.trailing)
              .textInputAutocapitalization(.words)
          }
          LabeledContent(L("provider")) {
            TextField(L("providerPlaceholder"), text: $provider)
              .multilineTextAlignment(.trailing)
              .textInputAutocapitalization(.words)
          }
        }

        Section {
          DatePicker(L("earnDate"), selection: $earnDate, displayedComponents: .date)
          Toggle(L("hasExpiration"), isOn: $hasExpiration.animation())
          if hasExpiration {
            DatePicker(L("expirationDate"), selection: $expirationDate, in: earnDate..., displayedComponents: .date)
          }
          LabeledContent(L("price")) {
            TextField("0.00", text: $priceInput)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
        } header: {
          Text(L("dates"))
        } footer: {
          if parseAmount(priceInput) == nil {
            Text(L("invalidNumber")).foregroundStyle(.red)
          }
        }

        Section {
          VStack(alignment: .leading, spacing: 4) {
            Text(L("verificationLink")).font(.footnote).foregroundStyle(.secondary)
            TextField(L("linkPlaceholder"), text: $link)
              .keyboardType(.URL)
              .textContentType(.URL)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
          }
        } footer: {
          if !linkIsValid {
            Text(L("verificationLinkInvalid")).foregroundStyle(.red)
          }
        }

        Section(L("tags")) {
          TagPicker(tags: $tags, query: $tagQuery, known: model.knownTags)
        }

        Section {
          if hasPDF {
            HStack {
              Label(pdfName ?? L("pdfAttached"), systemImage: "doc.richtext.fill")
              Spacer()
              Button(role: .destructive) {
                pdfData = nil
                pdfName = nil
                pdfRemoved = existing?.pdfPath != nil
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .symbolRenderingMode(.hierarchical)
                  .font(.title3)
              }
              .buttonStyle(.borderless)
              .accessibilityLabel(L("removePDF"))
            }
          } else {
            Button { importing = true } label: { Label(L("attachPDF"), systemImage: "paperclip") }
          }
        } header: {
          Text(L("certificatePDF"))
        } footer: {
          if let pdfError { Text(pdfError).foregroundStyle(.red) }
        }
      }
      .navigationTitle(L(existing == nil ? "addCertification" : "editCertification"))
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
      .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
        loadPDF(result)
      }
      .interactiveDismissDisabled(saving)
    }
  }

  private func loadPDF(_ result: Result<URL, Error>) {
    pdfError = nil
    guard case .success(let url) = result else { return }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let data = try Data(contentsOf: url)
      guard data.count <= Self.maxPDFBytes else {
        pdfError = L("pdfTooLarge")
        return
      }
      pdfData = data
      pdfName = url.lastPathComponent
      pdfRemoved = false
    } catch {
      pdfError = L("pdfReadFailed")
    }
  }

  private func save() async {
    saving = true
    defer { saving = false }
    var cert =
      existing
      ?? Certification(name: "", provider: "", earnDate: earnDate)
    cert.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    cert.provider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
    cert.earnDate = earnDate
    cert.expirationDate = hasExpiration ? max(expirationDate, earnDate) : nil
    cert.verificationLink = trimmedLink.isEmpty ? nil : trimmedLink
    cert.price = parseAmount(priceInput) ?? 0
    // Text left in the tag field counts as a tag, so it is not lost on save.
    cert.tags = TagTools.normalized(tags + [tagQuery])
    let change: PDFChange =
      if let pdfData { .replace(pdfData) } else if pdfRemoved { .remove } else { .keep }
    if await model.save(cert, pdf: change) != nil { dismiss() }
  }
}
