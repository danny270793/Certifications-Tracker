import CertsCore
import CertsData
import Foundation
import SwiftUI

/// Signed-in data for every tab. Writes update the in-memory list and Supabase.
@MainActor @Observable
final class AppModel {
  private(set) var repo: CertsRepository?
  private(set) var isSignedIn = false
  private(set) var certifications: [Certification] = []
  private(set) var courses: [Course] = []
  private(set) var fromCache = false
  private(set) var loading = false
  private(set) var loaded = false
  var loadError: String?
  var actionError: String?
  /// Shared by the list and search tabs. Newest earn date first by default.
  var sort = CertificationSort()
  var courseSort = CourseSort()

  init() {
    repo = CertsConfig.fromBundle().map { CertsRepository(config: $0) }
    isSignedIn = repo?.hasSession ?? false
    if let repo {
      Task { await observeAuth(repo) }
    }
  }

  private func observeAuth(_ repo: CertsRepository) async {
    for await (_, session) in repo.client.auth.authStateChanges {
      let signedIn = session != nil
      if signedIn != isSignedIn {
        isSignedIn = signedIn
        if !signedIn { clearList() }
      }
    }
  }

  /// Tags already in use, most used first. Feeds the suggestions while typing.
  var knownTags: [String] { TagTools.allTags(in: certifications) }

  var stats: CertificationStats { CertificationStats(certifications) }

  /// Tags already used by courses, most used first.
  var knownCourseTags: [String] { TagTools.allTags(of: courses.map(\.tags)) }

  /// Providers already used by courses, most used first.
  var knownProviders: [String] {
    var counts: [String: (shown: String, count: Int)] = [:]
    for course in courses {
      let name = course.provider.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { continue }
      let key = name.lowercased()
      counts[key] = (counts[key]?.shown ?? name, (counts[key]?.count ?? 0) + 1)
    }
    return counts.values.sorted { $0.count != $1.count ? $0.count > $1.count : $0.shown < $1.shown }.map(\.shown)
  }

  var courseStats: CourseStats { CourseStats(courses) }

  func course(_ id: String) -> Course? { courses.first { $0.id == id } }

  func certification(_ id: String) -> Certification? { certifications.first { $0.id == id } }

  func loadIfNeeded() async {
    guard isSignedIn, !loaded, !loading else { return }
    await reload()
  }

  func reload() async {
    guard let repo, isSignedIn, !loading else { return }
    loading = true
    defer { loading = false }
    do {
      let served = try await repo.certifications()
      certifications = served.value
      fromCache = served.fromCache
      loadError = nil
      loaded = true
    } catch {
      CertsLog.error("load failed", error)
      if !loaded { loadError = L("loadError") }
    }
    do {
      let served = try await repo.courses()
      courses = served.value
      fromCache = fromCache || served.fromCache
    } catch {
      CertsLog.error("load courses failed", error)
    }
  }

  func signIn(email: String, password: String) async throws {
    guard let repo else { throw CertsError.notConfigured }
    try await repo.signIn(email: email, password: password)
    isSignedIn = true
    loaded = false
    await reload()
  }

  func signOut() async {
    try? await repo?.signOut()
    isSignedIn = false
    clearList()
  }

  private func clearList() {
    certifications = []
    courses = []
    fromCache = false
    loaded = false
    loadError = nil
  }

  /// Saves the certification and its PDF change. Returns the stored row, or nil if it failed.
  func save(_ certification: Certification, pdf: PDFChange) async -> Certification? {
    guard let repo else { return nil }
    do {
      let saved = try await repo.save(certification, pdf: pdf)
      if let index = certifications.firstIndex(where: { $0.id == saved.id }) {
        certifications[index] = saved
      } else {
        certifications.append(saved)
      }
      return saved
    } catch {
      CertsLog.error("save certification", error)
      actionError = L("saveFailed")
      return nil
    }
  }

  @discardableResult
  func delete(_ certification: Certification) async -> Bool {
    guard let repo else { return false }
    do {
      try await repo.delete(certification)
      certifications.removeAll { $0.id == certification.id }
      return true
    } catch {
      CertsLog.error("delete certification", error)
      actionError = L("saveFailed")
      return false
    }
  }

  /// Saves the course and its file change. Returns the stored row, or nil if it failed.
  func saveCourse(_ course: Course, file: CourseFileChange) async -> Course? {
    guard let repo else { return nil }
    do {
      let saved = try await repo.saveCourse(course, file: file)
      if let index = courses.firstIndex(where: { $0.id == saved.id }) {
        courses[index] = saved
      } else {
        courses.append(saved)
      }
      return saved
    } catch {
      CertsLog.error("save course", error)
      actionError = L("saveFailed")
      return nil
    }
  }

  @discardableResult
  func deleteCourse(_ course: Course) async -> Bool {
    guard let repo else { return false }
    do {
      try await repo.deleteCourse(course)
      courses.removeAll { $0.id == course.id }
      return true
    } catch {
      CertsLog.error("delete course", error)
      actionError = L("saveFailed")
      return false
    }
  }
}
