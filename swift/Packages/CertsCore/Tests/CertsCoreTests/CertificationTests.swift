import Foundation
import Testing

@testable import CertsCore

private func day(_ text: String) -> Date { CertsJSON.parseDay(text)! }

private func cert(
  _ name: String, provider: String = "Microsoft", earned: String = "2022-01-01", expires: String? = nil,
  tags: [String] = []
) -> Certification {
  Certification(
    name: name, provider: provider, earnDate: day(earned), expirationDate: expires.map(day), tags: tags)
}

@Suite struct SortingTests {
  let list = [
    cert("Terraform Associate", provider: "HashiCorp", earned: "2022-12-18", expires: "2024-12-18"),
    cert("Azure Fundamentals", provider: "Microsoft", earned: "2021-07-05"),
    cert("CKA", provider: "Linux Foundation", earned: "2022-06-01", expires: "2025-06-01"),
    cert("azure data fundamentals", provider: "microsoft", earned: "2021-12-30"),
  ]

  @Test func defaultIsEarnDateNewestFirst() {
    let names = list.sorted(by: CertificationSort()).map(\.name)
    #expect(names == ["Terraform Associate", "CKA", "azure data fundamentals", "Azure Fundamentals"])
  }

  @Test func nameIgnoresCase() {
    let names = list.sorted(by: .init(field: .name, order: .ascending)).map(\.name)
    #expect(names == ["Azure Fundamentals", "azure data fundamentals", "CKA", "Terraform Associate"].sorted {
      $0.compare($1, options: [.caseInsensitive]) == .orderedAscending
    })
    #expect(names.first == "azure data fundamentals")
    #expect(names.last == "Terraform Associate")
  }

  @Test func providerThenNameBreaksTies() {
    let names = list.sorted(by: .init(field: .provider, order: .ascending)).map(\.name)
    #expect(names == ["Terraform Associate", "CKA", "azure data fundamentals", "Azure Fundamentals"])
  }

  @Test func neverExpiringGoLastInBothDirections() {
    let up = list.sorted(by: .init(field: .expirationDate, order: .ascending)).map(\.name)
    let down = list.sorted(by: .init(field: .expirationDate, order: .descending)).map(\.name)
    #expect(Array(up.prefix(2)) == ["Terraform Associate", "CKA"])
    #expect(Array(down.prefix(2)) == ["CKA", "Terraform Associate"])
    #expect(Set(up.suffix(2)) == Set(["Azure Fundamentals", "azure data fundamentals"]))
    #expect(Set(down.suffix(2)) == Set(["Azure Fundamentals", "azure data fundamentals"]))
  }

  @Test func searchMatchesNameProviderAndTags() {
    let tagged = [cert("AZ-900", tags: ["cloud", "azure"]), cert("CKA", provider: "Linux Foundation")]
    #expect(tagged.matching("azure").map(\.name) == ["AZ-900"])
    #expect(tagged.matching("linux found").map(\.name) == ["CKA"])
    #expect(tagged.matching("  ").count == 2)
    #expect(tagged.matching("nothing").isEmpty)
  }
}

@Suite struct TagTests {
  @Test func normalizeTrimsLowercasesAndCollapses() {
    #expect(TagTools.normalize("  Cloud   Native ") == "cloud native")
    #expect(TagTools.normalized(["Azure", "azure ", " ", "Cloud"]) == ["azure", "cloud"])
  }

  @Test func suggestionsPutPrefixMatchesFirstAndSkipSelected() {
    let known = ["cloud", "azure", "database", "data governance", "aws"]
    #expect(TagTools.suggestions(for: "da", known: known, selected: [], limit: 8) == ["database", "data governance"])
    #expect(TagTools.suggestions(for: "ta", known: known, selected: [], limit: 8) == ["database", "data governance"])
    #expect(TagTools.suggestions(for: "a", known: known, selected: ["Azure"], limit: 8) == ["aws", "database", "data governance"])
    #expect(TagTools.suggestions(for: "", known: known, selected: ["cloud"], limit: 2) == ["azure", "database"])
    #expect(TagTools.suggestions(for: "zzz", known: known, selected: []).isEmpty)
  }

  @Test func allTagsMostUsedFirst() {
    let list = [
      cert("a", tags: ["cloud", "azure"]), cert("b", tags: ["Azure"]), cert("c", tags: ["database", "azure", "cloud"]),
    ]
    #expect(TagTools.allTags(in: list) == ["azure", "cloud", "database"])
  }
}

@Suite struct StatsTests {
  @Test func countsByTagAndProvider() {
    let list = [
      cert("a", provider: "Microsoft", tags: ["cloud", "azure"]),
      cert("b", provider: "microsoft", tags: ["azure"]),
      cert("c", provider: "AWS", tags: ["cloud"]),
      cert("d", provider: "", tags: []),
    ]
    let stats = CertificationStats(list)
    #expect(stats.total == 4)
    #expect(stats.byTag == [CountItem(label: "azure", count: 2), CountItem(label: "cloud", count: 2)])
    #expect(stats.byProvider == [CountItem(label: "Microsoft", count: 2), CountItem(label: "AWS", count: 1)])
  }

  @Test func expirationStatuses() {
    let now = day("2026-06-01")
    let calendar = Calendar(identifier: .gregorian)
    func status(_ expires: String?) -> ExpirationStatus {
      cert("x", expires: expires).expirationStatus(now: now, calendar: calendar)
    }
    #expect(status(nil) == .noExpiration)
    #expect(status("2026-05-31") == .expired)
    #expect(status("2026-06-01") == .expiringSoon)
    #expect(status("2026-08-30") == .expiringSoon)
    #expect(status("2026-09-15") == .valid)
    let stats = CertificationStats(
      [cert("a", expires: "2026-05-01"), cert("b", expires: "2026-07-01"), cert("c", expires: "2030-01-01"), cert("d")],
      now: now, calendar: calendar)
    #expect(stats.expired == 1)
    #expect(stats.expiringSoon == 1)
  }
}

@Suite struct CodingTests {
  @Test func roundTripKeepsDaysAndNulls() throws {
    let original = Certification(
      name: "CKA", provider: "Linux Foundation", earnDate: day("2022-06-01"), expirationDate: nil,
      verificationLink: "https://example.com/verify/1", tags: ["kubernetes"], pdfPath: "u/1.pdf")
    let data = try JSONEncoder().encode(original)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("\"earnDate\":\"2022-06-01\""))
    #expect(text.contains("\"expirationDate\":null"))
    let decoded = try JSONDecoder().decode(Certification.self, from: data)
    #expect(decoded.earnDate == original.earnDate)
    #expect(decoded.expirationDate == nil)
    #expect(decoded.verificationLink == original.verificationLink)
    #expect(decoded.tags == ["kubernetes"])
  }

  @Test func decodesPostgrestRow() throws {
    let json = """
      {"id":"7b1c","userId":"u","name":"AZ-900","provider":"Microsoft","earnDate":"2021-07-05",
       "expirationDate":null,"verificationUrl":null,"tags":["azure"],"pdfPath":null,
       "createdAt":"2026-11-24T12:30:00.123456+00:00","updatedAt":"2026-11-24T12:30:00+00:00","deletedAt":null}
      """
    let cert = try JSONDecoder().decode(Certification.self, from: Data(json.utf8))
    #expect(CertsJSON.formatDay(cert.earnDate) == "2021-07-05")
    #expect(cert.tags == ["azure"])
    #expect(cert.verificationURL == nil)
  }

  @Test func verificationURLNeedsHttp() {
    #expect(cert("a").verificationURL == nil)
    var c = cert("a")
    c.verificationLink = "ftp://x.com"
    #expect(c.verificationURL == nil)
    c.verificationLink = " https://www.credly.com/badges/1 "
    #expect(c.verificationURL?.host() == "www.credly.com")
  }
}
