import CertsCore
import Foundation
import Testing

@testable import CertsData

@Suite struct CacheTests {
  @Test func writesAndReadsPerUserAndClears() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("certs-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let cache = OfflineCache(root: root)
    let list = [
      Certification(
        name: "CKA", provider: "Linux Foundation", earnDate: CertsJSON.parseDay("2022-06-01")!, tags: ["kubernetes"])
    ]
    await cache.write(list, user: "u1", name: OfflineCache.certifications)
    let back = await cache.read([Certification].self, user: "u1", name: OfflineCache.certifications)
    #expect(back?.first?.name == "CKA")
    #expect(back?.first?.tags == ["kubernetes"])
    #expect(await cache.read([Certification].self, user: "u2", name: OfflineCache.certifications) == nil)
    await cache.clearCache(user: "u1")
    #expect(await cache.read([Certification].self, user: "u1", name: OfflineCache.certifications) == nil)
  }
}
