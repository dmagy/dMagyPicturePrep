import Foundation

// ================================================================
// DMPPRegistryLockService.swift
// cp-2026-01-21-07 — hard-lock support for shared registries (Settings)
//
// [LOCK] Purpose:
// - Provide "named resource" locks (e.g., Settings) stored under:
//   <Root>/dMagy Portable Archive Data/_locks/_registries/<resourceKey>/lock_<sessionID>.json
//
// - Uses the same LockRecord schema as DMPPSoftLockService for consistency.
// - Warning/Hard-lock decision happens in the UI layer (gate view).
// ================================================================

enum DMPPRegistryLockService {

    // [LOCK] Reuse the same record format for compatibility/consistency.
    typealias LockRecord = DMPPSoftLockService.LockRecord
    typealias SessionInfo = DMPPSoftLockService.SessionInfo

    // -----------------------------
    // MARK: Public Resource Keys
    // -----------------------------

    // Stable key for Settings as a whole (hard lock target).
    static let resourceSettings = "settings"

    // -----------------------------
    // MARK: Public API
    // -----------------------------

    static func upsertLock(root: URL, resourceKey: String, session: SessionInfo) throws {
        let folder = resourceFolderURL(root: root, resourceKey: resourceKey)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let url = lockFileURL(folder: folder, sessionID: session.sessionID)

        let now = ISO8601DateFormatter().string(from: Date())
        let created = existingCreatedAtIfPresent(lockFileURL: url) ?? now

        let record = LockRecord(
            photoRelPath: "REGISTRY:\(resourceKey)", // informational only
            createdAtUTC: created,
            lastSeenUTC: now,
            userDisplayName: session.userDisplayName,
            deviceName: session.deviceName,
            sessionID: session.sessionID,
            appVersion: session.appVersion
        )

        let data = try JSONEncoder().encode(record)
        try data.write(to: url, options: [.atomic])
    }

    static func readLocks(root: URL, resourceKey: String) -> [LockRecord] {
        let folder = resourceFolderURL(root: root, resourceKey: resourceKey)

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var records: [LockRecord] = []
        records.reserveCapacity(urls.count)

        for url in urls where url.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: url),
                  let rec = try? JSONDecoder().decode(LockRecord.self, from: data)
            else { continue }
            records.append(rec)
        }

        return records
    }

    static func readFreshLocks(root: URL, resourceKey: String, freshMinutes: Int = 5) -> [LockRecord] {
        let now = Date()
        return readLocks(root: root, resourceKey: resourceKey)
            .filter { DMPPSoftLockService.isFresh($0, now: now, freshMinutes: freshMinutes) }
    }

    static func activeOtherSessions(root: URL, resourceKey: String, currentSessionID: String, freshMinutes: Int = 5) -> [LockRecord] {
        let fresh = readFreshLocks(root: root, resourceKey: resourceKey, freshMinutes: freshMinutes)
        return fresh.filter { $0.sessionID != currentSessionID }
    }

    static func removeLock(root: URL, resourceKey: String, sessionID: String) {
        let folder = resourceFolderURL(root: root, resourceKey: resourceKey)
        let url = lockFileURL(folder: folder, sessionID: sessionID)
        try? FileManager.default.removeItem(at: url)

        // Optional cleanup: remove folder if empty
        if let remaining = try? FileManager.default.contentsOfDirectory(atPath: folder.path),
           remaining.isEmpty {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    static func pruneStaleLocks(root: URL, resourceKey: String, freshMinutes: Int = 5) {
        let folder = resourceFolderURL(root: root, resourceKey: resourceKey)

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        let now = Date()

        for url in urls where url.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: url),
                  let rec = try? JSONDecoder().decode(LockRecord.self, from: data)
            else { continue }

            if !DMPPSoftLockService.isFresh(rec, now: now, freshMinutes: freshMinutes) {
                try? FileManager.default.removeItem(at: url)
            }
        }

        if let remaining = try? FileManager.default.contentsOfDirectory(atPath: folder.path),
           remaining.isEmpty {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    // -----------------------------
    // MARK: Private Helpers
    // -----------------------------

    private static func resourceFolderURL(root: URL, resourceKey: String) -> URL {
        let locks = DMPPSoftLockService.lockFolderURL(forRoot: root)
        let registries = locks.appendingPathComponent("_registries", isDirectory: true)
        let safeKey = sanitizeResourceKey(resourceKey)
        return registries.appendingPathComponent(safeKey, isDirectory: true)
    }

    private static func lockFileURL(folder: URL, sessionID: String) -> URL {
        let safeSession = sessionID
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return folder.appendingPathComponent("lock_\(safeSession).json")
    }

    private static func sanitizeResourceKey(_ key: String) -> String {
        // Keep it folder-safe and stable.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return key.lowercased().unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }.reduce("") { $0 + String($1) }
    }

    private static func existingCreatedAtIfPresent(lockFileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: lockFileURL),
              let record = try? JSONDecoder().decode(LockRecord.self, from: data)
        else { return nil }
        return record.createdAtUTC
    }
}
