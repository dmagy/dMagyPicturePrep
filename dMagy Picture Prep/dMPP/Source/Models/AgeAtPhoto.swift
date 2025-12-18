import Foundation

// cp-2025-12-18-04(AGE)

struct AgeAtPhoto {

    // [AGE-POLICY]
    // Policy:
    // - Prefer exact dateTaken Date if you have it
    // - Else use dateRange.earliest (loose grammar: YYYY, YYYY-MM, YYYY-MM-DD, YYYYs, YYYY-YYYY, "start to end")
    // cp-2025-12-18-05(AGE-POLICY)
    static func effectivePhotoDate(dateTaken: Date?, dateRange: DmpmsDateRange?) -> Date? {
        if let dateTaken { return dateTaken }
        return LooseYMD.parse(dateRange?.earliest)
    }


    // [AGE-YEARS] Whole years old at the time of photo.
    static func yearsOld(on photoDate: Date?, birthDate: Date?, calendar: Calendar = .current) -> Int? {
        guard let photoDate, let birthDate else { return nil }
        guard birthDate <= photoDate else { return nil }

        let yearDelta = calendar.dateComponents([.year], from: birthDate, to: photoDate).year ?? 0

        // Adjust if birthday hasn't happened yet in the photo year
        var comps = calendar.dateComponents([.month, .day], from: birthDate)
        comps.year = calendar.component(.year, from: photoDate)

        if let birthdayThisYear = calendar.date(from: comps) {
            let hasHadBirthday = (photoDate >= birthdayThisYear)
            return hasHadBirthday ? yearDelta : max(0, yearDelta - 1)
        }

        return yearDelta
    }

    // MARK: - Loose date parsing (no String[Int] indexing)

    private static func parseLooseYMD(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        // "start to end" -> start
        if let range = s.range(of: " to ") {
            let start = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            return parseLooseYMD(start)
        }

        // YYYYs (decade)
        if s.count == 5, s.hasSuffix("s") {
            let y = String(s.prefix(4))
            if Int(y) != nil {
                return dateFromParts(year: y, month: "01", day: "01")
            }
        }

        // YYYY-YYYY (year range) -> take start year
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

    private static func dateFromParts(year: String, month: String, day: String) -> Date? {
        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = TimeZone(secondsFromGMT: 0) // stable, avoids DST oddities
        comps.year = Int(year)
        comps.month = Int(month) ?? 1
        comps.day = Int(day) ?? 1
        return comps.date
    }
}
