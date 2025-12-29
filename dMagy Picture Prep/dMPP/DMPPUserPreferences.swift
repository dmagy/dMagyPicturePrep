//
//  DMPPUserPreferences.swift
//  dMagy Picture Prep
//
//  dMPP-2025-11-30-PREF1 — User preferences (crop + metadata)
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

    // MARK: - Location preferences (NEW)

    /// User-defined locations used by the Location dropdown.
    /// Examples: "Ashcroft" / "Our Family House" / address fields.
    var userLocations: [DMPPUserLocation] = []

    // MARK: - Location helpers

    /// Sorted for dropdown UI (shortName alpha, then city/state).
    var userLocationsSortedForUI: [DMPPUserLocation] {
        userLocations.sorted { a, b in
            let aName = a.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
            let bName = b.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
            let primary = aName.localizedCaseInsensitiveCompare(bName)
            if primary != .orderedSame { return primary == .orderedAscending }

            let aCity = (a.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let bCity = (b.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let secondary = aCity.localizedCaseInsensitiveCompare(bCity)
            if secondary != .orderedSame { return secondary == .orderedAscending }

            let aState = (a.state ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let bState = (b.state ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return aState.localizedCaseInsensitiveCompare(bState) == .orderedAscending
        }
    }

    /// Finds a saved user location that matches a DmpmsLocation by normalized address key.
    /// Use this after reverse-geocoding to auto-fill shortName/description.
    func matchingUserLocation(for loc: DmpmsLocation?) -> DMPPUserLocation? {
        guard let loc else { return nil }

        func norm(_ s: String?) -> String {
            (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        let key = [
            norm(loc.streetAddress),
            norm(loc.city),
            norm(loc.state),
            norm(loc.country)
        ].joined(separator: "|")

        guard !key.replacingOccurrences(of: "|", with: "").isEmpty else { return nil }
        return userLocations.first(where: { $0.matchKey == key })
    }


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

        // 1) Try current schema
        if var prefs = try? JSONDecoder().decode(DMPPUserPreferences.self, from: data) {
            prefs.ensureReservedTag()
            return prefs
        }

        // 2) Try legacy schema(s) and migrate forward (best-effort)
        if let legacy = try? JSONDecoder().decode(LegacyPrefsV1.self, from: data) {
            var prefs = DMPPUserPreferences()

            prefs.defaultCropPresets = legacy.defaultCropPresets
            prefs.customCropPresets = legacy.customCropPresets
            prefs.availableTags = legacy.availableTags
            prefs.userLocations = legacy.userLocations.map { $0.asCurrent }

            prefs.ensureReservedTag()
            prefs.save() // write back migrated schema
            return prefs
        }

        // 3) Total failure → defaults
        print("dMPP: Failed to decode DMPPUserPreferences, using defaults.")
        var prefs = DMPPUserPreferences()
        prefs.ensureReservedTag()
        return prefs
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



    /// Find a user location that matches an auto-resolved location (address fields).
    /// Uses the matchKey normalization from DMPPUserLocation.
    func matchUserLocation(to resolved: DmpmsLocation) -> DMPPUserLocation? {
        let key = [
            norm(resolved.streetAddress),
            norm(resolved.city),
            norm(resolved.state),
            norm(resolved.country)
        ].joined(separator: "|")

        return userLocations.first(where: { $0.matchKey == key })
    }

    private func norm(_ s: String?) -> String {
        (s ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

// MARK: - Effective defaults

extension DMPPUserPreferences {
    static let mandatoryTagName = "Do Not Display"

    /// Returns the active default crop presets, with safety rules:
    /// - If the user disables all presets, we fall back to `.original` only
    ///   so they can still use dMPP just for metadata.
    /// - Duplicates are removed while preserving order.
    var effectiveDefaultCropPresets: [CropPresetID] {
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

// MARK: - Legacy migrations

/// Legacy prefs format (kept minimal): same key, older Location ID shape, etc.
private struct LegacyPrefsV1: Codable {
    var defaultCropPresets: [DMPPUserPreferences.CropPresetID] = [.landscape16x9, .portrait8x10]
    var customCropPresets: [DMPPUserPreferences.CustomCropPreset] = []
    var availableTags: [String] = [DMPPUserPreferences.reservedDoNotDisplayTag]

    var userLocations: [LegacyUserLocation] = []
}

/// Older location shape that might exist from earlier experiments.
private struct LegacyUserLocation: Codable {
    var id: String
    var shortName: String
    var description: String?
    var streetAddress: String?
    var city: String?
    var state: String?
    var country: String?

    var asCurrent: DMPPUserLocation {
        DMPPUserLocation(
            id: UUID(), // legacy string IDs aren’t worth preserving long-term
            shortName: shortName,
            description: description,
            streetAddress: streetAddress,
            city: city,
            state: state,
            country: country
        )
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted whenever DMPPUserPreferences.save() is called.
    static let dmppPreferencesChanged = Notification.Name("dmppPreferencesChanged")
}
