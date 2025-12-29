//
//  DmpmsMetadata.swift
//  dMagy Picture Prep
//

import Foundation

// dMPMS-2025-12-XX-M3 — Core metadata models (+ human-facing notice + date ranges + peopleV2 + location)

/* [DMPMS-DATERANGE] Machine-friendly date range derived from `dateTaken`. */
struct DmpmsDateRange: Codable, Hashable {
    /// Earliest possible date this photo could reasonably be from (YYYY-MM-DD).
    var earliest: String
    /// Latest possible date this photo could reasonably be from (YYYY-MM-DD).
    var latest: String

    /// Build a DmpmsDateRange from a human-entered `dateTaken` string.
    /// Supported patterns:
    /// - "YYYY-MM-DD"
    /// - "YYYY-MM"
    /// - "YYYY"
    /// - "YYYYs"  (e.g., "1930s" → 1930-01-01 .. 1939-12-31)
    /// - "YYYY-YYYY" (e.g., "1930-1931" → 1930-01-01 .. 1931-12-31)
    static func from(dateTaken raw: String) -> DmpmsDateRange? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Normalize a human-friendly "YYYY-MM to YYYY-MM" into "YYYY-MM-YYYY-MM"
        let normalized = trimmed.replacingOccurrences(of: " to ", with: "-")
        let parts = normalized.split(separator: "-")

        // 0) Month range: YYYY-MM-YYYY-MM
        if parts.count == 4,
           let startYear = Int(parts[0]),
           let startMonth = Int(parts[1]),
           let endYear = Int(parts[2]),
           let endMonth = Int(parts[3]),
           (1...12).contains(startMonth),
           (1...12).contains(endMonth),
           (startYear < endYear || (startYear == endYear && startMonth <= endMonth)) {

            let earliest = String(format: "%04d-%02d-01", startYear, startMonth)
            let lastDay  = lastDayOfMonth(year: endYear, month: endMonth)
            let latest   = String(format: "%04d-%02d-%02d", endYear, endMonth, lastDay)
            return DmpmsDateRange(earliest: earliest, latest: latest)
        }

        // 1) Full date: YYYY-MM-DD
        if parts.count == 3,
           let year = Int(parts[0]),
           let month = Int(parts[1]),
           let day = Int(parts[2]),
           (1...12).contains(month),
           (1...31).contains(day) {
            let dateStr = String(format: "%04d-%02d-%02d", year, month, day)
            return DmpmsDateRange(earliest: dateStr, latest: dateStr)
        }

        // 2) Explicit year range: YYYY-YYYY
        if parts.count == 2,
           parts[0].count == 4,
           parts[1].count == 4,
           let startYear = Int(parts[0]),
           let endYear = Int(parts[1]),
           startYear <= endYear {
            let earliest = String(format: "%04d-01-01", startYear)
            let latest   = String(format: "%04d-12-31", endYear)
            return DmpmsDateRange(earliest: earliest, latest: latest)
        }

        // 3) Year-month: YYYY-MM
        if parts.count == 2,
           let year = Int(parts[0]),
           let month = Int(parts[1]),
           (1...12).contains(month) {
            let earliest = String(format: "%04d-%02d-01", year, month)
            let lastDay  = lastDayOfMonth(year: year, month: month)
            let latest   = String(format: "%04d-%02d-%02d", year, month, lastDay)
            return DmpmsDateRange(earliest: earliest, latest: latest)
        }

        // 4) Year only: YYYY
        if normalized.count == 4, let year = Int(normalized) {
            let earliest = String(format: "%04d-01-01", year)
            let latest   = String(format: "%04d-12-31", year)
            return DmpmsDateRange(earliest: earliest, latest: latest)
        }

        // 5) Decade: "1930s" → 1930-01-01 .. 1939-12-31
        if normalized.count == 5,
           normalized.hasSuffix("s") {
            let decadeString = normalized.prefix(4)
            if let startYear = Int(decadeString) {
                let earliest = String(format: "%04d-01-01", startYear)
                let latest   = String(format: "%04d-12-31", startYear + 9)
                return DmpmsDateRange(earliest: earliest, latest: latest)
            }
        }

        // Anything else → we keep the raw dateTaken but do NOT generate a range.
        return nil
    }

    private static func lastDayOfMonth(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let calendar = Calendar(identifier: .gregorian)
        if let date = calendar.date(from: comps),
           let range = calendar.range(of: .day, in: .month, for: date) {
            return range.count
        }
        return 31
    }
}

/* [DMPMS-META] Complete dMPMS metadata structure. */
struct DmpmsMetadata: Codable, Hashable {

    /// Default human-readable warning written into every sidecar.
    /// Intent: gently tell humans not to delete the file.
    static let defaultNotice = """
    Created by dMagy Picture Prep. Stores metadata and crop settings for this photo. Deleting it erases edits (not the original image).
    """

    // Core version for the dMPMS spec.
    var dmpmsVersion: String = "1.1"

    /// Human-facing notice so people know what this file is.
    /// Always included near the top of the JSON.
    var dmpmsNotice: String = DmpmsMetadata.defaultNotice

    /// Image filename (with extension) this sidecar belongs to.
    var sourceFile: String

    // Basic fields
    var title: String = ""
    var description: String = ""

    /// Human-entered date/era string.
    /// Examples: "1973-08-10", "1973-08", "1973", "1970s", "1930-1931"
    var dateTaken: String = ""

    /// Machine-friendly range derived from `dateTaken` when possible.
    /// Nil if parsing fails or the format is too fuzzy.
    var dateRange: DmpmsDateRange? = nil

    /// Raw GPS coordinates captured from the file (if present).
    var gps: DmpmsGPS? = nil

    /// Editable human-readable location snapshot (address parts).
    var location: DmpmsLocation? = nil

    var tags: [String] = []

    /// Legacy flat list of people names.
    /// Retained for simple/older workflows.
    var people: [String] = []

    /// v1.1+ rich people metadata.
    /// Each entry represents a specific person in this photo
    /// (identity ID, display name snapshot, age-at-photo, row/position, etc.).
    var peopleV2: [DmpmsPersonInPhoto] = []

    // cp-2025-12-19-PS2(METADATA-ADD-SNAPSHOTS)
    var peopleV2Snapshots: [DmpmsPeopleSnapshot] = []

    // Crops + history
    var virtualCrops: [VirtualCrop] = []
    var history: [HistoryEvent] = []

    // Explicit key order for encoding/decoding.
    // JSONEncoder (without .sortedKeys) will follow this order.
    enum CodingKeys: String, CodingKey {
        case dmpmsVersion
        case dmpmsNotice
        case sourceFile
        case title
        case description
        case dateTaken
        case dateRange
        case gps
        case location
        case tags
        case people
        case peopleV2
        case peopleV2Snapshots
        case virtualCrops
        case history
    }

    // MARK: - Designated init (used by code)

    init(
        dmpmsVersion: String = "1.1",
        dmpmsNotice: String = DmpmsMetadata.defaultNotice,
        sourceFile: String,
        title: String = "",
        description: String = "",
        dateTaken: String = "",
        dateRange: DmpmsDateRange? = nil,
        gps: DmpmsGPS? = nil,
        location: DmpmsLocation? = nil,
        tags: [String] = [],
        people: [String] = [],
        peopleV2: [DmpmsPersonInPhoto] = [],
        peopleV2Snapshots: [DmpmsPeopleSnapshot] = [],
        virtualCrops: [VirtualCrop] = [],
        history: [HistoryEvent] = []
    ) {
        self.dmpmsVersion = dmpmsVersion
        self.dmpmsNotice = dmpmsNotice
        self.sourceFile = sourceFile
        self.title = title
        self.description = description
        self.dateTaken = dateTaken
        self.dateRange = dateRange
        self.gps = gps
        self.location = location
        self.tags = tags
        self.people = people
        self.peopleV2 = peopleV2
        self.peopleV2Snapshots = peopleV2Snapshots
        self.virtualCrops = virtualCrops
        self.history = history
    }

    // MARK: - Codable (backward compatible with older sidecars)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        dmpmsVersion = try container.decode(String.self, forKey: .dmpmsVersion)

        dmpmsNotice = (try? container.decode(String.self, forKey: .dmpmsNotice))
            ?? DmpmsMetadata.defaultNotice

        sourceFile  = try container.decode(String.self, forKey: .sourceFile)
        title       = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        dateTaken   = try container.decode(String.self, forKey: .dateTaken)

        dateRange   = try? container.decode(DmpmsDateRange.self, forKey: .dateRange)

        gps = try? container.decode(DmpmsGPS.self, forKey: .gps)
        location = try? container.decode(DmpmsLocation.self, forKey: .location)

        tags   = try container.decode([String].self, forKey: .tags)
        people = try container.decode([String].self, forKey: .people)

        peopleV2 = (try? container.decode([DmpmsPersonInPhoto].self, forKey: .peopleV2)) ?? []

        // NEW (v1.2+)
        peopleV2Snapshots = (try? container.decode([DmpmsPeopleSnapshot].self, forKey: .peopleV2Snapshots)) ?? []

        virtualCrops = try container.decode([VirtualCrop].self, forKey: .virtualCrops)
        history      = try container.decode([HistoryEvent].self, forKey: .history)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(dmpmsVersion, forKey: .dmpmsVersion)
        try c.encodeIfPresent(dmpmsNotice, forKey: .dmpmsNotice)
        try c.encode(sourceFile, forKey: .sourceFile)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(dateTaken, forKey: .dateTaken)
        try c.encodeIfPresent(dateRange, forKey: .dateRange)

        try c.encodeIfPresent(gps, forKey: .gps)
        try c.encodeIfPresent(location, forKey: .location)

        try c.encode(tags, forKey: .tags)

        try c.encode(people, forKey: .people)
        try c.encode(peopleV2, forKey: .peopleV2)

        // NEW (v1.2+)
        try c.encode(peopleV2Snapshots, forKey: .peopleV2Snapshots)

        try c.encode(virtualCrops, forKey: .virtualCrops)
        try c.encode(history, forKey: .history)
    }
}

/* [DMPMS-HISTORY] Simple history event. */
struct HistoryEvent: Codable, Hashable {
    var action: String
    var timestamp: String
    var oldName: String? = nil
    var newName: String? = nil
    var cropID: String? = nil
}

// MARK: - People sync helpers

extension DmpmsMetadata {

    /// Rebuilds the legacy `people: [String]` list from `peopleV2`
    /// when `peopleV2` is non-empty.
    ///
    /// Sorting:
    /// - Primary: rowIndex (0 = front row, 1 = second row, etc.)
    /// - Secondary: positionIndex (0 = leftmost in that row)
    ///
    /// This lets newer UIs treat `peopleV2` as the source of truth,
    /// while keeping older consumers that only read `people` working.
    mutating func syncLegacyPeopleFromPeopleV2IfNeeded() {
        // If there are no v2 records yet, leave legacy people alone.
        guard !peopleV2.isEmpty else { return }

        let sorted = peopleV2.sorted { lhs, rhs in
            if lhs.rowIndex != rhs.rowIndex {
                return lhs.rowIndex < rhs.rowIndex
            }
            return lhs.positionIndex < rhs.positionIndex
        }

        self.people = sorted.map { $0.shortNameSnapshot }
    }
}

// MARK: - Location models

struct DmpmsGPS: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var altitudeMeters: Double? = nil
}

struct DmpmsLocation: Codable, Hashable {
    /// Optional friendly label used in UI (e.g., "Ashcroft", "Ames", "1st Lutheran")
    var shortName: String? = nil

    /// Optional longer description (e.g., "Our Family House", "Innovation Center")
    var description: String? = nil

    /// Human-entered address fields
    var streetAddress: String? = nil   // e.g., "1418 Ashcroft Dr"
    var city: String? = nil
    var state: String? = nil
    var country: String? = nil
}

