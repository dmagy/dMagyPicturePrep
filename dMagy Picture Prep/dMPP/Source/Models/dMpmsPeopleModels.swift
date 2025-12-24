//
//  DmpmsPeopleModels.swift
//  dMagy Picture Prep
//
//  dMPMS-2025-12-12-PPL3 — People / identity models for dMPMS 1.1
//

import Foundation

// cp-2025-12-18-31(DmpmsIdentity-DEATHDATE)

struct DmpmsIdentity: Codable, Hashable, Identifiable {

    // MARK: - Core identifiers

    /// Stable ID for this identity version (UUID string or human-readable).
    var id: String

    /// Groups multiple identity versions under one person.
    /// (Birth identity + later identities share the same personID)
    var personID: String?

    // MARK: - Person-level display & search fields (shared across versions)

    /// Short label shown in the People checklist (your “commonly known name”).
    var shortName: String

    /// Preferred / “Known as” name (e.g., Betty). Optional.
    var preferredName: String?

    /// Search helpers / historical variants (e.g., Elizabeth, Betty Ann).
    /// NOT intended to be the primary UI label.
    var aliases: [String]

    /// Birth date of the person (same grammar as dMPMS).
    var birthDate: String?

    /// Death date of the person (same grammar as dMPMS).
    /// NOTE: Option B: Death is an event. This field is legacy/optional; filtering should use the Death event date.
    var deathDate: String?

    /// Kind of being. Defaults to human.
    /// Missing/unknown decodes as "human" for migration safety.
    var kind: String

    /// Person-level favorite flag.
    var isFavorite: Bool

    /// Person-level notes.
    var notes: String?

    // MARK: - Identity-version fields (may vary over time)

    /// Structured legal name components for THIS identity version.
    var givenName: String
    var middleName: String?
    var surname: String

    /// When this identity version becomes valid.
    var idDate: String

    /// Why this version exists (Birth/Marriage/etc.)
    var idReason: String

    // MARK: - Computed

    var fullName: String {
        let mid = middleName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let mid, !mid.isEmpty {
            return "\(givenName) \(mid) \(surname)"
        } else {
            return "\(givenName) \(surname)"
        }
    }

    // MARK: - Init

    init(
        id: String,
        personID: String? = nil,
        shortName: String,
        preferredName: String? = nil,
        aliases: [String] = [],
        givenName: String,
        middleName: String? = nil,
        surname: String,
        birthDate: String? = nil,
        deathDate: String? = nil,
        kind: String = "human",
        idDate: String,
        idReason: String,
        isFavorite: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.personID = personID
        self.shortName = shortName
        self.preferredName = preferredName
        self.aliases = aliases
        self.givenName = givenName
        self.middleName = middleName
        self.surname = surname
        self.birthDate = birthDate
        self.deathDate = deathDate
        self.kind = Self.normalizeKind(kind)
        self.idDate = idDate
        self.idReason = idReason
        self.isFavorite = isFavorite
        self.notes = notes
    }

    // MARK: - Codable migration safety (defaults)

    enum CodingKeys: String, CodingKey {
        case id, personID
        case shortName, preferredName, aliases
        case birthDate, deathDate
        case kind
        case isFavorite, notes
        case givenName, middleName, surname
        case idDate, idReason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(String.self, forKey: .id)
        personID = try c.decodeIfPresent(String.self, forKey: .personID)

        shortName = try c.decodeIfPresent(String.self, forKey: .shortName) ?? ""
        preferredName = try c.decodeIfPresent(String.self, forKey: .preferredName)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []

        birthDate = try c.decodeIfPresent(String.self, forKey: .birthDate)
        deathDate = try c.decodeIfPresent(String.self, forKey: .deathDate) // legacy/optional

        let rawKind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "human"
        kind = Self.normalizeKind(rawKind)

        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        notes = try c.decodeIfPresent(String.self, forKey: .notes)

        givenName = try c.decodeIfPresent(String.self, forKey: .givenName) ?? ""
        middleName = try c.decodeIfPresent(String.self, forKey: .middleName)
        surname = try c.decodeIfPresent(String.self, forKey: .surname) ?? ""

        idDate = try c.decodeIfPresent(String.self, forKey: .idDate) ?? ""
        idReason = try c.decodeIfPresent(String.self, forKey: .idReason) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(personID, forKey: .personID)

        try c.encode(shortName, forKey: .shortName)
        try c.encodeIfPresent(preferredName, forKey: .preferredName)
        try c.encode(aliases, forKey: .aliases)

        try c.encodeIfPresent(birthDate, forKey: .birthDate)
        try c.encodeIfPresent(deathDate, forKey: .deathDate)

        try c.encode(Self.normalizeKind(kind), forKey: .kind)

        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encodeIfPresent(notes, forKey: .notes)

        try c.encode(givenName, forKey: .givenName)
        try c.encodeIfPresent(middleName, forKey: .middleName)
        try c.encode(surname, forKey: .surname)

        try c.encode(idDate, forKey: .idDate)
        try c.encode(idReason, forKey: .idReason)
    }

    // MARK: - Kind normalization

    private static func normalizeKind(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (s == "pet") ? "pet" : "human"
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
