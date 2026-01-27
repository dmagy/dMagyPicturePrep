//
//  LooseYMD.swift
//  dMagy Picture Prep
//
//  cp-2026-01-17-04 — add strict validation helpers for numeric date formats
//
//  Purpose:
//  - Parse "loose" date strings into inclusive date ranges (existing behavior).
//  - Add *validation* so the UI can show red warnings for malformed numeric dates.
//  - IMPORTANT RULE (per Dan):
//      Only show red warnings for these accepted numeric formats:
//        - 1976-07-04   (YYYY-MM-DD)
//        - 1976-07      (YYYY-MM)
//        - 1976         (YYYY)
//        - 1970s        (Decade)
//        - 1975-1977    (Year range)
//        - 1975-12 to 1976-08   (Range using " to " with YYYY-MM / YYYY-MM-DD / YYYY / decade / year-range on each side)
//
//  We are NOT supporting "Summer 1984" etc. yet, so those should *not* trigger a warning
//  (they are simply treated as "unparsed", same as other free text).
//

import Foundation

enum LooseYMD {

    // [CAL] Calendar helpers

    static var gregorianUTC: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    // [CAL] Strict date creation (rejects normalized/out-of-range components)
    static func dateFromPartsUTC(year: Int, month: Int, day: Int) -> Date? {
        // Quick bounds check (calendar will do deeper validation below)
        guard year >= 1 else { return nil }
        guard (1...12).contains(month) else { return nil }
        guard (1...31).contains(day) else { return nil }

        var dc = DateComponents()
        dc.calendar = gregorianUTC
        dc.timeZone = gregorianUTC.timeZone
        dc.year = year
        dc.month = month
        dc.day = day

        // Calendar may "normalize" invalid inputs; we reject those by round-tripping.
        guard let date = gregorianUTC.date(from: dc) else { return nil }
        let roundTrip = gregorianUTC.dateComponents([.year, .month, .day], from: date)

        guard roundTrip.year == year,
              roundTrip.month == month,
              roundTrip.day == day
        else { return nil }

        return date
    }


    static func endOfMonthUTC(year: Int, month: Int) -> Date? {
        guard let start = dateFromPartsUTC(year: year, month: month, day: 1) else { return nil }
        var comps = DateComponents()
        comps.month = 1
        comps.day = -1
        return gregorianUTC.date(byAdding: comps, to: start)
    }

    // [PARSE] Existing: parse "YYYY-MM-DD" only (kept behavior)
    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = s.split(separator: "-", omittingEmptySubsequences: true)
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        return dateFromPartsUTC(year: y, month: m, day: d)
    }

    // [RANGE] Interpret a loose date string as an inclusive date range.
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

    // [BIRTH] Birth date range from stored birth string
    // - "1967-08-23" => exact day
    // - "1970-06"    => month range
    // - "1976"       => year range
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

    // =====================================================================
    // [DATEVAL] Strict validation helpers for numeric date formats
    // =====================================================================

    /// True if the string "looks like" one of the numeric formats we support.
    ///
    /// This is the key to your UI rule:
    /// - If it *doesn't* look like a supported numeric format, do NOT show red
    ///   (because it's probably free text / unhandled format).
    /// - If it *does* look like a supported numeric format, validate it strictly
    ///   and show red if invalid.
    static func shouldValidateNumericDateString(_ raw: String?) -> Bool {
        guard let raw else { return false }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }

        // Allow the explicit range operator you use: " to "
        if s.contains(" to ") {
            // We'll validate both sides individually in validation logic.
            return true
        }

        // Decade: "1970s"
        if s.count == 5, s.hasSuffix("s"), Int(s.prefix(4)) != nil {
            return true
        }

        // Year only: "1976"
        if s.count == 4, Int(s) != nil {
            return true
        }

        // Year range: "1975-1977" (exactly 9 chars, 4 digits, '-', 4 digits)
        if s.count == 9 {
            let parts = s.split(separator: "-", omittingEmptySubsequences: true)
            if parts.count == 2, parts[0].count == 4, parts[1].count == 4,
               Int(parts[0]) != nil, Int(parts[1]) != nil {
                return true
            }
        }

        // YYYY-MM or YYYY-MM-DD
        // Strict shape check: 7 chars => YYYY-MM, 10 chars => YYYY-MM-DD
        if s.count == 7 || s.count == 10 {
            let parts = s.split(separator: "-", omittingEmptySubsequences: true)
            if parts.count == 2 || parts.count == 3 {
                // Ensure year is 4 digits
                guard parts.first?.count == 4, Int(parts[0]) != nil else { return false }
                // Ensure month/day parts are 2 digits when present
                if parts.count >= 2, parts[1].count == 2, Int(parts[1]) != nil {
                    if parts.count == 2 { return true }
                    if parts.count == 3, parts[2].count == 2, Int(parts[2]) != nil { return true }
                }
            }
        }

        return false
    }

    /// Strictly validates a loose date string *only for the supported numeric formats*.
    ///
    /// Returns:
    /// - .valid: the string is a supported numeric format and is calendar-valid
    /// - .invalid: the string is a supported numeric format but is NOT valid
    /// - .notApplicable: the string is not a supported numeric format (no red warning)
    enum ValidationResult {
        case valid
        case invalid
        case notApplicable
    }

    static func validateNumericDateString(_ raw: String?) -> ValidationResult {
        guard shouldValidateNumericDateString(raw) else { return .notApplicable }
        guard let raw else { return .notApplicable }

        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return .notApplicable }

        // Range "left to right" => both sides must validate, AND left.start <= right.end
        if let r = s.range(of: " to ") {
            let left  = String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let right = String(s[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

            let leftRange = parseRange(left)
            let rightRange = parseRange(right)

            // If either side can't parse to a range, it's invalid (since it looked numeric)
            guard let leftStart = leftRange.start, let leftEnd = leftRange.end,
                  let rightStart = rightRange.start, let rightEnd = rightRange.end
            else { return .invalid }

            // Sanity: start <= end for each side (should already be true, but be defensive)
            guard leftStart <= leftEnd, rightStart <= rightEnd else { return .invalid }

            // Sanity: overall order should be left <= right (otherwise it's a bogus range)
            guard leftStart <= rightEnd else { return .invalid }

            return .valid
        }

        // For all other supported numeric formats, parseRange must succeed.
        let range = parseRange(s)

        guard let start = range.start, let end = range.end else {
            // Example: "1985-34-87" looks numeric, but parseRange returns nil/nil (good => invalid)
            return .invalid
        }

        // Extra check: ensure parseRange didn't produce something inverted
        guard start <= end else { return .invalid }

        return .valid
    }
}
