import CertsCore
import CertsData
import SwiftUI

/// Downloads a certificate file once and shows it: PDFs with PDFKit, scans as images.
struct FileViewerView: View {
  let title: String
  /// Returns the local copy of the file (downloading it if needed).
  let load: () async throws -> URL
  @Environment(\.dismiss) private var dismiss
  @State private var file: URL?
  @State private var failed = false

  var body: some View {
    NavigationStack {
      Group {
        if let file {
          if file.pathExtension.lowercased() == "pdf" {
            PDFKitView(url: file).ignoresSafeArea(edges: .bottom)
          } else if let image = UIImage(contentsOfFile: file.path) {
            ScrollView([.horizontal, .vertical]) {
              Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
            }
          } else {
            ContentUnavailableView(L("pdfLoadFailed"), systemImage: "doc.badge.ellipsis")
          }
        } else if failed {
          ContentUnavailableView {
            Label(L("pdfLoadFailed"), systemImage: "doc.badge.ellipsis")
          } actions: {
            Button(L("retry")) { Task { await fetch() } }.buttonStyle(.glassProminent)
          }
        } else {
          ProgressView()
        }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button(L("done")) { dismiss() } }
        if let file {
          ToolbarItem(placement: .primaryAction) { ShareLink(item: file) }
        }
      }
    }
    .task { await fetch() }
  }

  private func fetch() async {
    failed = false
    do {
      file = try await load()
    } catch {
      CertsLog.error("open file", error)
      failed = true
    }
  }
}
