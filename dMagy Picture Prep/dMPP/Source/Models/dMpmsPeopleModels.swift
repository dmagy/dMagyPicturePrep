//
//  DmpmsPeopleModels.swift
//  dMagy Picture Prep
//
//  dMPMS-2025-12-12-PPL3 — People / identity models for dMPMS 1.1
//

import Foundation

// MARK: - Identity records (who this person is over time)

/// [DMPMS-IDENTITY]
/// A single identity "version" for a person, valid starting at `idDate`.
/// Example:
///   erin1: Erin Amanda Magyar, valid from birth
///   erin2: Erin Amanda Colburn, valid from marriage date
///
/// All date strings use the same dMPMS date grammar as `dateTaken`:
///   - Full: "1976-07-04"
///   - Year-month: "1976-07"
///   - Year: "1976"
///   - Decade: "1970s"
///   - Range: "1975-1977"
struct DmpmsIdentity: Codable, Hashable, Identifiable {

    /// Stable identifier for this identity version.
    /// You can use human-readable IDs like "erin1" or UUIDs as strings.
    var id: String

    /// Short name used in UI (and for legacy `people: [String]` compatibility).
    /// Intended to be unique across identities.
    var shortName: String
    
    /// Groups multiple identities that belong to the same individual.
    /// If missing (older identities.json), dMPP will default it to `id` on load.
    var personID: String?


    /// Structured name components.
    var givenName: String
    var middleName: String?
    var surname: String

    /// Birth date of the person (same date grammar as dMPMS).
    /// Typically a precise date, but we keep it as a string for flexibility.
    var birthDate: String?

    /// The date from which this identity version becomes valid.
    /// Example: marriage date when surname changes.
    var idDate: String

    /// Reason for this identity version (e.g., "birth", "marriage", "divorce", "name change").
    var idReason: String

    /// Optional flag to mark this identity as a "favorite" in UI.
    /// dMPP can use this to build a "favorites" column.
    var isFavorite: Bool

    /// Optional free-form notes: relationships, roles, etc.
    var notes: String?

    // MARK: - Computed helpers

    /// Convenience display name built from name components.
    /// This is *not* encoded; it’s derived at runtime.
    var fullName: String {
        let mid = middleName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let mid, !mid.isEmpty {
            return "\(givenName) \(mid) \(surname)"
        } else {
            return "\(givenName) \(surname)"
        }
    }

    /// Normalized short name for case-insensitive comparisons.
    var normalizedShortName: String {
        shortName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Designated init

    init(
        id: String,
        shortName: String,
        givenName: String,
        middleName: String? = nil,
        surname: String,
        birthDate: String,
        idDate: String,
        idReason: String,
        isFavorite: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.shortName = shortName
        self.givenName = givenName
        self.middleName = middleName
        self.surname = surname
        self.birthDate = birthDate
        self.idDate = idDate
        self.idReason = idReason
        self.isFavorite = isFavorite
        self.notes = notes
    }
}

// MARK: - Person record (groups multiple identities for one human)

/// [DMPMS-PERSON]
/// A *person* across their whole life, potentially with multiple
/// `DmpmsIdentity` records (birth name, married name, etc.).
///
/// Conventions:
/// - `identities[0]` is intended to be the **birth identity**.
/// - `primaryShortName` is what you show in most checklists (“Erin”, “Anna C”).
/// - `birthDate` is the canonical birth date used for age calculations.
struct DmpmsPerson: Identifiable, Codable, Hashable {

    /// Stable ID for the person (NOT the same as any identity.id).
    var id: String

    /// Whether this person should appear in the "Favorites" group in the UI.
    var isFavorite: Bool

    /// Primary label used in lists and checkboxes (e.g. “Anna C”).
    var primaryShortName: String

    /// Canonical birth date for age calculations (YYYY-MM-DD or dMPMS date grammar).
    var birthDate: String?

    /// Free-form notes about this person.
    var notes: String?

    /// All identity versions for this person.
    ///
    /// Convention: identities[0] is the birth identity.
    var identities: [DmpmsIdentity]

    init(
        id: String = UUID().uuidString,
        isFavorite: Bool = false,
        primaryShortName: String,
        birthDate: String? = nil,
        notes: String? = nil,
        identities: [DmpmsIdentity] = []
    ) {
        self.id = id
        self.isFavorite = isFavorite
        self.primaryShortName = primaryShortName
        self.birthDate = birthDate
        self.notes = notes
        self.identities = identities
    }

    /// Best identity to use as the “primary” for this person.
    ///
    /// - Prefer the identity whose `idReason` is "birth" (case-insensitive).
    /// - Fall back to the first identity if none are explicitly "birth".
    var primaryIdentity: DmpmsIdentity? {
        if let birth = identities.first(where: { $0.idReason.caseInsensitiveEquals("birth") }) {
            return birth
        }
        return identities.first
    }
}

// MARK: - Per-photo people records

/// [DMPMS-PERSON-IN-PHOTO]
/// A normalized record of "this person in this specific photo".
/// Stored in `DmpmsMetadata.peopleV2` (alongside legacy `people: [String]`).
struct DmpmsPersonInPhoto: Codable, Hashable, Identifiable {

    /// Unique per-photo person row ID.
    /// This is not the same as the identity ID.
    var id: String

    /// Identity record this person refers to, if known.
    /// For unknown placeholders, this will be `nil` and `isUnknown == true`.
    var identityID: String?

    /// True when this row represents an "unknown" person
    /// (e.g., “Unknown woman holding baby in front row”).
    var isUnknown: Bool

    /// Short name snapshot at time of tagging (for quick display and resilience).
    var shortNameSnapshot: String

    /// Human-facing display name snapshot (typically based on identity + photo date).
    var displayNameSnapshot: String

    /// Optional age snapshot (e.g., "3", "42", "late 30s").
    /// dMPP will compute this at tag-time based on `birthDate` and photo date/range.
    var ageAtPhoto: String?

    /// Row information for left-to-right ordering in group photos.
    /// `rowIndex` 0 = front row, 1 = second row, etc.
    var rowIndex: Int

    /// Optional row label for UI (e.g., "front", "second", "third").
    /// This is purely cosmetic and can be regenerated from `rowIndex` if needed.
    var rowName: String?

    /// Position within the row, left-to-right (0, 1, 2, ...).
    var positionIndex: Int

    /// Optional free-form role hint ("bride", "groom", "birthday child", etc.).
    var roleHint: String?

    // MARK: - Designated init

    init(
        id: String = UUID().uuidString,
        identityID: String? = nil,
        isUnknown: Bool = false,
        shortNameSnapshot: String,
        displayNameSnapshot: String,
        ageAtPhoto: String? = nil,
        rowIndex: Int = 0,
        rowName: String? = nil,
        positionIndex: Int = 0,
        roleHint: String? = nil
    ) {
        self.id = id
        self.identityID = identityID
        self.isUnknown = isUnknown
        self.shortNameSnapshot = shortNameSnapshot
        self.displayNameSnapshot = displayNameSnapshot
        self.ageAtPhoto = ageAtPhoto
        self.rowIndex = rowIndex
        self.rowName = rowName
        self.positionIndex = positionIndex
        self.roleHint = roleHint
    }
}

// MARK: - Small helper

private extension String {
    func caseInsensitiveEquals(_ other: String) -> Bool {
        self.compare(other, options: .caseInsensitive) == .orderedSame
    }
}
