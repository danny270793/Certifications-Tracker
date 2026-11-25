import CertsCore
import SwiftUI

struct CertificationsView: View {
  @Environment(AppModel.self) private var model
  @State private var adding = false
  @State private var pendingDelete: Certification?

  private var visible: [Certification] {
    model.certifications.sorted(by: model.sort)
  }

  var body: some View {
    content
      .navigationTitle(L("navCertifications"))
      .navigationSubtitle(L("sortedBy", sortLabel(model.sort.field)))
      .navigationDestination(for: String.self) { CertificationDetailView(id: $0) }
      .toolbar { toolbarContent }
      .safeAreaInset(edge: .top, spacing: 0) { OfflineHeader() }
      .sheet(isPresented: $adding) { CertificationEditorView(existing: nil) }
      .confirmationDialog(
        L("deleteCertificationTitle"), isPresented: showingDelete,
        titleVisibility: .visible, presenting: pendingDelete
      ) { cert in
        Button(L("delete"), role: .destructive) { Task { await model.delete(cert) } }
      } message: { cert in
        Text(L("deleteCertificationMessage", cert.name))
      }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    SettingsToolbar()
    ToolbarItem(placement: .primaryAction) { sortMenu }
    ToolbarItem(placement: .primaryAction) {
      Button { adding = true } label: { Image(systemName: "plus") }
        .accessibilityLabel(L("addCertification"))
    }
  }

  private var content: some View {
    Group {
      if !model.loaded && model.loadError == nil {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = model.loadError, model.certifications.isEmpty {
        ContentUnavailableView {
          Label(error, systemImage: "wifi.exclamationmark")
        } actions: {
          Button(L("retry")) { Task { await model.reload() } }.buttonStyle(.glassProminent)
        }
      } else if model.certifications.isEmpty {
        ContentUnavailableView {
          Label(L("noCertificationsTitle"), systemImage: "checkmark.seal")
        } description: {
          Text(L("noCertificationsBody"))
        } actions: {
          Button(L("addCertification")) { adding = true }.buttonStyle(.glassProminent)
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
      ForEach(visible) { cert in
        NavigationLink(value: cert.id) { CertificationRow(certification: cert) }
          .swipeActions(edge: .trailing) {
            Button(L("delete"), systemImage: "trash", role: .destructive) { pendingDelete = cert }
          }
      }
    }
    .refreshable { await model.reload() }
  }

  private var sortMenu: some View {
    @Bindable var model = model
    return Menu {
      Picker(L("sortBy"), selection: $model.sort.field) {
        ForEach(CertificationSortField.allCases) { Text(sortLabel($0)).tag($0) }
      }
      .pickerStyle(.inline)
      Picker(L("sortOrder"), selection: $model.sort.order) {
        ForEach(CertificationSortOrder.allCases) { Text(orderLabel($0, for: model.sort.field)).tag($0) }
      }
      .pickerStyle(.inline)
    } label: {
      Image(systemName: "arrow.up.arrow.down")
    }
    .accessibilityLabel(L("sortBy"))
  }
}

func sortLabel(_ field: CertificationSortField) -> String {
  switch field {
  case .name: L("name")
  case .provider: L("provider")
  case .earnDate: L("earnDate")
  case .expirationDate: L("expirationDate")
  }
}

func orderLabel(_ order: CertificationSortOrder, for field: CertificationSortField) -> String {
  switch (field, order) {
  case (.name, .ascending), (.provider, .ascending): L("orderAZ")
  case (.name, .descending), (.provider, .descending): L("orderZA")
  case (.earnDate, .ascending): L("orderOldest")
  case (.earnDate, .descending): L("orderNewest")
  case (.expirationDate, .ascending): L("orderSoonest")
  case (.expirationDate, .descending): L("orderLatest")
  }
}
