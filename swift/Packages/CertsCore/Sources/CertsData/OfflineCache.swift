import CertsCore
import Foundation

public enum CertsLog {
  public static func debug(_ message: String) {
    #if DEBUG
      print("CertificationsTracker: \(message)")
    #endif
  }

  public static func error(_ message: String, _ error: Error? = nil) {
    if let error {
      print("CertificationsTracker error: \(message): \(error)")
    } else {
      print("CertificationsTracker error: \(message)")
    }
  }
}

/// True when the failure means the server could not be reached.
public func isOfflineError(_ error: Error) -> Bool {
  if let url = error as? URLError, offlineCodes.contains(url.code) { return true }
  let ns = error as NSError
  if ns.domain == NSURLErrorDomain, offlineCodes.contains(URLError.Code(rawValue: ns.code)) { return true }
  if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error { return isOfflineError(underlying) }
  let text = String(describing: error).lowercased()
  return text.contains("authretryablefetch") || text.contains("network connection")
}

private let offlineCodes: Set<URLError.Code> = [
  .notConnectedToInternet, .timedOut, .cannotFindHost, .cannotConnectToHost,
  .networkConnectionLost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
  .callIsActive, .secureConnectionFailed, .serverCertificateUntrusted, .cannotLoadFromNetwork,
]

public struct Served<T: Sendable>: Sendable {
  public var value: T
  public var fromCache: Bool
  public init(value: T, fromCache: Bool = false) {
    self.value = value
    self.fromCache = fromCache
  }
}

private struct Envelope<T: Codable>: Codable {
  var version: Int
  var data: T
}

/// JSON file cache, one folder per user:
/// `<Documents>/certifications_tracker/users/<userId>/cache_*.json` plus `pdfs/`.
public actor OfflineCache {
  public static let shared = OfflineCache()

  public static let certifications = "cache_certifications"
  public static let courses = "cache_courses"
  public static let version = 1

  private let root: URL

  public init(root: URL? = nil) {
    if let root {
      self.root = root
    } else {
      let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      self.root = docs.appendingPathComponent("certifications_tracker", isDirectory: true)
    }
  }

  public func userDirectory(_ userId: String) -> URL {
    root.appendingPathComponent("users", isDirectory: true).appendingPathComponent(userId, isDirectory: true)
  }

  public func pdfDirectory(_ userId: String) -> URL {
    userDirectory(userId).appendingPathComponent("pdfs", isDirectory: true)
  }

  private func file(_ userId: String, _ name: String) -> URL {
    userDirectory(userId).appendingPathComponent("\(name).json")
  }

  public func read<T: Codable>(_ type: T.Type, user: String, name: String) -> T? {
    guard let data = try? Data(contentsOf: file(user, name)) else { return nil }
    return (try? JSONDecoder().decode(Envelope<T>.self, from: data))?.data
  }

  public func write<T: Codable>(_ value: T, user: String, name: String) {
    do {
      try FileManager.default.createDirectory(at: userDirectory(user), withIntermediateDirectories: true)
      let data = try JSONEncoder().encode(Envelope(version: Self.version, data: value))
      try data.write(to: file(user, name), options: .atomic)
    } catch {
      CertsLog.error("offline cache write failed", error)
    }
  }

  /// Deletes the cached list and the downloaded PDFs of one user.
  public func clearCache(user: String) {
    let dir = userDirectory(user)
    let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    for url in urls where url.lastPathComponent.hasPrefix("cache_") {
      try? FileManager.default.removeItem(at: url)
    }
    try? FileManager.default.removeItem(at: pdfDirectory(user))
  }
}
