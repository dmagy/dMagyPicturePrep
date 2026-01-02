import Foundation

enum LooseYMD {

    static var gregorianUTC: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    static func dateFromPartsUTC(year: Int, month: Int, day: Int) -> Date? {
        var dc = DateComponents()
        dc.calendar = gregorianUTC
        dc.timeZone = gregorianUTC.timeZone
        dc.year = year
        dc.month = month
        dc.day = day
        return dc.date
    }

    static func endOfMonthUTC(year: Int, month: Int) -> Date? {
        guard let start = dateFromPartsUTC(year: year, month: month, day: 1) else { return nil }
        var comps = DateComponents()
        comps.month = 1
        comps.day = -1
        return gregorianUTC.date(byAdding: comps, to: start)
    }

    /// Existing: parse "YYYY-MM-DD" only (kept behavior)
    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = s.split(separator: "-", omittingEmptySubsequences: true)
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        return dateFromPartsUTC(year: y, month: m, day: d)
    }

    /// Interpret a loose date string as an inclusive date range.
    static func parseRange(_ raw: String?) -> (start: Date?, end: Date?) {
        guard let raw else { return (nil, nil) }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return (nil, nil) }

        // "start to end"
        if let r = s.range(of: " to ") {
            let left  = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let right = String(s[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let a = parseRange(left)
            let b = parseRange(right)
            return (a.start, b.end)
        }

        // Decade "1970s"
        if s.count == 5, s.hasSuffix("s"), let y = Int(s.prefix(4)) {
            return (
                dateFromPartsUTC(year: y, month: 1, day: 1),
                dateFromPartsUTC(year: y + 9, month: 12, day: 31)
            )
        }

        // Year range "1985-1986"
        if s.count == 9, s.contains("-") {
            let parts = s.split(separator: "-", omittingEmptySubsequences: true)
            if parts.count == 2,
               parts[0].count == 4, parts[1].count == 4,
               let y1 = Int(parts[0]), let y2 = Int(parts[1]) {
                return (
                    dateFromPartsUTC(year: y1, month: 1, day: 1),
                    dateFromPartsUTC(year: y2, month: 12, day: 31)
                )
            }
        }

        let parts = s.split(separator: "-", omittingEmptySubsequences: true)

        // YYYY-MM-DD
        if parts.count == 3,
           let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) {
            let date = dateFromPartsUTC(year: y, month: m, day: d)
            return (date, date)
        }

        // YYYY-MM
        if parts.count == 2,
           let y = Int(parts[0]), let m = Int(parts[1]) {
            let start = dateFromPartsUTC(year: y, month: m, day: 1)
            let end = endOfMonthUTC(year: y, month: m)
            return (start, end)
        }

        // YYYY
        if parts.count == 1, parts[0].count == 4, let y = Int(parts[0]) {
            return (
                dateFromPartsUTC(year: y, month: 1, day: 1),
                dateFromPartsUTC(year: y, month: 12, day: 31)
            )
        }

        return (nil, nil)
    }

    /// Birth date range from stored birth string
    /// - "1967-08-23" => exact day
    /// - "1970-06"    => month range
    /// - "1976"       => year range
    static func birthRange(_ birth: String?) -> (Date?, Date?) {
        guard let birth else { return (nil, nil) }
        let s = birth.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return (nil, nil) }

        let parts = s.split(separator: "-", omittingEmptySubsequences: true)

        if parts.count == 3,
           let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) {
            let date = dateFromPartsUTC(year: y, month: m, day: d)
            return (date, date)
        }

        if parts.count == 2,
           let y = Int(parts[0]), let m = Int(parts[1]) {
            return (
                dateFromPartsUTC(year: y, month: m, day: 1),
                endOfMonthUTC(year: y, month: m)
            )
        }

        if parts.count == 1, parts[0].count == 4, let y = Int(parts[0]) {
            return (
                dateFromPartsUTC(year: y, month: 1, day: 1),
                dateFromPartsUTC(year: y, month: 12, day: 31)
            )
        }

        return (nil, nil)
    }
}
