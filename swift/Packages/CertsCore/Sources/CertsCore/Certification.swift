import Foundation

/// One certification. `earnDate` and `expirationDate` are whole days.
public struct Certification: Identifiable, Hashable, Sendable, Codable {
  public var id: String
  public var name: String
  public var provider: String
  public var earnDate: Date
  /// Nil when the certification does not expire.
  public var expirationDate: Date?
  public var verificationLink: String?
  /// Normalized labels (see ``TagTools/normalize(_:)``).
  public var tags: [String]
  /// Object path in the `cert-pdfs` bucket. Nil when no PDF was uploaded.
  public var pdfPath: String?
  /// What the certification cost. 0 by default.
  public var price: Double
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String = UUID().uuidString.lowercased(),
    name: String,
    provider: String,
    earnDate: Date,
    expirationDate: Date? = nil,
    verificationLink: String? = nil,
    tags: [String] = [],
    pdfPath: String? = nil,
    price: Double = 0,
    createdAt: Date = .now,
    updatedAt: Date = .now
  ) {
    self.id = id
    self.name = name
    self.provider = provider
    self.earnDate = earnDate
    self.expirationDate = expirationDate
    self.verificationLink = verificationLink
    self.tags = tags
    self.pdfPath = pdfPath
    self.price = price
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// The verification link when it is a usable http(s) URL.
  public var verificationURL: URL? {
    guard let link = verificationLink?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty else {
      return nil
    }
    return Certification.validURL(link)
  }

  public static func validURL(_ text: String) -> URL? {
    guard let url = URL(string: text), let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https", let host = url.host(), !host.isEmpty
    else { return nil }
    return url
  }

  // MARK: Coding (the column names of `cert_certifications`)

  enum CodingKeys: String, CodingKey {
    case id, name, provider, earnDate, expirationDate
    case verificationLink = "verificationUrl"
    case tags, pdfPath, price, createdAt, updatedAt
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? ""
    let earned = try c.decode(String.self, forKey: .earnDate)
    guard let earnedDay = CertsJSON.parseDay(earned) else {
      throw DecodingError.dataCorruptedError(forKey: .earnDate, in: c, debugDescription: "Bad date: \(earned)")
    }
    earnDate = earnedDay
    expirationDate = try c.decodeIfPresent(String.self, forKey: .expirationDate).flatMap(CertsJSON.parseDay)
    verificationLink = try c.decodeIfPresent(String.self, forKey: .verificationLink)
    tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    pdfPath = try c.decodeIfPresent(String.self, forKey: .pdfPath)
    price = CertsJSON.decodeNumber(c, forKey: .price) ?? 0
    createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt).flatMap(CertsJSON.parseTimestamp) ?? .now
    updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt).flatMap(CertsJSON.parseTimestamp) ?? .now
  }

  /// Writes every key, with explicit nulls, so an upsert can clear a field.
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encode(provider, forKey: .provider)
    try c.encode(CertsJSON.formatDay(earnDate), forKey: .earnDate)
    try c.encode(expirationDate.map(CertsJSON.formatDay), forKey: .expirationDate)
    try c.encode(verificationLink, forKey: .verificationLink)
    try c.encode(tags, forKey: .tags)
    try c.encode(pdfPath, forKey: .pdfPath)
    try c.encode(price, forKey: .price)
    try c.encode(CertsJSON.formatTimestamp(createdAt), forKey: .createdAt)
    try c.encode(CertsJSON.formatTimestamp(updatedAt), forKey: .updatedAt)
  }
}

public enum ExpirationStatus: Sendable, Equatable {
  case noExpiration
  case valid
  case expiringSoon
  case expired
}

extension Certification {
  /// How many days before the expiration date a certification counts as "expiring soon".
  public static let expiringSoonDays = 90

  public func expirationStatus(now: Date = .now, calendar: Calendar = .current) -> ExpirationStatus {
    guard let expirationDate else { return .noExpiration }
    let today = calendar.startOfDay(for: now)
    let expires = calendar.startOfDay(for: expirationDate)
    if expires < today { return .expired }
    let days = calendar.dateComponents([.day], from: today, to: expires).day ?? 0
    return days <= Self.expiringSoonDays ? .expiringSoon : .valid
  }
}
