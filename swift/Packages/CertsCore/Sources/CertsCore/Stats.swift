import Foundation

public struct CountItem: Identifiable, Hashable, Sendable {
  public var label: String
  public var count: Int
  public var id: String { label }

  public init(label: String, count: Int) {
    self.label = label
    self.count = count
  }
}

extension Array where Element == CountItem {
  /// Highest count first, then alphabetical.
  func sortedByCount() -> [CountItem] {
    sorted {
      if $0.count != $1.count { return $0.count > $1.count }
      return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
    }
  }
}

public struct CertificationStats: Sendable, Equatable {
  public var total: Int
  public var expiringSoon: Int
  public var expired: Int
  /// Sum of the prices.
  public var totalSpent: Double
  public var byTag: [CountItem]
  public var byProvider: [CountItem]

  public init(_ certifications: [Certification], now: Date = .now, calendar: Calendar = .current) {
    total = certifications.count
    var soon = 0
    var gone = 0
    for cert in certifications {
      switch cert.expirationStatus(now: now, calendar: calendar) {
      case .expiringSoon: soon += 1
      case .expired: gone += 1
      case .valid, .noExpiration: break
      }
    }
    expiringSoon = soon
    expired = gone
    totalSpent = certifications.reduce(0) { $0 + $1.price }
    byTag = TagTools.counts(of: certifications.flatMap { TagTools.normalized($0.tags) })

    // Providers are grouped ignoring case; the first spelling found is shown.
    var shown: [String: String] = [:]
    var table: [String: Int] = [:]
    for cert in certifications {
      let provider = cert.provider.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !provider.isEmpty else { continue }
      let key = provider.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
      shown[key] = shown[key] ?? provider
      table[key, default: 0] += 1
    }
    byProvider = table.map { CountItem(label: shown[$0.key] ?? $0.key, count: $0.value) }.sortedByCount()
  }
}
