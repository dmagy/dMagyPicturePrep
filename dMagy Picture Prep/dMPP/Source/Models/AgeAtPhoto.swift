import Foundation

enum AgeAtPhoto {

    // Stable calendar to avoid DST / locale surprises
    static var gregorianUTC: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    /// Returns age in whole years on `photoDate`, or nil if missing.
    /// Accepts `calendar:` so any existing call sites passing it will compile.
    static func yearsOld(on photoDate: Date?, birthDate: Date?, calendar: Calendar = gregorianUTC) -> Int? {
        guard let photoDate, let birthDate else { return nil }

        let b = calendar.dateComponents([.year, .month, .day], from: birthDate)
        let p = calendar.dateComponents([.year, .month, .day], from: photoDate)

        guard let by = b.year, let py = p.year else { return nil }

        let bm = b.month ?? 1
        let bd = b.day ?? 1
        let pm = p.month ?? 1
        let pd = p.day ?? 1

        var age = py - by

        // If birthday hasn't occurred yet this year, subtract 1.
        if (pm < bm) || (pm == bm && pd < bd) {
            age -= 1
        }

        // Guardrails
        if age < 0 { return nil }
        if age > 130 { return nil }
        return age
    }

    /// Age text for UI/JSON, based on photo range + birth range.
    /// youngest = photoStart - birthEnd
    /// oldest   = photoEnd   - birthStart
    static func ageText(photoStart: Date?, photoEnd: Date?, birthStart: Date?, birthEnd: Date?) -> String? {
        let end = photoEnd ?? photoStart

        let youngest = yearsOld(on: photoStart, birthDate: birthEnd)
        let oldest   = yearsOld(on: end,       birthDate: birthStart)

        guard let a0 = youngest, let a1 = oldest else { return nil }

        if a0 == a1 { return "\(a0)" }
        return "\(min(a0, a1))–\(max(a0, a1))"
    }
}
