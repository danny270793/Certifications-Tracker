import Foundation

public enum TagTools {
  /// Lower-case, trimmed, with inner whitespace collapsed to one space.
  public static func normalize(_ raw: String) -> String {
    raw.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
  }

  /// Normalizes, drops empty labels and duplicates, keeps the first occurrence order.
  public static func normalized(_ tags: [String]) -> [String] {
    var seen = Set<String>()
    return tags.map(normalize).filter { !$0.isEmpty && seen.insert($0).inserted }
  }

  /// Every tag in use, most used first, then alphabetically.
  public static func allTags(in certifications: [Certification]) -> [String] {
    allTags(of: certifications.map(\.tags))
  }

  /// Same, for any list of tag lists (courses, ...).
  public static func allTags(of tagLists: [[String]]) -> [String] {
    counts(of: tagLists.flatMap { normalized($0) }).map(\.label)
  }

  /// Existing tags to offer while typing `query`: prefix matches first, then other
  /// matches, each group keeping the order of `known` (most used first). With an empty
  /// query it offers the first `limit` tags. Tags already `selected` are left out.
  public static func suggestions(
    for query: String, known: [String], selected: [String], limit: Int = 8
  ) -> [String] {
    let needle = normalize(query)
    let taken = Set(selected.map(normalize))
    let candidates = known.filter { !taken.contains($0) }
    guard !needle.isEmpty else { return Array(candidates.prefix(limit)) }
    let prefix = candidates.filter { $0.hasPrefix(needle) }
    let inside = candidates.filter { !$0.hasPrefix(needle) && $0.contains(needle) }
    return Array((prefix + inside).prefix(limit))
  }

  static func counts(of values: [String]) -> [CountItem] {
    var table: [String: Int] = [:]
    for value in values { table[value, default: 0] += 1 }
    return table.map { CountItem(label: $0.key, count: $0.value) }.sortedByCount()
  }
}
