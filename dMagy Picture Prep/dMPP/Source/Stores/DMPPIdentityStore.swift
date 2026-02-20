import Foundation
import Combine

// ================================================================
// DMPPIdentityStore.swift
// cp-2026-01-24-01 — People registry: portable archive + record-per-person files
//
// [IDS] Goals:
// - Store People registry under:
//   <Picture Library Folder>/dMagy Portable Archive Data/People/
//
// - Record-per-file model (per person):
//   People/person_<personID>.json  (contains [DmpmsIdentity] versions for that person)
//
// - Keep legacy single-file storage in Application Support as a fallback + migration source.
// - Provide configureForArchiveRoot() entry point so the App can point the store at the
//   currently selected Picture Library Folder.
//
// Notes:
// - Settings are hard-locked, so concurrent People edits should be rare.
// - Writes are atomic; Drive sync is still "eventual" across machines.
// ================================================================

final class DMPPIdentityStore: ObservableObject {



    // ------------------------------------------------------------
    // [IDS] Public, in-memory model
    // ------------------------------------------------------------

    /// Flat list of all identity versions loaded from disk.
    /// Multiple entries may share the same `personID`.
    @Published var identities: [DmpmsIdentity] = []

    /// [IDS-REV] Lightweight change signal for cross-window refresh (People Manager -> Editor).
    @Published private(set) var revision: Int = 0

    // ------------------------------------------------------------
    // [IDS] Storage configuration
    // ------------------------------------------------------------

    /// The currently selected Picture Library Folder (archive root).
    /// When set, People read/write happens in the portable archive.
    private var archiveRootURL: URL? = nil

    /// Legacy storage location (single identities.json file) used as fallback and migration source.
    private let legacyStorageURL: URL

    // [IDS] Portable folder names (single source of truth)
    private let portableFolderName = DMPPPortableArchiveBootstrap.portableFolderName // "dMagy Portable Archive Data"
    private let peopleFolderName = "People"

    // MARK: - Init

    init() {
        // [IDS-LEGACY] Create legacy location (Application Support) for fallback + migration.
        let fm = FileManager.default

        if let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            let dir = appSupport.appendingPathComponent("dMagyPicturePrep", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            legacyStorageURL = dir.appendingPathComponent("identities.json")
        } else {
            legacyStorageURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("dMPP-identities.json")
        }

        // [IDS] Load immediately from legacy so the app can run before root is chosen.
        loadFromLegacy()
    }

    // ------------------------------------------------------------
    // [IDS] Configure store for a Picture Library Folder (archive root)
    // ------------------------------------------------------------

    /// Call this whenever the Picture Library Folder changes.
    /// - If root is set: load from portable archive People/ folder (record-per-person files).
    /// - If root is nil: fall back to legacy.
    func configureForArchiveRoot(_ root: URL?) {
        self.archiveRootURL = root

        if let root {
            loadFromPortableArchive(root: root)
        } else {
            loadFromLegacy()
        }
    }

    // ------------------------------------------------------------
    // [IDS] Portable archive file helpers (People record-per-file)
    // ------------------------------------------------------------

    func peopleFolderURL() -> URL? {
        guard let root = archiveRootURL else { return nil }
        return root
            .appendingPathComponent(DMPPPortableArchiveBootstrap.portableFolderName, isDirectory: true)
            .appendingPathComponent("People", isDirectory: true)
    }

    func personRecordURL(for personID: String) -> URL? {
        guard let peopleFolder = peopleFolderURL() else { return nil }
        return peopleFolder.appendingPathComponent("person_\(personID).json")
    }

    
    // MARK: - Revision bump

    private func bumpRevision() {
        revision &+= 1
    }

    // ============================================================
    // MARK: [IDS-PATHS] Portable paths
    // ============================================================

    private func portablePeopleFolderURL(root: URL) -> URL {
        root
            .appendingPathComponent(portableFolderName, isDirectory: true)
            .appendingPathComponent(peopleFolderName, isDirectory: true)
    }

    private func personFileURL(root: URL, personID: String) -> URL {
        let safeID = personID.trimmingCharacters(in: .whitespacesAndNewlines)
        return portablePeopleFolderURL(root: root)
            .appendingPathComponent("person_\(safeID).json")
    }

    // ============================================================
    // MARK: [IDS-IO] Loading
    // ============================================================

    /// Legacy single-file load (Application Support fallback).
    private func loadFromLegacy() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyStorageURL.path) else {
            identities = []
            bumpRevision()
            return
        }

        do {
            let data = try Data(contentsOf: legacyStorageURL)
            identities = try JSONDecoder().decode([DmpmsIdentity].self, from: data)
            migrateAndNormalize()
            bumpRevision()
        } catch {
            print("dMPP: Failed to load legacy identities: \(error)")
            identities = []
            bumpRevision()
        }
    }

    /// Portable record-per-person load.
    private func loadFromPortableArchive(root: URL) {

        let fm = FileManager.default
        let peopleFolder = portablePeopleFolderURL(root: root)

        // Ensure folder exists (bootstrap should create it, but be defensive)
        try? fm.createDirectory(at: peopleFolder, withIntermediateDirectories: true)

        // If folder appears empty AND legacy has data, perform one-time migration.
        if isPortablePeopleFolderEmpty(peopleFolder),
           fm.fileExists(atPath: legacyStorageURL.path) {

            do {
                try migrateLegacyIntoPortableArchive(root: root)
            } catch {
                // If migration fails, fall back to legacy so the app still works.
                print("dMPP: Migration legacy -> portable failed, using legacy. Error: \(error)")
                loadFromLegacy()
                return
            }
        }

        do {
            let files = try fm.contentsOfDirectory(
                at: peopleFolder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            var loaded: [DmpmsIdentity] = []
            loaded.reserveCapacity(512)

            for url in files where url.lastPathComponent.hasPrefix("person_") && url.pathExtension.lowercased() == "json" {
                guard let data = try? Data(contentsOf: url) else { continue }

                // Each person file contains [DmpmsIdentity] versions for that person.
                if let versions = try? JSONDecoder().decode([DmpmsIdentity].self, from: data) {
                    loaded.append(contentsOf: versions)
                }
            }

            identities = loaded
            migrateAndNormalize()
            bumpRevision()

        } catch {
            print("dMPP: Failed to load portable identities: \(error)")
            identities = []
            bumpRevision()
        }
    }

    private func isPortablePeopleFolderEmpty(_ peopleFolder: URL) -> Bool {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: peopleFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return true
        }
        // Count only our person files
        let personFiles = files.filter { $0.lastPathComponent.hasPrefix("person_") && $0.pathExtension.lowercased() == "json" }
        return personFiles.isEmpty
    }

    // ============================================================
    // MARK: [IDS-IO] Saving
    // ============================================================

    /// Save to the “current” backing store:
    /// - If archiveRootURL is set: portable record-per-person files
    /// - Else: legacy single-file
    private func saveCurrentBackingStore() {
        if let root = archiveRootURL {
            saveToPortableArchive(root: root)
        } else {
            saveToLegacy()
        }
    }

    private func saveToLegacy() {
        do {
            let data = try JSONEncoder().encode(identities)
            try data.write(to: legacyStorageURL, options: .atomic)
        } catch {
            print("dMPP: Failed to save legacy identities: \(error)")
        }
    }

    private func saveToPortableArchive(root: URL) {
        let fm = FileManager.default
        let peopleFolder = portablePeopleFolderURL(root: root)
        try? fm.createDirectory(at: peopleFolder, withIntermediateDirectories: true)

        // Group identities by personID (fall back to id if missing)
        let groups = Dictionary(grouping: identities, by: { ($0.personID?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? $0.id })

        for (personID, versions) in groups {
            let url = personFileURL(root: root, personID: personID)

            do {
                let data = try JSONEncoder().encode(versions)
                try data.write(to: url, options: .atomic)
            } catch {
                print("dMPP: Failed to save portable person file \(personID): \(error)")
            }
        }

        // Optional cleanup: remove person files that no longer exist in memory
        // (This prevents orphan files after deleting a person.)
        do {
            let existing = try fm.contentsOfDirectory(at: peopleFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let desiredNames = Set(groups.keys.map { "person_\($0).json" })

            for file in existing where file.lastPathComponent.hasPrefix("person_") && file.pathExtension.lowercased() == "json" {
                if !desiredNames.contains(file.lastPathComponent) {
                    try? fm.removeItem(at: file)
                }
            }
        } catch {
            // Best-effort; ignore
        }
    }

    // ============================================================
    // MARK: [IDS-MIGRATE] Legacy -> Portable migration
    // ============================================================

    private func migrateLegacyIntoPortableArchive(root: URL) throws {
        // Load legacy identities.json
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyStorageURL.path) else { return }

        let data = try Data(contentsOf: legacyStorageURL)
        let legacy = try JSONDecoder().decode([DmpmsIdentity].self, from: data)

        // Write as portable person files.
        let peopleFolder = portablePeopleFolderURL(root: root)
        try fm.createDirectory(at: peopleFolder, withIntermediateDirectories: true)

        let groups = Dictionary(grouping: legacy, by: { ($0.personID?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? $0.id })

        for (personID, versions) in groups {
            let url = personFileURL(root: root, personID: personID)
            let out = try JSONEncoder().encode(versions)
            try out.write(to: url, options: .atomic)
        }

        // We intentionally do NOT delete legacyStorageURL.
        // It remains a fallback/backup in case the user switches roots or the portable folder is removed.
        print("dMPP: Migrated legacy identities.json -> portable People/ (\(groups.count) people)")
    }

    // ============================================================
    // MARK: [IDS-NORMALIZE] Migration / normalization
    // ============================================================

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
    }

    // ============================================================
    // MARK: [IDS] Alive filter (Option B: Death is an event)
    // ============================================================

    /// Return people who could plausibly be alive during the photo range.
    /// - If birth/death is unknown, we keep the person (inclusive).
    /// - Uses LooseYMD.birthRange for fuzzy parsing.
    func peopleAliveDuring(photoRange: DmpmsDateRange?) -> [PersonSummary] {

        // If we don't know the photo date at all, show everybody.
        guard let photoRange else { return peopleSortedForUI }

        let photoEarliest = LooseYMD.parse(photoRange.earliest) ?? LooseYMD.parse(photoRange.latest)
        let photoLatest   = LooseYMD.parse(photoRange.latest)   ?? photoEarliest

        // If parsing failed, fall back to "show everybody".
        guard let p0 = photoEarliest, let p1 = photoLatest else {
            return peopleSortedForUI
        }

        return peopleSortedForUI.filter { person in

            // Person-level birth (propagated)
            let (b0, _) = LooseYMD.birthRange(person.birthDate)

            // Option B+: end-of-presence comes from “Death” OR other end events (Lost contact / Rehomed)
            let endDateString = effectiveEndEventDate(from: person.versions)
            let (_, d1) = LooseYMD.birthRange(endDateString)


            let earliestAlive = b0
            let latestAlive   = d1

            // If we have a latestAlive and it is before the photo earliest → definitely not alive.
            if let latestAlive, latestAlive < p0 { return false }

            // If we have an earliestAlive and it is after the photo latest → not born yet.
            if let earliestAlive, earliestAlive > p1 { return false }

            // Otherwise: could be alive.
            return true
        }
    }

    private func deathEventDate(from versions: [DmpmsIdentity]) -> String? {
        let deaths = versions.filter { normalize($0.idReason) == "death" }
        guard !deaths.isEmpty else { return nil }
        let best = deaths.max(by: { sortKey(for: $0.idDate) < sortKey(for: $1.idDate) })
        let s = (best?.idDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    
    
    private func effectiveEndEventDate(from versions: [DmpmsIdentity]) -> String? {

        // Normalize once
        let endReasons: Set<String> = ["death", "lost contact", "rehomed"]

        let endEvents = versions.filter { endReasons.contains(normalize($0.idReason)) }
        guard !endEvents.isEmpty else { return nil }

        // IMPORTANT CHOICE:
        // We want the earliest “end-of-presence” date to act as the cutoff.
        // Example: Rehomed in 2019, Death in 2030 -> cutoff should be 2019.
        let best = endEvents.min(by: { sortKey(for: $0.idDate) < sortKey(for: $1.idDate) })

        let s = (best?.idDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    
    // ============================================================
    // MARK: [IDS] Shared fields propagation
    // ============================================================

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
            let sharedDeathDate  = primary.deathDate   // legacy; keep propagated for backward compat
            let sharedKind       = normalizeKind(primary.kind)
            let sharedFavorite   = primary.isFavorite
            let sharedNotes      = primary.notes

            // Preferred + Aliases (person-level)
            let sharedPreferred  = primary.preferredName
            let sharedAliases    = primary.aliases

            for v in versions {
                var copy = v
                copy.personID   = personID

                // shared fields
                copy.shortName  = sharedShortName
                copy.birthDate  = sharedBirthDate
                copy.deathDate  = sharedDeathDate
                copy.kind       = sharedKind
                copy.isFavorite = sharedFavorite
                copy.notes      = sharedNotes

                copy.preferredName = sharedPreferred
                copy.aliases       = sharedAliases

                rebuilt.append(copy)
            }
        }

        identities = rebuilt
    }

    // ============================================================
    // MARK: [IDS] Computed views (raw identities)
    // ============================================================

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

    // ============================================================
    // MARK: [IDS] Person grouping (one row per person for editor UI)
    // ============================================================

    struct PersonSummary: Identifiable, Hashable {
        /// Uses the stable personID as the group identifier.
        let id: String

        /// Shared person-level fields (kept in sync across versions).
        let shortName: String
        let preferredName: String?
        let aliases: [String]
        let birthDate: String?
        let kind: String
        let isFavorite: Bool
        let notes: String?

        /// All identity versions for this person (sorted: Birth first, then by date-ish)
        let versions: [DmpmsIdentity]
    }

    /// Returns a label for the People checklist.
    /// - If `shortName` is unique: "Anna"
    /// - If duplicated: "Anna (b. 1942)"
    /// - If duplicated but birth year missing: "Anna (b. ? #A1B2)"
    func checklistLabel(for person: PersonSummary) -> String {
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

        func personKey(for identity: DmpmsIdentity) -> String {
            let raw = identity.personID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return raw.isEmpty ? identity.id : raw
        }

        let groups = Dictionary(grouping: identities, by: personKey)

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
                kind: normalizeKind(representative.kind),
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

    // ============================================================
    // MARK: [IDS] Lookup / mutation
    // ============================================================

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

        // Normalize kind
        incoming.kind = normalizeKind(incoming.kind)

        if let idx = identities.firstIndex(where: { $0.id == incoming.id }) {
            identities[idx] = incoming
        } else {
            identities.append(incoming)
        }

        migrateAndNormalize()
        saveCurrentBackingStore()
        bumpRevision()
    }

    func delete(id: String) {
        identities.removeAll { $0.id == id }
        migrateAndNormalize()
        saveCurrentBackingStore()
        bumpRevision()
    }

    func deletePerson(personID: String) {
        identities.removeAll { ($0.personID ?? $0.id) == personID }
        migrateAndNormalize()
        saveCurrentBackingStore()
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

    // ============================================================
    // MARK: [IDS] Creation helpers for People Manager
    // ============================================================

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
            deathDate: nil,
            kind: "human",
            idDate: "",
            idReason: "Birth",
            isFavorite: false,
            notes: nil
        )

        identities.append(birth)

        migrateAndNormalize()
        saveCurrentBackingStore()
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

        // ensure kind normalized
        new.kind = normalizeKind(new.kind)

        identities.append(new)

        migrateAndNormalize()
        saveCurrentBackingStore()
        bumpRevision()

        return new.id
    }

    // ============================================================
    // MARK: [IDS] Internal helpers
    // ============================================================

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizeKind(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (s == "pet") ? "pet" : "human"
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

