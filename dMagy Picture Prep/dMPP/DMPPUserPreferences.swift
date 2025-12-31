//
//  DMPPUserPreferences.swift
//  dMagy Picture Prep
//
//  dMPP-2025-11-30-PREF1 — User preferences (crop + metadata)
//  cp-2025-12-30-TAGS2 — Add reserved "Flagged" tag (undeletable)
//

import Foundation

/// [DMPP-PREFS] Container for all user-level preferences.
/// Designed to be extendable (metadata defaults, UI options, etc.).
struct DMPPUserPreferences: Codable, Equatable {

    // MARK: - Constants (Reserved / undeletable tags)

    /// Canonical reserved tag used by dMagy apps to hide photos from slideshows.
    /// This tag is:
    /// - Always present in `availableTags`
    /// - Not renamable or deletable in Settings
    static let reservedDoNotDisplayTag = "Do Not Display"

    /// Canonical reserved tag used by dMagy apps to mark photos for follow-up / review.
    /// This tag is:
    /// - Always present in `availableTags`
    /// - Not renamable or deletable in Settings
    static let reservedFlaggedTag = "Flagged"

    /// Reserved tags in the order you want them to appear at the top of Settings + checkboxes.
    static let reservedTagsInOrder: [String] = [
        DMPPUserPreferences.reservedDoNotDisplayTag,
        DMPPUserPreferences.reservedFlaggedTag
    ]

    static func isReservedTag(_ tag: String) -> Bool {
        let t = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return reservedTagsInOrder.contains { $0.lowercased() == t }
    }

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
    /// - Reserved tags are mandatory and enforced via `ensureReservedTags()`.
    var availableTags: [String] = [
        "Halloween",
        "NSFW",
        DMPPUserPreferences.reservedDoNotDisplayTag,
        DMPPUserPreferences.reservedFlaggedTag
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
            prefs.ensureReservedTags()
            return prefs
        }

        // 1) Try current schema
        if var prefs = try? JSONDecoder().decode(DMPPUserPreferences.self, from: data) {
            prefs.ensureReservedTags()
            return prefs
        }

        // 2) Try legacy schema(s) and migrate forward (best-effort)
        if let legacy = try? JSONDecoder().decode(LegacyPrefsV1.self, from: data) {
            var prefs = DMPPUserPreferences()

            prefs.defaultCropPresets = legacy.defaultCropPresets
            prefs.customCropPresets = legacy.customCropPresets
            prefs.availableTags = legacy.availableTags
            prefs.userLocations = legacy.userLocations.map { $0.asCurrent }

            prefs.ensureReservedTags()
            prefs.save() // write back migrated schema
            return prefs
        }

        // 3) Total failure → defaults
        print("dMPP: Failed to decode DMPPUserPreferences, using defaults.")
        var prefs = DMPPUserPreferences()
        prefs.ensureReservedTags()
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

    /// Ensure that reserved tags:
    /// - Exist exactly once each (case-insensitive)
    /// - Are in canonical form
    /// - Appear at the top of `availableTags` in `reservedTagsInOrder` order
    mutating func ensureReservedTags() {
        // Remove any variants (case-insensitive) of any reserved tag.
        let reservedLower = Set(Self.reservedTagsInOrder.map { $0.lowercased() })
        availableTags.removeAll { reservedLower.contains($0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }

        // Insert canonical versions at the front, in desired order.
        for (idx, tag) in Self.reservedTagsInOrder.enumerated() {
            availableTags.insert(tag, at: idx)
        }
    }

    /// Back-compat for older call sites.
    /// (Some parts of the app may still call ensureReservedTag().)
    mutating func ensureReservedTag() {
        ensureReservedTags()
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

    /// Back-compat for older Settings UI that only knew about a single mandatory tag.
    static let mandatoryTagName = DMPPUserPreferences.reservedDoNotDisplayTag

    /// Use this for new UI logic (lock both).
    static let mandatoryTagNames = DMPPUserPreferences.reservedTagsInOrder

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
