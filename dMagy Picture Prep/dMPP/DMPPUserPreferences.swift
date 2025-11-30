//
//  DMPPUserPreferences.swift
//  dMagy Picture Prep
//
//  dMPP-2025-11-30-PREF1 — User preferences (crop + future metadata)
//

import Foundation

/// [DMPP-PREFS] Container for all user-level preferences.
/// Designed to be extendable (metadata defaults, UI options, etc.).
struct DMPPUserPreferences: Codable {

    // MARK: - Crop presets

    /// Known built-in crop presets that can be used as defaults for new images.
    enum CropPresetID: String, Codable, CaseIterable {
        case original          // Original (full image)
        case landscape16x9     // Landscape 16:9
        case portrait8x10      // Portrait 8×10 (4:5)
        case headshot8x10      // Headshot 8×10 (uses guides)
        case landscape4x6      // Landscape 4×6 (3:2)
        case square1x1         // Square 1:1

        // NOTE: Freeform is *per-image* and created explicitly;
        // we do not auto-create it as a default preset.
    }

    /// Which presets should be auto-created when an image has no crops.
    /// Order is preserved.
    var defaultCropPresets: [CropPresetID] = [
        .landscape16x9,
        .portrait8x10
    ]

    // MARK: - Future metadata defaults

    /// Placeholder for future metadata defaults (title/date/tag behavior, etc.)
    /// Add fields here later as needed.
    // struct MetadataDefaults: Codable {
    //     var defaultDatePattern: String?
    //     var autoTagFromFolder: Bool
    // }
    //
    // var metadataDefaults: MetadataDefaults? = nil

    // MARK: - Persistence

    private static let storageKey = "dmpp_userPreferences"

    /// Load preferences from UserDefaults, or fall back to sensible defaults.
    static func load() -> DMPPUserPreferences {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: storageKey) else {
            return DMPPUserPreferences()   // default initializer
        }

        do {
            return try JSONDecoder().decode(DMPPUserPreferences.self, from: data)
        } catch {
            print("dMPP: Failed to decode DMPPUserPreferences, using defaults. Error: \(error)")
            return DMPPUserPreferences()
        }
    }

    /// Save preferences to UserDefaults.
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            print("dMPP: Failed to encode DMPPUserPreferences: \(error)")
        }
    }
}
extension DMPPUserPreferences {

    /// Returns the active default crop presets, with safety rules:
    /// - If the user disables all presets, we fall back to `.original` only
    ///   so they can still use dMPP just for metadata.
    /// - Duplicates are removed while preserving order.
    var effectiveDefaultCropPresets: [CropPresetID] {
        // If the user turned everything off, treat this as "metadata only",
        // but still create an Original (full image) crop.
        let base: [CropPresetID] =
            defaultCropPresets.isEmpty ? [.original] : defaultCropPresets

        var seen = Set<CropPresetID>()
        var result: [CropPresetID] = []

        for preset in base {
            if !seen.contains(preset) {
                seen.insert(preset)
                result.append(preset)
            }
        }
        return result
    }
}
