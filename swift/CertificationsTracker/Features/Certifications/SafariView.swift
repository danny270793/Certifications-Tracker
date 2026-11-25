import PDFKit
import SafariServices
import SwiftUI

struct IdentifiableURL: Identifiable {
  let url: URL
  var id: URL { url }
}

/// The in-app browser (Safari View Controller) used for verification links.
struct SafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context: Context) -> SFSafariViewController {
    let config = SFSafariViewController.Configuration()
    config.entersReaderIfAvailable = false
    return SFSafariViewController(url: url, configuration: config)
  }

  func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct PDFKitView: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> PDFView {
    let view = PDFView()
    view.autoScales = true
    view.displayMode = .singlePageContinuous
    view.displayDirection = .vertical
    view.document = PDFDocument(url: url)
    return view
  }

  func updateUIView(_ view: PDFView, context: Context) {}
}
