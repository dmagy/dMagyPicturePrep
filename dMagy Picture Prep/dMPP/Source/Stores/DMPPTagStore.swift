import Foundation
import Combine

// ================================================================
// DMPPTagStore.swift
// cp-2026-01-29-02 — Tags registry stored in portable archive (records)
// ================================================================
//
// [TAGS] Portable file:
//   <Picture Library Folder>/dMagy Portable Archive Data/Tags/tags.json
//
// Schema (current):
//   { "tags":[{id,name,description,isReserved}], "updatedAtUTC": "..." }
//
// Backward compatible reads:
//   1) ["Tag1","Tag2"]
//   2) { "tags": ["Tag1","Tag2"] }
//
// Notes:
// - Reserved tags always exist and cannot be renamed/deleted in UI.
// - Default tags for brand-new users include: Halloween, NSFW (plus reserved).
// - App still uses prefs.availableTags ([String]) for editor checkboxes;
//   Settings can use tagRecords for descriptions.
// ================================================================

final class DMPPTagStore: ObservableObject {

    // Canonical in-memory model (records)
    @Published var tagRecords: [TagRecord] = []

    // Convenience (names only) for callers that only care about strings
    var tags: [String] { tagRecords.map { $0.name } }

    private var archiveRootURL: URL? = nil

    // Reserved tags (canonical spelling + display order at top)
    private let reservedTagNames: [String] = [
        "Do Not Display",
        "Flagged"
    ]

    // Default “starter” tags for new users (non-reserved)
    private let defaultTagNames: [String] = [
        "Halloween",
        "NSFW"
    ]

    // Default descriptions (seed for new users + fill blanks on normalize)
    private let defaultDescriptionsByName: [String: String] = [
        "Do Not Display": """
Use this to hide pictures from displays unless explicitly included. dMagy Picture apps will exclude by default. It does not delete the photo; it just hides it from display-oriented views.
""",
        "Flagged": """
Use this to mark something that needs attention later (review, fix metadata, crop, etc.).
""",
        "NSFW": """
Not Safe for Work: Use this for content that should not be shown in mixed company or public contexts.
Examples: nudity, explicit content, graphic injury, anything you’d avoid showing at work or church.
""",
        "Halloween": """
Use this for Halloween decor/theme — costumes, pumpkins, spooky setup, party scenes.
Not necessarily the calendar date (10/31). It’s just weird when you see your aunt as a pirate princess in April.
"""
    ]

    // MARK: - Model

    struct TagRecord: Codable, Identifiable, Equatable, Hashable {
        var id: String                // stable UUID string
        var name: String              // display name / checkbox label
        var description: String       // user-maintained meaning/usage
        var isReserved: Bool
    }

    private struct WrappedRecords: Codable {
        let tags: [TagRecord]
        let updatedAtUTC: String
    }

    private struct WrappedLegacyNames: Codable {
        let tags: [String]
    }

    // MARK: - Configure

    /// Configure the store to use the current Picture Library Folder.
    /// If tags.json is missing/empty, seed from fallbackTags and defaults.
    func configureForArchiveRoot(_ root: URL?, fallbackTags: [String]? = nil) {
        archiveRootURL = root

        guard let root else { return }

        // Ensure portable folder structure exists (best-effort)
        _ = try? DMPPPortableArchiveBootstrap.ensurePortableArchive(at: root)

        let url = tagsFileURL(forRoot: root)
        let loaded = readAnyTagsFile(url: url)

        if loaded.isEmpty {
            // Brand new / empty: seed from fallback + defaults + reserved
            let seeded = seedRecords(fallbackTags: fallbackTags ?? [])
            tagRecords = seeded
            writeRecordsFile(url: url, records: seeded)
            return
        }

        // Normalize + enforce reserved, but do NOT inject defaults just because file exists.
        // (Defaults are only for first-run or when user has no non-reserved tags.)
        let cleaned = sanitizeRecords(loaded, ensureReserved: true, includeDefaultsIfEmpty: true)

        tagRecords = cleaned

        if cleaned != loaded {
            writeRecordsFile(url: url, records: cleaned)
        }

        // Optional: if legacy tags were provided and portable is essentially empty, migrate.
        if let fallbackTags {
            migrateFromLegacyPrefsIfNeeded(legacyTags: fallbackTags)
        }
    }

    // MARK: - Normalize & Save

    /// Re-sanitizes current records (canonical reserved tags, trims, de-dupes, fills default descriptions)
    /// and writes tags.json.
    func normalizeAndSave() {
        guard let root = archiveRootURL else { return }
        let url = tagsFileURL(forRoot: root)

        // 1) Normalize names / reserved / defaults without touching descriptions mid-typing elsewhere.
        var cleaned = sanitizeRecords(
            tagRecords,
            ensureReserved: true,
            includeDefaultsIfEmpty: true
        )

        // 2) NOW trim descriptions (only on explicit Normalize action)
        cleaned = cleaned.map { rec in
            var r = rec
            r.description = r.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return r
        }

        tagRecords = cleaned
        writeRecordsFile(url: url, records: cleaned)
    }


    // MARK: - Persist from UI

    /// Persist full record edits (name + description).
    func persistRecordsFromUI(_ records: [TagRecord]) {
        guard let root = archiveRootURL else { return }
        let url = tagsFileURL(forRoot: root)

        let cleaned = sanitizeRecords(records, ensureReserved: true, includeDefaultsIfEmpty: true)

        tagRecords = cleaned
        writeRecordsFile(url: url, records: cleaned)
    }

    /// Back-compat: persist names only (descriptions preserved where possible).
    func persistTagsFromUI(_ uiTags: [String]) {
        let incomingNames = sanitizeNames(uiTags)

        // Merge names into existing records, preserving descriptions if name matches
        var updated: [TagRecord] = []
        updated.reserveCapacity(incomingNames.count)

        for name in incomingNames {
            if let existing = tagRecords.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                var copy = existing
                copy.name = name // keep user's exact casing/spelling
                updated.append(copy)
            } else {
                updated.append(TagRecord(
                    id: UUID().uuidString,
                    name: name,
                    description: defaultDescriptionIfAny(forName: name) ?? "",
                    isReserved: isReservedName(name)
                ))
            }
        }

        persistRecordsFromUI(updated)
    }

    // MARK: - Migration (legacy prefs -> portable)

    /// If portable tags are empty OR only reserved, migrate from legacy `prefs.availableTags`.
    func migrateFromLegacyPrefsIfNeeded(legacyTags: [String]) {
        let legacyClean = sanitizeNames(legacyTags)
        guard !legacyClean.isEmpty else { return }

        // Heuristic: if portable has no non-reserved tags, migrate.
        let portableNonReserved = tagRecords.filter { !( $0.isReserved || isReservedName($0.name) ) }
        let shouldMigrate = tagRecords.isEmpty || portableNonReserved.isEmpty
        guard shouldMigrate else { return }

        // Start with legacy order, then ensure defaults and reserved.
        var mergedNames = legacyClean
        mergedNames.append(contentsOf: defaultTagNames)
        mergedNames = sanitizeNames(mergedNames)

        var mergedRecords: [TagRecord] = mergedNames.map { name in
            TagRecord(
                id: UUID().uuidString,
                name: name,
                description: defaultDescriptionIfAny(forName: name) ?? "",
                isReserved: isReservedName(name)
            )
        }

        mergedRecords = sanitizeRecords(mergedRecords, ensureReserved: true, includeDefaultsIfEmpty: true)

        tagRecords = mergedRecords

        if let root = archiveRootURL {
            let url = tagsFileURL(forRoot: root)
            writeRecordsFile(url: url, records: mergedRecords)
        }
    }

    // MARK: - URLs (for “Linked file” display)

    func tagsFileURL() -> URL? {
        guard let root = archiveRootURL else { return nil }
        return tagsFileURL(forRoot: root)
    }

    private func tagsFolderURL(forRoot root: URL) -> URL {
        root
            .appendingPathComponent(DMPPPortableArchiveBootstrap.portableFolderName, isDirectory: true)
            .appendingPathComponent("Tags", isDirectory: true)
    }

    private func tagsFileURL(forRoot root: URL) -> URL {
        tagsFolderURL(forRoot: root).appendingPathComponent("tags.json")
    }

    // MARK: - Read / Write

    /// Reads ANY supported historical format and returns records.
    private func readAnyTagsFile(url: URL) -> [TagRecord] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [] }

        // 1) Current wrapped records
        if let wrapped = try? JSONDecoder().decode(WrappedRecords.self, from: data) {
            return wrapped.tags
        }

        // 2) Legacy plain array of strings
        if let list = try? JSONDecoder().decode([String].self, from: data) {
            return list.map { name in
                TagRecord(
                    id: UUID().uuidString,
                    name: name,
                    description: defaultDescriptionIfAny(forName: name) ?? "",
                    isReserved: isReservedName(name)
                )
            }
        }

        // 3) Legacy wrapped strings: { "tags": ["a","b"] }
        if let wrappedNames = try? JSONDecoder().decode(WrappedLegacyNames.self, from: data) {
            return wrappedNames.tags.map { name in
                TagRecord(
                    id: UUID().uuidString,
                    name: name,
                    description: defaultDescriptionIfAny(forName: name) ?? "",
                    isReserved: isReservedName(name)
                )
            }
        }

        return []
    }

    private func writeRecordsFile(url: URL, records: [TagRecord]) {
        let payload = WrappedRecords(
            tags: records,
            updatedAtUTC: ISO8601DateFormatter().string(from: Date())
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(payload)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("dMPP: Failed to write tags.json: \(error)")
        }
    }

    // MARK: - Seed / Sanitize

    /// Create initial records for a brand new/empty tags.json.
    private func seedRecords(fallbackTags: [String]) -> [TagRecord] {

        // Start with fallback names (your previous prefs tags),
        // then add defaults, then enforce reserved at top.
        var names = fallbackTags
        names.append(contentsOf: defaultTagNames)

        // Sanitize names -> unique, trimmed
        names = sanitizeNames(names)

        // Build records
        var records = names.map { name in
            TagRecord(
                id: UUID().uuidString,
                name: name,
                description: defaultDescriptionIfAny(forName: name) ?? "",
                isReserved: isReservedName(name)
            )
        }

        records = sanitizeRecords(records, ensureReserved: true, includeDefaultsIfEmpty: true)
        return records
    }

    private func sanitizeNames(_ incoming: [String]) -> [String] {
        // Trim, drop empties
        let trimmed = incoming
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // De-dupe case-insensitive, preserve order
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(trimmed.count)

        for t in trimmed {
            let key = t.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(t)
            }
        }

        return result
    }

    private func sanitizeRecords(
        _ incoming: [TagRecord],
        ensureReserved: Bool,
        includeDefaultsIfEmpty: Bool
    ) -> [TagRecord] {

        // 1) Trim + drop empties (by name)
        var cleaned = incoming
            .map { rec -> TagRecord in
                var r = rec
                r.name = r.name.trimmingCharacters(in: .whitespacesAndNewlines)

                return r
            }
            .filter { !$0.name.isEmpty }

        // 2) De-dupe by name (case-insensitive), preserve first occurrence
        var seen = Set<String>()
        cleaned = cleaned.filter { rec in
            let key = rec.name.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // 3) Optionally ensure defaults exist (only when there are no non-reserved)
        if includeDefaultsIfEmpty {
            let hasNonReserved = cleaned.contains(where: { !($0.isReserved || isReservedName($0.name)) })
            if !hasNonReserved {
                for def in defaultTagNames {
                    if !cleaned.contains(where: { $0.name.caseInsensitiveCompare(def) == .orderedSame }) {
                        cleaned.append(TagRecord(
                            id: UUID().uuidString,
                            name: def,
                            description: defaultDescriptionIfAny(forName: def) ?? "",
                            isReserved: false
                        ))
                    }
                }
            }
        }

        // 4) Ensure reserved tags exist and are canonical (name + reserved flag)
        if ensureReserved {
            // Insert missing reserved at top (in reverse so final order matches reservedTagNames)
            for reservedName in reservedTagNames.reversed() {
                if let idx = cleaned.firstIndex(where: { $0.name.caseInsensitiveCompare(reservedName) == .orderedSame }) {
                    cleaned[idx].name = reservedName
                    cleaned[idx].isReserved = true
                } else {
                    cleaned.insert(TagRecord(
                        id: UUID().uuidString,
                        name: reservedName,
                        description: defaultDescriptionIfAny(forName: reservedName) ?? "",
                        isReserved: true
                    ), at: 0)
                }
            }
        }

        // 5) Fill default descriptions ONLY when blank (don’t overwrite user text)
        cleaned = cleaned.map { rec in
            var r = rec
            if r.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let def = defaultDescriptionIfAny(forName: r.name) {
                r.description = def
            }
            // Keep reserved flag consistent with name
            if isReservedName(r.name) { r.isReserved = true }
            return r
        }

        // 6) Sort: reserved first in reservedTagNames order, then alpha by name
        cleaned.sort { a, b in
            let aRes = a.isReserved || isReservedName(a.name)
            let bRes = b.isReserved || isReservedName(b.name)
            if aRes != bRes { return aRes } // reserved first

            if aRes && bRes {
                let ia = reservedIndex(a.name)
                let ib = reservedIndex(b.name)
                if ia != ib { return ia < ib }
            }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        return cleaned
    }

    // MARK: - Reserved helpers

    private func isReservedName(_ name: String) -> Bool {
        reservedTagNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func reservedIndex(_ name: String) -> Int {
        let idx = reservedTagNames.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame })
        return idx ?? Int.max
    }

    // MARK: - Default descriptions

    private func defaultDescriptionIfAny(forName name: String) -> String? {
        // Match case-insensitive against our defaults
        if let exact = defaultDescriptionsByName[name] {
            return exact
        }
        if let key = defaultDescriptionsByName.keys.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            return defaultDescriptionsByName[key]
        }
        return nil
    }
}
