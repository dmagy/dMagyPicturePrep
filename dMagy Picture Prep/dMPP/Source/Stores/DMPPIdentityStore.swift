//
//  DMPPIdentityStore.swift
//  dMagy Picture Prep
//
//  dMPP-2025-12-08-ID1 — Identity store (load/save/query + favorites)
//

import Foundation
import Observation

/// [DMPP-IDENTITY-STORE]
/// Application-wide store for identity records (`DmpmsIdentity`).
///
/// Responsibilities:
/// - Load/save a single JSON file containing all identities.
/// - Provide simple query helpers for favorites vs others.
/// - Offer stable, sorted lists for UI (favorites first, then alphabetical).
///
/// NOTE:
/// This is intentionally *not* tied to any particular view;
/// it can be injected into future identity pickers, people panes, etc.
@Observable
final class DMPPIdentityStore {

    /// Shared singleton used throughout the app.
    static let shared = DMPPIdentityStore()

    /// Convenience loader used by views that expect a `load()` factory.
    /// For now this simply returns the shared singleton.
    static func load() -> DMPPIdentityStore {
        DMPPIdentityStore.shared
    }

    /// In-memory list of all identities.
    /// This is the single source of truth for identity records in dMPP.
    private(set) var identities: [DmpmsIdentity] = []

    /// Backwards-friendly alias for `identities` so older code that
    /// refers to `identityStore.people` still compiles.
    ///
    /// This is a full get/set computed property so callers can
    /// modify `people` (append/remove/etc.) and those changes
    /// are applied to the underlying `identities` array.
    var people: [DmpmsIdentity] {
        get { identities }
        set { identities = newValue }
    }


    /// Backing file path for persistence.
    private let storeURL: URL

    // MARK: - Init

    private init() {
        self.storeURL = DMPPIdentityStore.defaultStoreURL()
        self.identities = DMPPIdentityStore.loadFromDisk(at: storeURL)
    }

    // MARK: - Public API

    /// Reloads identities from disk, discarding any in-memory changes
    /// that have not been saved. Intended for future "Reload" / debug hooks.
    func refreshFromDisk() {
        identities = DMPPIdentityStore.loadFromDisk(at: storeURL)
    }

    /// Persists the current in-memory identities to disk.
    func save() {
        DMPPIdentityStore.saveToDisk(identities, at: storeURL)
    }

    /// Returns all identities sorted for UI:
    /// - Favorites first, then non-favorites
    /// - Alphabetical by `shortName` (case-insensitive) within each group.
    var identitiesSortedForUI: [DmpmsIdentity] {
        let (favorites, others) = identities.partitionedByFavorite()
        return favorites.sortedByShortName() + others.sortedByShortName()
    }

    /// Convenience: favorites only, sorted by short name.
    var favoriteIdentities: [DmpmsIdentity] {
        identities.filter { $0.isFavorite }.sortedByShortName()
    }

    /// Convenience: non-favorites only, sorted by short name.
    var nonFavoriteIdentities: [DmpmsIdentity] {
        identities.filter { !$0.isFavorite }.sortedByShortName()
    }

    /// Look up an identity by its `id`.
    func identity(withID id: String) -> DmpmsIdentity? {
        identities.first { $0.id == id }
    }

    /// Look up all identities that share a `shortName`.
    /// This is useful for people who have multiple identity versions
    /// (e.g., pre-/post-marriage surname).
    func identities(withShortName shortName: String) -> [DmpmsIdentity] {
        identities.filter { $0.shortName == shortName }
    }

    /// Insert or replace an identity by `id`.
    /// - If an identity with the same `id` exists, it is updated in-place.
    /// - Otherwise, the identity is appended.
    func upsert(_ identity: DmpmsIdentity) {
        if let idx = identities.firstIndex(where: { $0.id == identity.id }) {
            identities[idx] = identity
        } else {
            identities.append(identity)
        }
        save()
    }

    /// Removes an identity by `id`.
    func delete(identityID: String) {
        identities.removeAll { $0.id == identityID }
        save()
    }

    /// Ensures that short names remain unique by checking whether any
    /// identity (other than the provided one, if any) already uses it.
    func isShortNameInUse(_ shortName: String, excludingID: String? = nil) -> Bool {
        identities.contains { identity in
            if let excludingID, identity.id == excludingID {
                return false
            }
            return identity.shortName == shortName
        }
    }

    // MARK: - Storage Locations

    /// Default location for the identity store JSON:
    ///   ~/Library/Application Support/dMagyPicturePrep/identities.json
    private static func defaultStoreURL() -> URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory

        let folder = appSupport.appendingPathComponent("dMagyPicturePrep", isDirectory: true)

        if !fm.fileExists(atPath: folder.path) {
            do {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("dMPP: Failed to create identity store directory at \(folder.path): \(error)")
            }
        }

        return folder.appendingPathComponent("identities.json")
    }

    // MARK: - Disk I/O

    private static func loadFromDisk(at url: URL) -> [DmpmsIdentity] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            // No file yet → start with an empty list.
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([DmpmsIdentity].self, from: data)
            return decoded
        } catch {
            print("dMPP: Failed to load identity store from \(url.path): \(error)")
            return []
        }
    }

    private static func saveToDisk(_ identities: [DmpmsIdentity], at url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]

            let data = try encoder.encode(identities)
            try data.write(to: url, options: .atomic)

        } catch {
            print("dMPP: Failed to save identity store to \(url.path): \(error)")
        }
    }
}

// MARK: - Small helpers for sorting/partitioning

private extension Array where Element == DmpmsIdentity {

    func sortedByShortName() -> [DmpmsIdentity] {
        self.sorted { a, b in
            a.shortName.lowercased() < b.shortName.lowercased()
        }
    }

    func partitionedByFavorite() -> (favorites: [DmpmsIdentity], others: [DmpmsIdentity]) {
        var favorites: [DmpmsIdentity] = []
        var others: [DmpmsIdentity] = []

        for identity in self {
            if identity.isFavorite {
                favorites.append(identity)
            } else {
                others.append(identity)
            }
        }
        return (favorites, others)
    }
}
