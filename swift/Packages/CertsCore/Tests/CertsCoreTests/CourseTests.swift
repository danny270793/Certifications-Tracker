import Foundation
import Testing

@testable import CertsCore

private func day(_ text: String) -> Date { CertsJSON.parseDay(text)! }

private func course(
  _ name: String, provider: String = "Udemy", earned: String = "2022-01-01", hours: Double = 1, price: Double = 0,
  tags: [String] = []
) -> Course {
  Course(name: name, provider: provider, price: price, earnDate: day(earned), hours: hours, tags: tags)
}

@Suite struct CourseTests {
  @Test func defaultSortIsMostRecentFirst() {
    let list = [course("a", earned: "2021-01-01"), course("b", earned: "2023-01-01"), course("c", earned: "2022-01-01")]
    #expect(list.sorted(by: CourseSort()).map(\.name) == ["b", "c", "a"])
  }

  @Test func sortsByHoursAndPrice() {
    let list = [course("a", hours: 5, price: 20), course("b", hours: 30, price: 0), course("c", hours: 12, price: 10)]
    #expect(list.sorted(by: .init(field: .hours, order: .descending)).map(\.name) == ["b", "c", "a"])
    #expect(list.sorted(by: .init(field: .price, order: .ascending)).map(\.name) == ["b", "c", "a"])
  }

  @Test func searchMatchesNameProviderAndTags() {
    let list = [course("Learning Go", provider: "LinkedIn Learning", tags: ["golang"]), course("Rust", tags: ["systems"])]
    #expect(list.matching("linkedin").map(\.name) == ["Learning Go"])
    #expect(list.matching("systems").map(\.name) == ["Rust"])
    #expect(list.matching("").count == 2)
  }

  @Test func statsGroupHoursAndCoursesByTagAndProvider() {
    let list = [
      course("a", provider: "Udemy", hours: 10, price: 15, tags: ["python", "data"]),
      course("b", provider: "udemy", hours: 2.5, price: 0, tags: ["python"]),
      course("c", provider: "LinkedIn Learning", hours: 4, tags: ["data"]),
    ]
    let stats = CourseStats(list)
    #expect(stats.totalCourses == 3)
    #expect(stats.totalHours == 16.5)
    #expect(stats.totalSpent == 15)
    #expect(stats.byTag == [CourseGroup(label: "python", courses: 2, hours: 12.5), CourseGroup(label: "data", courses: 2, hours: 14)].sortedByHours())
    #expect(stats.byProvider == [CourseGroup(label: "Udemy", courses: 2, hours: 12.5), CourseGroup(label: "LinkedIn Learning", courses: 1, hours: 4)])
    #expect(stats.byTag.sortedByCourses().first?.courses == 2)
  }

  @Test func roundTripAndFileExtension() throws {
    let original = Course(
      name: "Rust", provider: "Udemy", price: 12.5, earnDate: day("2021-11-23"), hours: 3.5, tags: ["rust"],
      filePath: "u/courses/1.PNG")
    let data = try JSONEncoder().encode(original)
    let back = try JSONDecoder().decode(Course.self, from: data)
    #expect(back.hours == 3.5 && back.price == 12.5 && back.tags == ["rust"])
    #expect(CertsJSON.formatDay(back.earnDate) == "2021-11-23")
    #expect(back.fileExtension == "png")
  }

  @Test func decodesNumericStrings() throws {
    let json = #"{"id":"1","name":"x","provider":"Udemy","price":"9.99","earnDate":"2022-02-02","hours":"7.5","tags":[],"filePath":null}"#
    let c = try JSONDecoder().decode(Course.self, from: Data(json.utf8))
    #expect(c.price == 9.99 && c.hours == 7.5)
  }

  @Test func certificationPriceDefaultsToZero() throws {
    let json = #"{"id":"1","name":"x","provider":"MS","earnDate":"2022-02-02","tags":[]}"#
    #expect(try JSONDecoder().decode(Certification.self, from: Data(json.utf8)).price == 0)
    let stats = CertificationStats([Certification(name: "a", provider: "p", earnDate: day("2022-01-01"), price: 99.5)])
    #expect(stats.totalSpent == 99.5)
  }
}
