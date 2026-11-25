import CertsCore
import SwiftUI
import UIKit

struct CertificationDetailView: View {
  let id: String
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var editing = false
  @State private var confirmDelete = false
  @State private var browser: IdentifiableURL?
  @State private var showPDF = false
  @State private var copied = false

  var body: some View {
    if let cert = model.certification(id) {
      content(cert)
    } else {
      ContentUnavailableView(L("certificationNotFound"), systemImage: "checkmark.seal")
    }
  }

  private func content(_ cert: Certification) -> some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text(cert.name).font(.title2.bold())
          Text(cert.provider).font(.headline).foregroundStyle(.secondary)
          if let status = statusLabel(cert) {
            Label(status.text, systemImage: status.symbol)
              .font(.subheadline.weight(.medium))
              .foregroundStyle(cert.statusColor)
              .padding(.top, 2)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
      }

      Section(L("dates")) {
        LabeledContent(L("earnDate"), value: dayText(cert.earnDate))
        LabeledContent(
          L("expirationDate"), value: cert.expirationDate.map(dayText) ?? L("noExpiration"))
        if cert.price > 0 {
          LabeledContent(L("price"), value: priceText(cert.price))
        }
      }

      if let url = cert.verificationURL {
        Section(L("verification")) {
          HStack {
            Button {
              browser = IdentifiableURL(url: url)
            } label: {
              Label(L("verifyCredential"), systemImage: "safari")
            }
            Spacer()
            Button {
              UIPasteboard.general.string = url.absoluteString
              copied = true
            } label: {
              Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
                .frame(minWidth: 28, minHeight: 28)
            }
            .accessibilityLabel(L("copyLink"))
            .sensoryFeedback(.success, trigger: copied) { _, new in new }
          }
          .buttonStyle(.borderless)
          Text(url.absoluteString)
            .font(.footnote).foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }

      if !cert.tags.isEmpty {
        Section(L("tags")) {
          FlowLayout(spacing: 8) {
            ForEach(cert.tags, id: \.self) { TagChip(tag: $0) }
          }
          .padding(.vertical, 4)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(cert.tags.joined(separator: ", "))
        }
      }

      if cert.pdfPath != nil {
        Section(L("certificatePDF")) {
          Button {
            showPDF = true
          } label: {
            Label(L("viewPDF"), systemImage: "doc.richtext")
          }
        }
      }

      Section {
        Button(L("deleteCertification"), role: .destructive) { confirmDelete = true }
          .frame(maxWidth: .infinity)
      }
    }
    .navigationTitle(cert.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) { Button(L("edit")) { editing = true } }
    }
    .task(id: copied) {
      guard copied else { return }
      try? await Task.sleep(for: .seconds(1.5))
      copied = false
    }
    .sheet(isPresented: $editing) { CertificationEditorView(existing: cert) }
    .sheet(isPresented: $showPDF) {
      FileViewerView(title: cert.name) {
        guard let url = try await model.repo?.pdfFile(for: cert) else { throw CocoaError(.fileNoSuchFile) }
        return url
      }
    }
    .fullScreenCover(item: $browser) { SafariView(url: $0.url).ignoresSafeArea() }
    .confirmationDialog(L("deleteCertificationTitle"), isPresented: $confirmDelete, titleVisibility: .visible) {
      Button(L("delete"), role: .destructive) {
        Task {
          if await model.delete(cert) { dismiss() }
        }
      }
    } message: {
      Text(L("deleteCertificationMessage", cert.name))
    }
  }

  private func statusLabel(_ cert: Certification) -> (text: String, symbol: String)? {
    switch cert.expirationStatus() {
    case .expired: (L("statusExpired"), "exclamationmark.octagon.fill")
    case .expiringSoon: (L("statusExpiringSoon"), "exclamationmark.triangle.fill")
    case .valid: (L("statusValid"), "checkmark.seal.fill")
    case .noExpiration: nil
    }
  }
}
