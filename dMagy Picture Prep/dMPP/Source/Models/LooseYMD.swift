import Foundation

// cp-2025-12-18-22(LooseYMD)
// Loose date parsing helpers used by dMPMS in dMPP.

enum LooseYMD {

    // MARK: - Public parse helpers

    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        // "start to end" -> start
        if let range = s.range(of: " to ") {
            let start = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            return parse(start)
        }

        // YYYYs (decade) -> take start
        if s.count == 5, s.hasSuffix("s") {
            let y = String(s.prefix(4))
            if Int(y) != nil { return dateFromParts(year: y, month: "01", day: "01") }
        }

        // YYYY-YYYY (year range) -> take start
        if s.count == 9, s.contains("-") {
            let parts = s.split(separator: "-", omittingEmptySubsequences: true)
            if parts.count == 2, parts[0].count == 4, Int(parts[0]) != nil {
                return dateFromParts(year: String(parts[0]), month: "01", day: "01")
            }
        }

        // YYYY-MM-DD or YYYY-MM or YYYY
        let parts = s.split(separator: "-", omittingEmptySubsequences: true)

        if parts.count == 3 {
            let y = String(parts[0]), m = String(parts[1]), d = String(parts[2])
            guard y.count == 4, Int(y) != nil else { return nil }
            return dateFromParts(year: y, month: m, day: d)
        }

        if parts.count == 2 {
            let y = String(parts[0]), m = String(parts[1])
            guard y.count == 4, Int(y) != nil else { return nil }
            return dateFromParts(year: y, month: m, day: "01")
        }

        if parts.count == 1 {
            let y = String(parts[0])
            if y.count == 4, Int(y) != nil {
                return dateFromParts(year: y, month: "01", day: "01")
            }
        }

        return nil
    }

    /// If the string is exactly "YYYY-MM", return the **end** of that month.
    /// This is useful when the user enters month precision and expects a single age.
    static func parseEndOfMonthIfMonthPrecision(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count == 7 else { return nil } // YYYY-MM

        let parts = s.split(separator: "-", omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }

        let y = Int(parts[0]) ?? 0
        let m = Int(parts[1]) ?? 0
        guard y > 0, (1...12).contains(m) else { return nil }

        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        comps.year = y
        comps.month = m
        comps.day = 1

        guard let startOfMonth = comps.date else { return nil }
        guard let startOfNextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth),
              let endOfMonth = Calendar.current.date(byAdding: .day, value: -1, to: startOfNextMonth)
        else { return nil }

        return endOfMonth
    }

    // cp-2025-12-18-22(BIRTH-RANGE)

    /// Interprets fuzzy birthdate strings as a date range.
    /// - "1970s" => 1970-01-01 ... 1979-12-31
    /// - "1976"  => 1976-01-01 ... 1976-12-31
    /// - "1976-03-17" => exact single day
    static func birthRange(_ raw: String?) -> (earliest: Date?, latest: Date?) {
        guard let raw else { return (nil, nil) }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return (nil, nil) }

        // Decade: "1970s"
        if s.count == 5, s.hasSuffix("s"), let y = Int(s.prefix(4)) {
            let start = dateFromParts(year: "\(y)", month: "01", day: "01")
            let end   = dateFromParts(year: "\(y + 9)", month: "12", day: "31")
            return (start, end)
        }

        // Year-only: "1976"
        if s.count == 4, let y = Int(s) {
            let start = dateFromParts(year: "\(y)", month: "01", day: "01")
            let end   = dateFromParts(year: "\(y)", month: "12", day: "31")
            return (start, end)
        }

        // Otherwise: treat parseable values as exact (single point)
        if let d = parse(s) {
            return (d, d)
        }

        return (nil, nil)
    }

    // MARK: - Private helpers

    private static func dateFromParts(year: String, month: String, day: String) -> Date? {
        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        comps.year = Int(year)
        comps.month = Int(month) ?? 1
        comps.day = Int(day) ?? 1
        return comps.date
    }
}
