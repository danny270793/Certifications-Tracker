import Foundation

public enum CertificationSortField: String, CaseIterable, Identifiable, Sendable {
  case name, provider, earnDate, expirationDate
  public var id: String { rawValue }
}

public enum CertificationSortOrder: String, CaseIterable, Identifiable, Sendable {
  case ascending, descending
  public var id: String { rawValue }
}

public struct CertificationSort: Equatable, Sendable {
  public var field: CertificationSortField
  public var order: CertificationSortOrder

  /// Newest certification first.
  public init(field: CertificationSortField = .earnDate, order: CertificationSortOrder = .descending) {
    self.field = field
    self.order = order
  }
}

extension Array where Element == Certification {
  /// Sorts by the chosen field. Names and providers compare case- and accent-insensitively.
  /// Certifications that never expire always go last when sorting by expiration date.
  /// Ties fall back to the name, then to the earn date, so the order is stable.
  public func sorted(by sort: CertificationSort) -> [Certification] {
    let ascending = sort.order == .ascending
    return sorted { a, b in
      switch sort.field {
      case .name:
        let result = Self.compare(a.name, b.name)
        if result != .orderedSame { return (result == .orderedAscending) == ascending }
      case .provider:
        let result = Self.compare(a.provider, b.provider)
        if result != .orderedSame { return (result == .orderedAscending) == ascending }
      case .earnDate:
        if a.earnDate != b.earnDate { return (a.earnDate < b.earnDate) == ascending }
      case .expirationDate:
        switch (a.expirationDate, b.expirationDate) {
        case (nil, nil): break
        case (nil, _): return false
        case (_, nil): return true
        case let (x?, y?):
          if x != y { return (x < y) == ascending }
        }
      }
      let byName = Self.compare(a.name, b.name)
      if byName != .orderedSame { return byName == .orderedAscending }
      return a.earnDate > b.earnDate
    }
  }

  /// Keeps certifications whose name, provider or a tag contains every word of `query`.
  public func matching(_ query: String) -> [Certification] {
    let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
    guard !words.isEmpty else { return self }
    return filter { cert in
      let haystack = ([cert.name, cert.provider] + cert.tags).joined(separator: " ")
      return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
  }

  private static func compare(_ a: String, _ b: String) -> ComparisonResult {
    a.compare(b, options: [.caseInsensitive, .diacriticInsensitive, .numeric])
  }
}
