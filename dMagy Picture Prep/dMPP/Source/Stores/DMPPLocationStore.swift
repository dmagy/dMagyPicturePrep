import Foundation
import Combine

// ================================================================
// DMPPLocationStore.swift
// cp-2026-01-30-01 — Locations registry stored in portable archive (records)
//
// [LOC] Portable file:
//   <Picture Library Folder>/dMagy Portable Archive Data/Locations/locations.json
//
// Schema (current):
//   { "locations":[...], "updatedAtUTC": "..." }
//
// Notes:
// - No reserved locations.
// - If file is missing/empty, can seed from legacy prefs.userLocations.
// - Writes are atomic.
// ================================================================

final class DMPPLocationStore: ObservableObject {

    // IMPORTANT: matches your prefs type
    typealias UserLocation = DMPPUserLocation

    @Published private(set) var locations: [UserLocation] = []

    private var archiveRootURL: URL? = nil

    // MARK: - Configure

    /// Configure the store to use the current Picture Library Folder.
    /// If locations.json is missing/empty and fallbackLocations is provided, seed from fallbackLocations.
    func configureForArchiveRoot(_ root: URL?, fallbackLocations: [UserLocation]? = nil) {
        archiveRootURL = root

        guard let root else {
            // No archive root yet; keep in-memory as-is.
            return
        }

        // Ensure portable structure exists (best-effort)
        _ = try? DMPPPortableArchiveBootstrap.ensurePortableArchive(at: root)

        let url = locationsFileURL(forRoot: root)
        let loaded = readLocationsFile(url: url)

        if loaded.isEmpty {
            if let fallback = fallbackLocations, !fallback.isEmpty {
                let seeded = sanitize(fallback)
                locations = seeded
                writeLocationsFile(url: url, locations: seeded)
            } else {
                locations = []
                writeLocationsFile(url: url, locations: [])
            }
        } else {
            let cleaned = sanitize(loaded)
            locations = cleaned
            if cleaned != loaded {
                writeLocationsFile(url: url, locations: cleaned)
            }
        }
    }

    /// If portable is empty (or missing), migrate from legacy prefs locations.
    func migrateFromLegacyPrefsIfNeeded(legacyLocations: [UserLocation]) {
        let legacyClean = sanitize(legacyLocations)
        guard !legacyClean.isEmpty else { return }

        // If we already have portable locations, don’t clobber.
        guard locations.isEmpty else { return }

        locations = legacyClean
        save()
    }

    // MARK: - Persist from UI

    func persistLocationsFromUI(_ uiLocations: [UserLocation]) {
        locations = sanitize(uiLocations)
        save()
    }

    // MARK: - Linked file helpers

    func locationsFileURL() -> URL? {
        guard let root = archiveRootURL else { return nil }
        return locationsFileURL(forRoot: root)
    }

    private func locationsFolderURL(forRoot root: URL) -> URL {
        root
            .appendingPathComponent(DMPPPortableArchiveBootstrap.portableFolderName, isDirectory: true)
            .appendingPathComponent("Locations", isDirectory: true)
    }

    private func locationsFileURL(forRoot root: URL) -> URL {
        locationsFolderURL(forRoot: root).appendingPathComponent("locations.json")
    }

    // MARK: - Read / Write

    private struct WrappedLocations: Codable {
        let locations: [UserLocation]
        let updatedAtUTC: String
    }

    private func readLocationsFile(url: URL) -> [UserLocation] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [] }

        // Current wrapped format
        if let wrapped = try? JSONDecoder().decode(WrappedLocations.self, from: data) {
            return wrapped.locations
        }

        // Legacy plain array format
        if let list = try? JSONDecoder().decode([UserLocation].self, from: data) {
            return list
        }

        return []
    }

    private func writeLocationsFile(url: URL, locations: [UserLocation]) {
        let payload = WrappedLocations(
            locations: locations,
            updatedAtUTC: ISO8601DateFormatter().string(from: Date())
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(payload)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("dMPP: Failed to write locations.json: \(error)")
        }
    }

    private func save() {
        guard let root = archiveRootURL else { return }
        let url = locationsFileURL(forRoot: root)
        writeLocationsFile(url: url, locations: locations)
    }

    // MARK: - Sanitize

    private func sanitize(_ incoming: [UserLocation]) -> [UserLocation] {
        var cleaned: [UserLocation] = incoming.map { loc in
            var l = loc

            // These match what your Locations UI edits.
            l.shortName = l.shortName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            l.description = l.description?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if (l.description ?? "").isEmpty { l.description = nil }

            l.streetAddress = l.streetAddress?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if (l.streetAddress ?? "").isEmpty { l.streetAddress = nil }

            l.city = l.city?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if (l.city ?? "").isEmpty { l.city = nil }

            l.state = l.state?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if (l.state ?? "").isEmpty { l.state = nil }

            l.country = l.country?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if (l.country ?? "").isEmpty { l.country = nil }

            return l
        }

        // Drop totally empty short names? (Keep them if you want “Untitled” locations.)
        // For now, keep them.

        // De-dupe by id (defensive) and keep deterministic order
        var seen = Set<UUID>()
        cleaned = cleaned.filter { loc in
            if seen.contains(loc.id) { return false }
            seen.insert(loc.id)
            return true
        }

        // Deterministic sort: shortName then id
        cleaned.sort { a, b in
            let aName = a.shortName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let bName = b.shortName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            let c = aName.localizedCaseInsensitiveCompare(bName)
            if c != .orderedSame { return c == .orderedAscending }

            // UUID tie-breaker
            return a.id.uuidString < b.id.uuidString
        }

        return cleaned
    }
}
