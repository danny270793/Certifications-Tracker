import CertsCore
import Foundation
import Supabase

public struct CertsConfig: Sendable {
  public var url: URL
  public var anonKey: String

  public init(url: URL, anonKey: String) {
    self.url = url
    self.anonKey = anonKey
  }

  public static func fromBundle(_ bundle: Bundle = .main) -> CertsConfig? {
    guard let path = bundle.path(forResource: "CertsConfig", ofType: "plist"),
      let dict = NSDictionary(contentsOfFile: path) as? [String: String],
      let raw = dict["SUPABASE_URL"], let url = URL(string: raw),
      let key = dict["SUPABASE_ANON_KEY"], !key.isEmpty, !raw.contains("xxxx")
    else { return nil }
    return CertsConfig(url: url, anonKey: key)
  }
}

public enum CertsError: LocalizedError {
  case notSignedIn
  case notConfigured

  public var errorDescription: String? {
    switch self {
    case .notSignedIn: "Not signed in"
    case .notConfigured: "Danny Certifications isn't configured"
    }
  }
}

/// What to do with the certification's PDF when saving.
public enum PDFChange: Sendable {
  case keep
  case replace(Data)
  case remove
}

/// What to do with a course's attached file (PDF, JPEG or PNG) when saving.
public enum CourseFileChange: Sendable {
  case keep
  /// `fileExtension` is "pdf", "jpg" or "png".
  case replace(Data, fileExtension: String)
  case remove
}

/// Reads and writes `cert_certifications` and the private `cert-pdfs` bucket. Reads fall
/// back to the on-device cache when the network is down. Writes need a connection.
public final class CertsRepository: Sendable {
  public let client: SupabaseClient
  let cache: OfflineCache

  static let table = "cert_certifications"
  static let coursesTable = "cert_courses"
  static let pdfBucket = "cert-pdfs"

  public init(config: CertsConfig, cache: OfflineCache = .shared) {
    self.cache = cache
    client = SupabaseClient(
      supabaseURL: config.url,
      supabaseKey: config.anonKey,
      options: SupabaseClientOptions(
        auth: .init(
          storage: KeychainLocalStorage(service: "io.github.danny270793.certificationstracker.auth"),
          emitLocalSessionAsInitialSession: true
        )
      )
    )
  }

  public var userId: String? { client.auth.currentUser?.id.uuidString.lowercased() }
  public var email: String? { client.auth.currentUser?.email }
  public var hasSession: Bool { client.auth.currentSession != nil }

  func requireUser() throws -> String {
    guard let userId else { throw CertsError.notSignedIn }
    return userId
  }

  // MARK: Session

  public func signIn(email: String, password: String) async throws {
    CertsLog.debug("signIn")
    try await client.auth.signIn(email: email, password: password)
  }

  public func signOut() async throws {
    let uid = userId
    try await client.auth.signOut()
    if let uid { await cache.clearCache(user: uid) }
  }

  public func updateEmail(_ email: String) async throws {
    try await client.auth.update(user: UserAttributes(email: email))
  }

  public func updatePassword(_ password: String) async throws {
    try await client.auth.update(user: UserAttributes(password: password))
  }

  // MARK: Certifications

  public func certifications() async throws -> Served<[Certification]> {
    let user = try requireUser()
    do {
      let rows: [Certification] = try await client.from(Self.table).select()
        .is("deletedAt", value: nil).order("earnDate", ascending: false).execute().value
      await cache.write(rows, user: user, name: OfflineCache.certifications)
      return Served(value: rows)
    } catch {
      if isOfflineError(error), let cached = await cache.read([Certification].self, user: user, name: OfflineCache.certifications) {
        CertsLog.debug("offline: \(cached.count) cached certifications")
        return Served(value: cached, fromCache: true)
      }
      throw error
    }
  }

  /// Inserts or updates a certification and applies the PDF change. Returns the saved row.
  public func save(_ certification: Certification, pdf: PDFChange = .keep) async throws -> Certification {
    let user = try requireUser()
    var cert = certification
    cert.tags = TagTools.normalized(cert.tags)
    cert.updatedAt = .now
    let previousPDF = cert.pdfPath

    switch pdf {
    case .keep:
      break
    case .replace(let data):
      let path = "\(user)/\(cert.id).pdf"
      try await client.storage.from(Self.pdfBucket).upload(
        path, data: data, options: FileOptions(contentType: "application/pdf", upsert: true))
      cert.pdfPath = path
      await removeLocalPDF(cert, user: user)
    case .remove:
      cert.pdfPath = nil
    }

    try await client.from(Self.table).upsert(CertificationWrite(cert, userId: user)).execute()

    if case .remove = pdf, let previousPDF {
      await removePDFs([previousPDF])
      await removeLocalPDF(cert, user: user)
    }

    var list = await cache.read([Certification].self, user: user, name: OfflineCache.certifications) ?? []
    if let index = list.firstIndex(where: { $0.id == cert.id }) { list[index] = cert } else { list.append(cert) }
    await cache.write(list, user: user, name: OfflineCache.certifications)
    return cert
  }

  public func delete(_ certification: Certification) async throws {
    let user = try requireUser()
    let now = CertsJSON.formatTimestamp(.now)
    try await client.from(Self.table).update(SoftDelete(deletedAt: now, updatedAt: now))
      .eq("id", value: certification.id).execute()
    var list = await cache.read([Certification].self, user: user, name: OfflineCache.certifications) ?? []
    list.removeAll { $0.id == certification.id }
    await cache.write(list, user: user, name: OfflineCache.certifications)
    if let path = certification.pdfPath {
      await removePDFs([path])
      await removeLocalPDF(certification, user: user)
    }
  }

  // MARK: Courses

  public func courses() async throws -> Served<[Course]> {
    let user = try requireUser()
    do {
      let rows: [Course] = try await client.from(Self.coursesTable).select()
        .is("deletedAt", value: nil).order("earnDate", ascending: false).execute().value
      await cache.write(rows, user: user, name: OfflineCache.courses)
      return Served(value: rows)
    } catch {
      if isOfflineError(error), let cached = await cache.read([Course].self, user: user, name: OfflineCache.courses) {
        CertsLog.debug("offline: \(cached.count) cached courses")
        return Served(value: cached, fromCache: true)
      }
      throw error
    }
  }

  /// Inserts or updates a course and applies the file change. Returns the saved row.
  public func saveCourse(_ course: Course, file: CourseFileChange = .keep) async throws -> Course {
    let user = try requireUser()
    var saved = course
    saved.tags = TagTools.normalized(saved.tags)
    saved.updatedAt = .now
    let previousFile = saved.filePath

    switch file {
    case .keep:
      break
    case .replace(let data, let ext):
      let clean = ext.lowercased() == "jpeg" ? "jpg" : ext.lowercased()
      let path = "\(user)/courses/\(saved.id).\(clean)"
      try await client.storage.from(Self.pdfBucket).upload(
        path, data: data, options: FileOptions(contentType: Self.contentType(for: clean), upsert: true))
      if let previousFile, previousFile != path { await removePDFs([previousFile]) }
      saved.filePath = path
      await removeLocalCourseFile(saved, user: user)
    case .remove:
      saved.filePath = nil
    }

    try await client.from(Self.coursesTable).upsert(CourseWrite(saved, userId: user)).execute()

    if case .remove = file, let previousFile {
      await removePDFs([previousFile])
      await removeLocalCourseFile(course, user: user)
    }

    var list = await cache.read([Course].self, user: user, name: OfflineCache.courses) ?? []
    if let index = list.firstIndex(where: { $0.id == saved.id }) { list[index] = saved } else { list.append(saved) }
    await cache.write(list, user: user, name: OfflineCache.courses)
    return saved
  }

  public func deleteCourse(_ course: Course) async throws {
    let user = try requireUser()
    let now = CertsJSON.formatTimestamp(.now)
    try await client.from(Self.coursesTable).update(SoftDelete(deletedAt: now, updatedAt: now))
      .eq("id", value: course.id).execute()
    var list = await cache.read([Course].self, user: user, name: OfflineCache.courses) ?? []
    list.removeAll { $0.id == course.id }
    await cache.write(list, user: user, name: OfflineCache.courses)
    if let path = course.filePath {
      await removePDFs([path])
      await removeLocalCourseFile(course, user: user)
    }
  }

  /// A local copy of the course's file, downloading it the first time.
  public func courseFile(for course: Course) async throws -> URL {
    let user = try requireUser()
    guard let path = course.filePath else { throw CertsError.notConfigured }
    let local = await localCourseFile(course, user: user)
    if FileManager.default.fileExists(atPath: local.path) { return local }
    let data = try await client.storage.from(Self.pdfBucket).download(path: path)
    try FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: local, options: .atomic)
    return local
  }

  private func localCourseFile(_ course: Course, user: String) async -> URL {
    let ext = course.fileExtension ?? "pdf"
    return await cache.pdfDirectory(user).appendingPathComponent("course-\(course.id).\(ext)")
  }

  private func removeLocalCourseFile(_ course: Course, user: String) async {
    try? FileManager.default.removeItem(at: await localCourseFile(course, user: user))
  }

  static func contentType(for ext: String) -> String {
    switch ext {
    case "jpg", "jpeg": "image/jpeg"
    case "png": "image/png"
    default: "application/pdf"
    }
  }

  // MARK: PDFs

  /// A local copy of the certification's PDF, downloading it the first time.
  public func pdfFile(for certification: Certification) async throws -> URL {
    let user = try requireUser()
    guard let path = certification.pdfPath else { throw CertsError.notConfigured }
    let local = await localPDF(certification, user: user)
    if FileManager.default.fileExists(atPath: local.path) { return local }
    let data = try await client.storage.from(Self.pdfBucket).download(path: path)
    try FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: local, options: .atomic)
    return local
  }

  private func localPDF(_ certification: Certification, user: String) async -> URL {
    await cache.pdfDirectory(user).appendingPathComponent("\(certification.id).pdf")
  }

  private func removeLocalPDF(_ certification: Certification, user: String) async {
    try? FileManager.default.removeItem(at: await localPDF(certification, user: user))
  }

  private func removePDFs(_ paths: [String]) async {
    do {
      try await client.storage.from(Self.pdfBucket).remove(paths: paths)
    } catch {
      CertsLog.error("failed to remove PDFs", error)
    }
  }
}

private struct SoftDelete: Encodable {
  var deletedAt: String
  var updatedAt: String
}

/// The columns the app writes. `createdAt` stays the database default.
private struct CertificationWrite: Encodable {
  var id: String
  var userId: String
  var name: String
  var provider: String
  var earnDate: String
  var expirationDate: String?
  var verificationUrl: String?
  var tags: [String]
  var pdfPath: String?
  var price: Double
  var updatedAt: String
  var deletedAt: String?

  init(_ cert: Certification, userId: String) {
    id = cert.id
    self.userId = userId
    name = cert.name.trimmingCharacters(in: .whitespacesAndNewlines)
    provider = cert.provider.trimmingCharacters(in: .whitespacesAndNewlines)
    earnDate = CertsJSON.formatDay(cert.earnDate)
    expirationDate = cert.expirationDate.map(CertsJSON.formatDay)
    let link = cert.verificationLink?.trimmingCharacters(in: .whitespacesAndNewlines)
    verificationUrl = (link?.isEmpty ?? true) ? nil : link
    tags = cert.tags
    pdfPath = cert.pdfPath
    price = cert.price
    updatedAt = CertsJSON.formatTimestamp(cert.updatedAt)
    deletedAt = nil
  }

  enum CodingKeys: String, CodingKey {
    case id, userId, name, provider, earnDate, expirationDate, verificationUrl, tags, pdfPath, price, updatedAt, deletedAt
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(userId, forKey: .userId)
    try c.encode(name, forKey: .name)
    try c.encode(provider, forKey: .provider)
    try c.encode(earnDate, forKey: .earnDate)
    try c.encode(expirationDate, forKey: .expirationDate)
    try c.encode(verificationUrl, forKey: .verificationUrl)
    try c.encode(tags, forKey: .tags)
    try c.encode(pdfPath, forKey: .pdfPath)
    try c.encode(price, forKey: .price)
    try c.encode(updatedAt, forKey: .updatedAt)
    try c.encode(deletedAt, forKey: .deletedAt)
  }
}

/// The columns the app writes for a course. `createdAt` stays the database default.
private struct CourseWrite: Encodable {
  var id: String
  var userId: String
  var name: String
  var provider: String
  var price: Double
  var earnDate: String
  var hours: Double
  var tags: [String]
  var filePath: String?
  var updatedAt: String
  var deletedAt: String?

  init(_ course: Course, userId: String) {
    id = course.id
    self.userId = userId
    name = course.name.trimmingCharacters(in: .whitespacesAndNewlines)
    provider = course.provider.trimmingCharacters(in: .whitespacesAndNewlines)
    price = course.price
    earnDate = CertsJSON.formatDay(course.earnDate)
    hours = course.hours
    tags = course.tags
    filePath = course.filePath
    updatedAt = CertsJSON.formatTimestamp(course.updatedAt)
    deletedAt = nil
  }

  enum CodingKeys: String, CodingKey {
    case id, userId, name, provider, price, earnDate, hours, tags, filePath, updatedAt, deletedAt
  }

  /// Writes explicit nulls so an upsert can clear the file.
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(userId, forKey: .userId)
    try c.encode(name, forKey: .name)
    try c.encode(provider, forKey: .provider)
    try c.encode(price, forKey: .price)
    try c.encode(earnDate, forKey: .earnDate)
    try c.encode(hours, forKey: .hours)
    try c.encode(tags, forKey: .tags)
    try c.encode(filePath, forKey: .filePath)
    try c.encode(updatedAt, forKey: .updatedAt)
    try c.encode(deletedAt, forKey: .deletedAt)
  }
}
