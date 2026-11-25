import SwiftUI

@main
struct CertificationsTrackerApp: App {
  @State private var model = AppModel()
  @State private var prefs = Preferences()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
        .environment(prefs)
        .environment(\.locale, L10n.locale)
        .preferredColorScheme(prefs.theme.colorScheme)
        .id(prefs.language)
    }
  }
}
