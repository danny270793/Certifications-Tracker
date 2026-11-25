import Foundation

/// Date coding shared by Supabase and the offline cache.
/// `date` columns travel as `yyyy-MM-dd` and are read as the start of that day in the
/// device's time zone, so a day never shifts when it is shown. Timestamps are ISO 8601.
public enum CertsJSON {
  private static var calendar: Calendar { Calendar(identifier: .gregorian) }

  public static func formatDay(_ date: Date) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
  }

  public static func parseDay(_ raw: String) -> Date? {
    let parts = raw.prefix(10).split(separator: "-")
    guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
      return nil
    }
    return calendar.date(from: DateComponents(year: year, month: month, day: day))
  }

  public static func formatTimestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  public static func parseTimestamp(_ raw: String) -> Date? {
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = withFraction.date(from: raw) { return date }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    if let date = plain.date(from: raw) { return date }
    // Postgres may omit the fraction digits' precision or use a space instead of "T".
    let fixed = raw.replacingOccurrences(of: " ", with: "T")
    if fixed != raw { return parseTimestamp(fixed) }
    return nil
  }

  /// Postgres `numeric` normally arrives as a JSON number, but can be a string.
  public static func decodeNumber<K: CodingKey>(_ container: KeyedDecodingContainer<K>, forKey key: K) -> Double? {
    if let number = try? container.decodeIfPresent(Double.self, forKey: key) { return number }
    if let text = try? container.decodeIfPresent(String.self, forKey: key) { return Double(text) }
    return nil
  }
}
