import Foundation
import Combine

// cp-2025-12-18-02(IDS)
// NOTE: Converted from @Observable to ObservableObject so it works with @StateObject / .environmentObject.

final class DMPPIdentityStore: ObservableObject {

    static let shared = DMPPIdentityStore()

    /// Flat list of all identity versions persisted to disk.
    /// Multiple entries may share the same `personID`.
    @Published var identities: [DmpmsIdentity] = []

    /// [IDS-REV] Lightweight change signal for cross-window refresh (People Manager -> Editor).
    /// Any mutation bumps this so views/viewmodels can recompute derived values (like ages).
    @Published private(set) var revision: Int = 0

    private let storageURL: URL

    // MARK: - Init

    init() {
        let fm = FileManager.default

        if let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            let dir = appSupport.appendingPathComponent("dMagyPicturePrep", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            storageURL = dir.appendingPathComponent("identities.json")
        } else {
            storageURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("dMPP-identities.json")
        }

        load()
    }

    // MARK: - Revision bump

    private func bumpRevision() {
        revision &+= 1
    }

    // MARK: - Persistence

    func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storageURL.path) else {
            identities = []
            bumpRevision()
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            identities = try JSONDecoder().decode([DmpmsIdentity].self, from: data)
            migrateAndNormalize()
            bumpRevision()
        } catch {
            print("dMPP: Failed to load identities: \(error)")
            identities = []
            bumpRevision()
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(identities)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("dMPP: Failed to save identities: \(error)")
        }
    }

    // MARK: - Migration / normalization

    /// Ensures older files work and keeps per-person shared fields in sync.
    private func migrateAndNormalize() {

        // 1) Backfill missing/blank personID from identity.id
        for idx in identities.indices {
            let pid = identities[idx].personID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if pid.isEmpty {
                identities[idx].personID = identities[idx].id
            }
        }

        // 2) Propagate shared fields across versions
        propagateSharedFieldsAcrossIdentityVersions()

        // 3) Keep stable UI ordering
        identities = identitiesSortedForUI

        // Optional: write back the migrated structure so it stays clean next run
        save()
    }

    private func propagateSharedFieldsAcrossIdentityVersions() {
        let groups = Dictionary(grouping: identities, by: { $0.personID ?? $0.id })

        var rebuilt: [DmpmsIdentity] = []
        rebuilt.reserveCapacity(identities.count)

        for (personID, versions) in groups {

            // Choose a “primary” identity to define person-level shared fields:
            // Prefer Birth; otherwise earliest idDate-ish.
            let primary = versions.first(where: { normalize($0.idReason) == "birth" })
                ?? versions.sorted(by: { sortKey(for: $0.idDate) < sortKey(for: $1.idDate) }).first
                ?? versions.first!

            // Person-level fields to keep in sync across ALL versions
            let sharedShortName  = primary.shortName
            let sharedBirthDate  = primary.birthDate
            let sharedFavorite   = primary.isFavorite
            let sharedNotes      = primary.notes

            // Preferred + Aliases (person-level)
            let sharedPreferred  = primary.preferredName
            let sharedAliases    = primary.aliases

            for v in versions {
                var copy = v
                copy.personID   = personID

                // existing shared fields
                copy.shortName  = sharedShortName
                copy.birthDate  = sharedBirthDate
                copy.isFavorite = sharedFavorite
                copy.notes      = sharedNotes

                // shared fields
                copy.preferredName = sharedPreferred
                copy.aliases       = sharedAliases

                rebuilt.append(copy)
            }
        }

        identities = rebuilt
    }

    // MARK: - Computed views (raw identities)

    var identitiesSortedForUI: [DmpmsIdentity] {
        identities.sorted {
            $0.shortName.localizedCaseInsensitiveCompare($1.shortName) == .orderedAscending
        }
    }

    var favoriteIdentities: [DmpmsIdentity] {
        identitiesSortedForUI.filter { $0.isFavorite }
    }

    var nonFavoriteIdentities: [DmpmsIdentity] {
        identitiesSortedForUI.filter { !$0.isFavorite }
    }

    // MARK: - Person grouping (one row per person for editor UI)

    struct PersonSummary: Identifiable, Hashable {
        /// Uses the stable personID as the group identifier.
        let id: String

        /// Shared person-level fields (kept in sync across versions).
        let shortName: String
        let preferredName: String?
        let aliases: [String]
        let birthDate: String?
        let isFavorite: Bool
        let notes: String?

        /// All identity versions for this person (sorted: Birth first, then by date-ish)
        let versions: [DmpmsIdentity]
    }

    // MARK: - Checklist labels (People section)

    private var shortNameCounts: [String: Int] {
        Dictionary(grouping: peopleSortedForUI, by: { $0.shortName.lowercased() })
            .mapValues { $0.count }
    }

    /// Returns a label for the People checklist.
    /// - If `shortName` is unique: "Anna"
    /// - If duplicated: "Anna (b. 1942)"
    /// - If duplicated but birth year missing: "Anna (b. ? #A1B2)"
    func checklistLabel(for person: PersonSummary) -> String {
        // Count duplicates by shortName (case-insensitive)
        let counts = Dictionary(grouping: peopleSortedForUI, by: { $0.shortName.lowercased() })
            .mapValues { $0.count }

        let key = person.shortName.lowercased()
        let isDuplicate = (counts[key] ?? 0) > 1
        guard isDuplicate else { return person.shortName }

        let year = person.birthDate.flatMap { bd -> String? in
            let t = bd.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.count >= 4 ? String(t.prefix(4)) : nil
        }

        if let year, !year.isEmpty {
            return "\(person.shortName) (b. \(year))"
        } else {
            let suffix = String(person.id.prefix(4)).uppercased()
            return "\(person.shortName) (b. ? #\(suffix))"
        }
    }

    /// One row per person, used for checkbox UI (dedupes “two Amys” problem).
    var peopleSortedForUI: [PersonSummary] {
        let groups = Dictionary(grouping: identities) { $0.personID ?? $0.id }

        let people: [PersonSummary] = groups.map { (personID, versions) in
            let sortedVersions = identityVersionsInternalSorted(versions)

            // person-level fields are already propagated, so any version is fine.
            let representative = sortedVersions.first ?? versions.first!

            let sn = representative.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayShort = sn.isEmpty ? "Untitled" : sn

            let bd = representative.birthDate?.trimmingCharacters(in: .whitespacesAndNewlines)
            let birth = (bd?.isEmpty == false) ? bd : nil

            let preferred = representative.preferredName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let preferredClean = (preferred?.isEmpty == false) ? preferred : nil

            let aliasesClean = representative.aliases
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return PersonSummary(
                id: personID,
                shortName: displayShort,
                preferredName: preferredClean,
                aliases: aliasesClean,
                birthDate: birth,
                isFavorite: representative.isFavorite,
                notes: representative.notes,
                versions: sortedVersions
            )
        }

        return people.sorted {
            $0.shortName.localizedCaseInsensitiveCompare($1.shortName) == .orderedAscending
        }
    }

    var favoritePeople: [PersonSummary] {
        peopleSortedForUI.filter { $0.isFavorite }
    }

    var nonFavoritePeople: [PersonSummary] {
        peopleSortedForUI.filter { !$0.isFavorite }
    }

    // MARK: - Lookup / mutation

    func identity(withID id: String) -> DmpmsIdentity? {
        identities.first { $0.id == id }
    }

    func identityVersions(forPersonID personID: String) -> [DmpmsIdentity] {
        let versions = identities.filter { ($0.personID ?? $0.id) == personID }
        return identityVersionsInternalSorted(versions)
    }

    /// Convenience for age/label recompute: identityID == identity.id
    func identity(forIdentityID identityID: String) -> DmpmsIdentity? {
        identity(withID: identityID)
    }

    /// Insert or replace a single identity version, then normalize and save.
    func upsert(_ identity: DmpmsIdentity) {
        var incoming = identity

        // Ensure personID exists
        let pid = (incoming.personID?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        incoming.personID = pid ?? incoming.id

        if let idx = identities.firstIndex(where: { $0.id == incoming.id }) {
            identities[idx] = incoming
        } else {
            identities.append(incoming)
        }

        propagateSharedFieldsAcrossIdentityVersions()
        identities = identitiesSortedForUI
        save()
        bumpRevision()
    }

    func delete(id: String) {
        identities.removeAll { $0.id == id }
        propagateSharedFieldsAcrossIdentityVersions()
        save()
        bumpRevision()
    }

    func deletePerson(personID: String) {
        identities.removeAll { ($0.personID ?? $0.id) == personID }
        save()
        bumpRevision()
    }

    /// Given a person’s versions, pick the best identity for a photo date.
    /// Selects the identity with the latest idDate <= photo earliest date.
    func bestIdentityForPhoto(versions: [DmpmsIdentity], photoEarliestYMD: String?) -> DmpmsIdentity {
        let sorted = versions.sorted { sortValue(for: $0.idDate) < sortValue(for: $1.idDate) }
        guard let photoEarliestYMD else { return sorted.last ?? sorted.first! }
        let photoVal = sortValue(for: photoEarliestYMD)
        return sorted.last(where: { sortValue(for: $0.idDate) <= photoVal }) ?? sorted.first!
    }

    // MARK: - Creation helpers for People Manager

    /// Creates a new person with a birth identity and returns the new personID.
    func addPerson() -> String {
        let personID = UUID().uuidString

        let birth = DmpmsIdentity(
            id: UUID().uuidString,
            personID: personID,
            shortName: "New",
            preferredName: nil,
            aliases: [],
            givenName: "",
            middleName: nil,
            surname: "",
            birthDate: "",
            idDate: "",
            idReason: "Birth",
            isFavorite: false,
            notes: nil
        )

        var birthCopy = birth
        birthCopy.personID = personID

        identities.append(birthCopy)
        propagateSharedFieldsAcrossIdentityVersions()
        identities = identitiesSortedForUI
        save()
        bumpRevision()

        return personID
    }

    /// Adds an additional identity version for an existing person.
    /// Prefills from the most recent known version.
    func addIdentityVersion(forPersonID personID: String) -> String {
        let versions = identityVersions(forPersonID: personID)
        let base = versions.last ?? versions.first!

        var new = base
        new.id = UUID().uuidString
        new.personID = personID
        new.idReason = "Marriage"   // default; user can change
        new.idDate = ""

        identities.append(new)
        propagateSharedFieldsAcrossIdentityVersions()
        identities = identitiesSortedForUI
        save()
        bumpRevision()

        return new.id
    }

    // MARK: - Internal helpers

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func identityVersionsInternalSorted(_ versions: [DmpmsIdentity]) -> [DmpmsIdentity] {
        versions.sorted { a, b in
            let aIsBirth = normalize(a.idReason) == "birth"
            let bIsBirth = normalize(b.idReason) == "birth"
            if aIsBirth != bIsBirth { return aIsBirth }
            return sortKey(for: a.idDate) < sortKey(for: b.idDate)
        }
    }

    private func sortValue(for dateString: String) -> Int {
        let parts = dateString.split(separator: "-").map { Int($0) ?? 0 }
        let y = parts.count > 0 ? parts[0] : 0
        let m = parts.count > 1 ? parts[1] : 0
        let d = parts.count > 2 ? parts[2] : 0
        return y * 10_000 + m * 100 + d
    }

    // MARK: - Sorting helpers (date grammar)

    /// Turns loose date grammar into a comparable key (earliest plausible YYYYMMDD).
    private func sortKey(for raw: String) -> Int {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return Int.max }

        // YYYY-MM-DD
        if s.count == 10, s[4] == "-", s[7] == "-" {
            return intKey(
                year: String(s.prefix(4)),
                month: String(s.dropFirst(5).prefix(2)),
                day: String(s.dropFirst(8).prefix(2))
            )
        }

        // YYYY-MM
        if s.count == 7, s[4] == "-" {
            return intKey(
                year: String(s.prefix(4)),
                month: String(s.dropFirst(5).prefix(2)),
                day: "01"
            )
        }

        // YYYY
        if s.count == 4, Int(s) != nil {
            return intKey(year: s, month: "01", day: "01")
        }

        // YYYYs (decade)
        if s.count == 5, s.hasSuffix("s"), Int(s.prefix(4)) != nil {
            return intKey(year: String(s.prefix(4)), month: "01", day: "01")
        }

        // YYYY-YYYY (year range) → take start
        if s.count == 9, s[4] == "-", Int(s.prefix(4)) != nil {
            return intKey(year: String(s.prefix(4)), month: "01", day: "01")
        }

        // "YYYY-MM to YYYY-MM" → take start
        if let range = s.range(of: " to ") {
            let start = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            return sortKey(for: start)
        }

        return Int.max
    }

    private func intKey(year: String, month: String, day: String) -> Int {
        let y = Int(year) ?? 9999
        let m = Int(month) ?? 99
        let d = Int(day) ?? 99
        return (y * 10000) + (m * 100) + d
    }
}

fileprivate extension String {
    subscript(_ i: Int) -> Character { self[index(startIndex, offsetBy: i)] }
}
