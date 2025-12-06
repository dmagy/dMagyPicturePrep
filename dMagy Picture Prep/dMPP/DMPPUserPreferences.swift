//
//  DMPPUserPreferences.swift
//  dMagy Picture Prep
//
//  dMPP-2025-11-30-PREF1 — User preferences (crop + future metadata)
//

import Foundation

/// [DMPP-PREFS] Container for all user-level preferences.
/// Designed to be extendable (metadata defaults, UI options, etc.).
struct DMPPUserPreferences: Codable, Equatable {

    // MARK: - Constants

    /// Canonical reserved tag used by dMagy apps to hide photos from slideshows.
    /// This tag is:
    /// - Always present in `availableTags`
    /// - Not renamable or deletable in Settings
    static let reservedDoNotDisplayTag = "Do Not Display"

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

    /// User-defined custom crop preset.
    struct CustomCropPreset: Codable, Identifiable, Equatable {
        var id: UUID
        var label: String
        var aspectWidth: Int
        var aspectHeight: Int
        var isDefaultForNewImages: Bool
    }

    /// Which built-in presets should be auto-created when an image has no crops.
    /// Order is preserved.
    var defaultCropPresets: [CropPresetID] = [
        .landscape16x9,
        .portrait8x10
    ]

    /// User-defined custom crop presets.
    var customCropPresets: [CustomCropPreset] = []

    // MARK: - Tag preferences

    /// Tags offered as checkboxes in the editor.
    /// - "Do Not Display" is mandatory and enforced via `ensureReservedTag()`.
    var availableTags: [String] = [
        "Halloween",
        "NSFW",
        DMPPUserPreferences.reservedDoNotDisplayTag
    ]

    // MARK: - Future metadata defaults

    /// Placeholder for future metadata defaults (title/date/tag behavior, etc.)
    /// Add fields here later as needed.
    // struct MetadataDefaults: Codable, Equatable {
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
            // Fresh defaults
            var prefs = DMPPUserPreferences()
            prefs.ensureReservedTag()
            return prefs
        }

        do {
            var prefs = try JSONDecoder().decode(DMPPUserPreferences.self, from: data)
            prefs.ensureReservedTag()
            return prefs
        } catch {
            print("dMPP: Failed to decode DMPPUserPreferences, using defaults. Error: \(error)")
            var prefs = DMPPUserPreferences()
            prefs.ensureReservedTag()
            return prefs
        }
    }

    /// Save preferences to UserDefaults and broadcast a change notification.
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
            NotificationCenter.default.post(name: .dmppPreferencesChanged, object: nil)
        } catch {
            print("dMPP: Failed to encode DMPPUserPreferences: \(error)")
        }
    }

    // MARK: - Enforcement helpers

    /// Ensure that the reserved "Do Not Display" tag:
    /// - Exists exactly once
    /// - Is in canonical form and appears at the top of `availableTags`.
    mutating func ensureReservedTag() {
        let lowerReserved = Self.reservedDoNotDisplayTag.lowercased()

        // Remove any variants (case-insensitive) of the reserved tag.
        availableTags.removeAll { $0.lowercased() == lowerReserved }

        // Insert the canonical version at the front.
        availableTags.insert(Self.reservedDoNotDisplayTag, at: 0)
    }
}

// MARK: - Effective defaults

extension DMPPUserPreferences {
    static let mandatoryTagName = "Do Not Display";
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

// MARK: - Notification name

extension Notification.Name {
    /// Posted whenever DMPPUserPreferences.save() is called.
    static let dmppPreferencesChanged = Notification.Name("dmppPreferencesChanged")
}
