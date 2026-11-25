import Foundation

/// A course taken (Udemy, LinkedIn Learning, ...). Kept apart from certifications.
public struct Course: Identifiable, Hashable, Sendable, Codable {
  public var id: String
  public var name: String
  /// Where it was taken: Udemy, LinkedIn Learning, ...
  public var provider: String
  public var price: Double
  public var earnDate: Date
  public var hours: Double
  public var tags: [String]
  /// Object path in the `cert-pdfs` bucket (`<userId>/courses/<id>.<ext>`). Nil when nothing was uploaded.
  public var filePath: String?
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String = UUID().uuidString.lowercased(),
    name: String,
    provider: String,
    price: Double = 0,
    earnDate: Date,
    hours: Double = 0,
    tags: [String] = [],
    filePath: String? = nil,
    createdAt: Date = .now,
    updatedAt: Date = .now
  ) {
    self.id = id
    self.name = name
    self.provider = provider
    self.price = price
    self.earnDate = earnDate
    self.hours = hours
    self.tags = tags
    self.filePath = filePath
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// "pdf", "jpg" or "png": the extension of the uploaded file.
  public var fileExtension: String? {
    filePath.map { ($0 as NSString).pathExtension.lowercased() }
  }

  enum CodingKeys: String, CodingKey {
    case id, name, provider, price, earnDate, hours, tags, filePath, createdAt, updatedAt
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? ""
    price = CertsJSON.decodeNumber(c, forKey: .price) ?? 0
    let earned = try c.decode(String.self, forKey: .earnDate)
    guard let day = CertsJSON.parseDay(earned) else {
      throw DecodingError.dataCorruptedError(forKey: .earnDate, in: c, debugDescription: "Bad date: \(earned)")
    }
    earnDate = day
    hours = CertsJSON.decodeNumber(c, forKey: .hours) ?? 0
    tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    filePath = try c.decodeIfPresent(String.self, forKey: .filePath)
    createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt).flatMap(CertsJSON.parseTimestamp) ?? .now
    updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt).flatMap(CertsJSON.parseTimestamp) ?? .now
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encode(provider, forKey: .provider)
    try c.encode(price, forKey: .price)
    try c.encode(CertsJSON.formatDay(earnDate), forKey: .earnDate)
    try c.encode(hours, forKey: .hours)
    try c.encode(tags, forKey: .tags)
    try c.encode(filePath, forKey: .filePath)
    try c.encode(CertsJSON.formatTimestamp(createdAt), forKey: .createdAt)
    try c.encode(CertsJSON.formatTimestamp(updatedAt), forKey: .updatedAt)
  }
}

public enum CourseSortField: String, CaseIterable, Identifiable, Sendable {
  case name, provider, earnDate, hours, price
  public var id: String { rawValue }
}

public struct CourseSort: Equatable, Sendable {
  public var field: CourseSortField
  public var order: CertificationSortOrder

  /// Most recent course first.
  public init(field: CourseSortField = .earnDate, order: CertificationSortOrder = .descending) {
    self.field = field
    self.order = order
  }
}

extension Array where Element == Course {
  /// Ties fall back to the name, then to the earn date, so the order is stable.
  public func sorted(by sort: CourseSort) -> [Course] {
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
      case .hours:
        if a.hours != b.hours { return (a.hours < b.hours) == ascending }
      case .price:
        if a.price != b.price { return (a.price < b.price) == ascending }
      }
      let byName = Self.compare(a.name, b.name)
      if byName != .orderedSame { return byName == .orderedAscending }
      return a.earnDate > b.earnDate
    }
  }

  /// Keeps courses whose name, provider or a tag contains every word of `query`.
  public func matching(_ query: String) -> [Course] {
    let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
    guard !words.isEmpty else { return self }
    return filter { course in
      let haystack = ([course.name, course.provider] + course.tags).joined(separator: " ")
      return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
  }

  private static func compare(_ a: String, _ b: String) -> ComparisonResult {
    a.compare(b, options: [.caseInsensitive, .diacriticInsensitive, .numeric])
  }
}

/// Courses and hours of one tag or one provider.
public struct CourseGroup: Identifiable, Hashable, Sendable {
  public var label: String
  public var courses: Int
  public var hours: Double
  public var id: String { label }

  public init(label: String, courses: Int, hours: Double) {
    self.label = label
    self.courses = courses
    self.hours = hours
  }
}

extension Array where Element == CourseGroup {
  /// Most hours first, then most courses, then alphabetical.
  public func sortedByHours() -> [CourseGroup] {
    sorted {
      if $0.hours != $1.hours { return $0.hours > $1.hours }
      if $0.courses != $1.courses { return $0.courses > $1.courses }
      return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
    }
  }

  /// Most courses first, then most hours, then alphabetical.
  public func sortedByCourses() -> [CourseGroup] {
    sorted {
      if $0.courses != $1.courses { return $0.courses > $1.courses }
      if $0.hours != $1.hours { return $0.hours > $1.hours }
      return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
    }
  }
}

public struct CourseStats: Sendable, Equatable {
  public var totalCourses: Int
  public var totalHours: Double
  public var totalSpent: Double
  /// By tag ("category"), most hours first. A course counts once for each of its tags.
  public var byTag: [CourseGroup]
  /// By provider, most hours first. Providers are grouped ignoring case.
  public var byProvider: [CourseGroup]

  public init(_ courses: [Course]) {
    totalCourses = courses.count
    totalHours = courses.reduce(0) { $0 + $1.hours }
    totalSpent = courses.reduce(0) { $0 + $1.price }

    var tagTable: [String: (courses: Int, hours: Double)] = [:]
    for course in courses {
      for tag in TagTools.normalized(course.tags) {
        let current = tagTable[tag] ?? (0, 0)
        tagTable[tag] = (current.courses + 1, current.hours + course.hours)
      }
    }
    byTag = tagTable.map { CourseGroup(label: $0.key, courses: $0.value.courses, hours: $0.value.hours) }
      .sortedByHours()

    var shown: [String: String] = [:]
    var providerTable: [String: (courses: Int, hours: Double)] = [:]
    for course in courses {
      let provider = course.provider.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !provider.isEmpty else { continue }
      let key = provider.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
      shown[key] = shown[key] ?? provider
      let current = providerTable[key] ?? (0, 0)
      providerTable[key] = (current.courses + 1, current.hours + course.hours)
    }
    byProvider = providerTable.map {
      CourseGroup(label: shown[$0.key] ?? $0.key, courses: $0.value.courses, hours: $0.value.hours)
    }.sortedByHours()
  }
}
