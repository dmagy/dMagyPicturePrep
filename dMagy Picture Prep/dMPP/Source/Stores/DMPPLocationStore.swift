import Foundation
import Combine

// ================================================================
// DMPPLocationStore.swift
// cp-2026-01-31-01 — Locations registry stored in portable archive
// ================================================================
//
// Portable file:
//   <Picture Library Folder>/dMagy Portable Archive Data/Locations/locations.json
//
// Schema (current):
//   { "locations":[...], "updatedAtUTC": "..." }
//
// Backward compatible reads:
//   1) [DMPPUserLocation]  (plain array)
//
// Notes:
// - For now, the Settings UI can keep using prefs.userLocations.
// - This store’s job is: load/save portable + seed from prefs if empty.
// ================================================================

final class DMPPLocationStore: ObservableObject {

    @Published private(set) var locations: [DMPPUserLocation] = []

    private var archiveRootURL: URL? = nil

    // MARK: - Configure

    func configureForArchiveRoot(_ root: URL?, fallbackLocations: [DMPPUserLocation]? = nil) {
        archiveRootURL = root
        guard let root else { return }

        // Ensure portable folder structure exists (best-effort)
        _ = try? DMPPPortableArchiveBootstrap.ensurePortableArchive(at: root)

        let url = locationsFileURL(forRoot: root)
        let loaded = readAnyLocationsFile(url: url)

        if loaded.isEmpty {
            // Seed from fallback if provided
            let seeded = sanitize(fallbackLocations ?? [])
            locations = seeded
            writeLocationsFile(url: url, locations: seeded)
        } else {
            let cleaned = sanitize(loaded)
            locations = cleaned

            // Keep file tidy if we normalized anything
            if cleaned != loaded {
                writeLocationsFile(url: url, locations: cleaned)
            }
        }
    }

    // MARK: - Persist from UI (prefs.userLocations)

    func persistLocationsFromUI(_ uiLocations: [DMPPUserLocation]) {
        guard let root = archiveRootURL else { return }
        let url = locationsFileURL(forRoot: root)

        let cleaned = sanitize(uiLocations)
        locations = cleaned
        writeLocationsFile(url: url, locations: cleaned)
    }

    // MARK: - URLs (for “Linked file (advanced)” later)

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
        let locations: [DMPPUserLocation]
        let updatedAtUTC: String
    }

    private func readAnyLocationsFile(url: URL) -> [DMPPUserLocation] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [] }

        // 1) Wrapped schema
        if let wrapped = try? JSONDecoder().decode(WrappedLocations.self, from: data) {
            return wrapped.locations
        }

        // 2) Legacy plain array
        if let list = try? JSONDecoder().decode([DMPPUserLocation].self, from: data) {
            return list
        }

        return []
    }

    private func writeLocationsFile(url: URL, locations: [DMPPUserLocation]) {
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

    // MARK: - Normalize

    /// Keep things predictable:
    /// - Trim strings (shortName + address fields)
    /// - Drop truly empty locations (no shortName + no address-ish fields)
    /// - De-dupe by shortName (case-insensitive) keeping first
    private func sanitize(_ incoming: [DMPPUserLocation]) -> [DMPPUserLocation] {

        func trim(_ s: String?) -> String? {
            guard let s else { return nil }
            let t = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        func hasAnyContent(_ loc: DMPPUserLocation) -> Bool {
            let sn = loc.shortName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !sn.isEmpty { return true }

            // These property names match what your UI edits.
            if let d = trim(loc.description), !d.isEmpty { return true }
            if let a = trim(loc.streetAddress), !a.isEmpty { return true }
            if let c = trim(loc.city), !c.isEmpty { return true }
            if let s = trim(loc.state), !s.isEmpty { return true }
            if let ctry = trim(loc.country), !ctry.isEmpty { return true }

            return false
        }

        // 1) Trim fields
        var cleaned: [DMPPUserLocation] = incoming.map { loc in
            var v = loc
            v.shortName = v.shortName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            v.description = trim(v.description)
            v.streetAddress = trim(v.streetAddress)
            v.city = trim(v.city)
            v.state = trim(v.state)
            v.country = trim(v.country)
            return v
        }

        // 2) Drop “fully empty” locations
        cleaned = cleaned.filter { hasAnyContent($0) }

        // 3) De-dupe by shortName (case-insensitive) if shortName exists
        var seen = Set<String>()
        cleaned = cleaned.filter { loc in
            let key = loc.shortName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return true } // allow untitled duplicates (rare, but user is mid-edit)
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // 4) Stable sort for file tidiness (alphabetical by shortName)
        cleaned.sort {
            $0.shortName.localizedCaseInsensitiveCompare($1.shortName) == .orderedAscending
        }

        return cleaned
    }
}
