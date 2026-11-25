import SwiftUI

struct MainTabView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    TabView {
      Tab(L("navCertifications"), systemImage: "checkmark.seal") {
        NavigationStack { CertificationsView() }
      }
      Tab(L("navCourses"), systemImage: "graduationcap") {
        NavigationStack { CoursesView() }
      }
      Tab(L("navDashboard"), systemImage: "chart.bar.xaxis") {
        NavigationStack { DashboardView() }
      }
      Tab(L("searchCertifications"), systemImage: "magnifyingglass", role: .search) {
        NavigationStack { SearchView() }
      }
    }
    .tabBarMinimizeBehavior(.onScrollDown)
    .task { await model.loadIfNeeded() }
  }
}

struct SettingsToolbar: ToolbarContent {
  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      NavigationLink {
        SettingsView()
      } label: {
        Image(systemName: "gearshape")
      }
      .accessibilityLabel(L("settings"))
    }
  }
}

struct OfflineHeader: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if model.fromCache {
      Label(L("offlineBanner"), systemImage: "icloud.slash")
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.tertiary.opacity(0.25))
    }
  }
}
