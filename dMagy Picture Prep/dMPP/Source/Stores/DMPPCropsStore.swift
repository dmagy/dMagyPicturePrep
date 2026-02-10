import Foundation
import Combine

// ================================================================
// DMPPCropStore.swift
// cp-2026-02-07-01 — Crop presets registry stored in portable archive
// ================================================================
//
// Portable file:
//   <Picture Library Folder>/dMagy Portable Archive Data/Crops/crops.json
//
// Schema (current):
//   { "presets":[...], "updatedAtUTC": "..." }
//
// Backward compatible reads:
//   1) [Preset] (plain array)
//
// Notes:
// - This is "vocabulary" (preset definitions), NOT per-photo crops.
// - Per-photo crops remain authoritative in *.dmpms.json sidecars.
// ================================================================

final class DMPPCropStore: ObservableObject {

    // MARK: - Model

    struct Preset: Codable, Identifiable, Equatable, Hashable {
        /// Store as UUID string for portability and stability.
        var id: String

        /// Human label shown in UI (e.g., "Landscape 16:9", "Weird Banner")
        var label: String

        /// Aspect ratio parts (integers like 16 and 9)
        var aspectWidth: Int
        var aspectHeight: Int

        /// Optional: whether the preset is suggested/eligible as a default for new images.
        var isDefaultForNewImages: Bool = false
    }

    // MARK: - Published state

    @Published private(set) var presets: [Preset] = []

    private var archiveRootURL: URL? = nil

    // MARK: - Configure

    func configureForArchiveRoot(_ root: URL?, fallbackPresets: [Preset]? = nil) {
        archiveRootURL = root
        guard let root else { return }

        // Ensure portable folder structure exists (best-effort)
        _ = try? DMPPPortableArchiveBootstrap.ensurePortableArchive(at: root)

        let url = cropsFileURL(forRoot: root)
        let loaded = readAnyCropsFile(url: url)

        if loaded.isEmpty {
            let seeded = sanitize(fallbackPresets ?? [])
            presets = seeded
            writeCropsFile(url: url, presets: seeded)
        } else {
            let cleaned = sanitize(loaded)
            presets = cleaned

            // Keep file tidy if we normalized anything
            if cleaned != loaded {
                writeCropsFile(url: url, presets: cleaned)
            }
        }
    }

    // MARK: - Persist from UI

    func persistPresetsFromUI(_ uiPresets: [Preset]) {
        guard let root = archiveRootURL else { return }
        let url = cropsFileURL(forRoot: root)

        let cleaned = sanitize(uiPresets)
        presets = cleaned
        writeCropsFile(url: url, presets: cleaned)
    }

    // MARK: - URLs (for “Linked file (advanced)”)

    func cropsFileURL() -> URL? {
        guard let root = archiveRootURL else { return nil }
        return cropsFileURL(forRoot: root)
    }

    private func cropsFolderURL(forRoot root: URL) -> URL {
        root
            .appendingPathComponent(DMPPPortableArchiveBootstrap.portableFolderName, isDirectory: true)
            .appendingPathComponent("Crops", isDirectory: true)
    }

    private func cropsFileURL(forRoot root: URL) -> URL {
        cropsFolderURL(forRoot: root).appendingPathComponent("crops.json")
    }

    // MARK: - Read / Write

    private struct WrappedCrops: Codable {
        let presets: [Preset]
        let updatedAtUTC: String
    }

    private func readAnyCropsFile(url: URL) -> [Preset] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [] }

        // 1) Wrapped schema
        if let wrapped = try? JSONDecoder().decode(WrappedCrops.self, from: data) {
            return wrapped.presets
        }

        // 2) Legacy plain array
        if let list = try? JSONDecoder().decode([Preset].self, from: data) {
            return list
        }

        return []
    }

    private func writeCropsFile(url: URL, presets: [Preset]) {
        let payload = WrappedCrops(
            presets: presets,
            updatedAtUTC: ISO8601DateFormatter().string(from: Date())
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(payload)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("dMPP: Failed to write crops.json: \(error)")
        }
    }

    // MARK: - Normalize

    private func sanitize(_ incoming: [Preset]) -> [Preset] {

        func trimmed(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func isValidUUIDString(_ s: String) -> Bool {
            UUID(uuidString: s) != nil
        }

        func newUUIDString() -> String {
            UUID().uuidString
        }

        // 1) Trim + normalize + ensure IDs
        var cleaned: [Preset] = incoming.map { p in
            var v = p

            v.label = trimmed(v.label)

            // Ensure we always have a valid UUID string id
            if trimmed(v.id).isEmpty || !isValidUUIDString(v.id) {
                v.id = newUUIDString()
            }

            // Prevent nonsense ratios
            if v.aspectWidth <= 0 { v.aspectWidth = 1 }
            if v.aspectHeight <= 0 { v.aspectHeight = 1 }

            return v
        }

        // 2) Drop “fully empty” presets (no label)
        cleaned.removeAll { $0.label.isEmpty }

        // 3) De-dupe by (label + ratio) case-insensitive, keep first
        var seen = Set<String>()
        cleaned = cleaned.filter { p in
            let key = "\(p.label.lowercased())|\(p.aspectWidth):\(p.aspectHeight)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // 4) Stable sort: label alpha, then ratio
        cleaned.sort { a, b in
            let c = a.label.localizedCaseInsensitiveCompare(b.label)
            if c != .orderedSame { return c == .orderedAscending }

            let arA = "\(a.aspectWidth):\(a.aspectHeight)"
            let arB = "\(b.aspectWidth):\(b.aspectHeight)"
            return arA.localizedCaseInsensitiveCompare(arB) == .orderedAscending
        }

        return cleaned
    }
    
    func migrateLegacyPrefsIfNeeded(legacyPresets: [DMPPUserPreferences.CustomCropPreset]) {

        // Must be configured first (otherwise persist is a no-op)
        guard archiveRootURL != nil else { return }

        // If portable already has presets, do nothing.
        guard presets.isEmpty else { return }

        // If legacy is empty, do nothing.
        guard !legacyPresets.isEmpty else { return }

        let converted: [Preset] = legacyPresets.map { lp in
            Preset(
                id: lp.id.uuidString,
                label: lp.label,
                aspectWidth: lp.aspectWidth,
                aspectHeight: lp.aspectHeight,
                isDefaultForNewImages: lp.isDefaultForNewImages
            )
        }

        persistPresetsFromUI(converted)

        var prefs = DMPPUserPreferences.load()
        prefs.customCropPresets.removeAll()
        prefs.save()
    }
    /// Merge legacy prefs into portable when BOTH have data, then clear legacy.
    /// This prevents "portable=1 legacy=1" lasting forever.
    func mergeLegacyPrefsIntoPortableThenClear(legacyPresets: [DMPPUserPreferences.CustomCropPreset]) {

        // Must be configured first (otherwise persist is a no-op)
        guard archiveRootURL != nil else { return }

        // If legacy is empty, nothing to do.
        guard !legacyPresets.isEmpty else { return }

        // If portable is empty, let migrateLegacyPrefsIfNeeded handle seeding instead.
        guard !presets.isEmpty else { return }

        // Convert legacy → portable model
        let converted: [Preset] = legacyPresets.map { lp in
            Preset(
                id: lp.id.uuidString,
                label: lp.label,
                aspectWidth: lp.aspectWidth,
                aspectHeight: lp.aspectHeight,
                isDefaultForNewImages: lp.isDefaultForNewImages
            )
        }

        // Merge + de-dupe using your store sanitize() by just persisting combined list
        let combined = presets + converted
        persistPresetsFromUI(combined)

        // Clear legacy so we don’t keep reporting both sources
        var prefs = DMPPUserPreferences.load()
        prefs.customCropPresets.removeAll()
        prefs.save()
    }


}
