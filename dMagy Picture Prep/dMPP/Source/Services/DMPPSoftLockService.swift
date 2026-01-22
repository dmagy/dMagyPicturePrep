import Foundation
import CryptoKit

// ================================================================
// DMPPSoftLockService.swift
// cp-2026-01-21-05 — warning-only soft locks (record-per-session)
// - Uses SHA256(relPath) for stable per-picture folder names.
// - Each session writes its OWN lock file so sessions do not overwrite each other.
//
// [LOCK] Goals:
// - Warn (only) when another user/session may be editing the SAME picture.
// - No hard blocking.
// - Key by RELATIVE picture path (relative to Picture Library Folder).
// - Cloud-sync friendly (Drive/Dropbox): no merge conflicts from shared single file.
//
// Lock files live at:
// <Root>/dMagy Portable Archive Data/_locks/<sha256prefix>/lock_<sessionID>.json
// ================================================================

enum DMPPSoftLockService {

    // -----------------------------
    // MARK: Public Types
    // -----------------------------

    struct LockRecord: Codable {
        let photoRelPath: String
        let createdAtUTC: String
        var lastSeenUTC: String
        let userDisplayName: String
        let deviceName: String
        let sessionID: String
        let appVersion: String
    }

    // -----------------------------
    // MARK: Public API
    // -----------------------------

    static func lockFolderURL(forRoot root: URL) -> URL {
        root
            .appendingPathComponent(DMPPPortableArchiveBootstrap.portableFolderName, isDirectory: true)
            .appendingPathComponent("_locks", isDirectory: true)
    }

    /// Create or update THIS SESSION's lock for a given relative photo path.
    static func upsertLock(root: URL, photoRelPath: String, session: SessionInfo) throws {
        let locksFolder = lockFolderURL(forRoot: root)
        try FileManager.default.createDirectory(at: locksFolder, withIntermediateDirectories: true)

        // Per-picture folder (stable across devices)
        let pictureFolder = pictureLockFolderURL(locksFolder: locksFolder, photoRelPath: photoRelPath)
        try FileManager.default.createDirectory(at: pictureFolder, withIntermediateDirectories: true)

        // Per-session lock file (prevents last-writer-wins)
        let url = lockFileURL(pictureFolder: pictureFolder, sessionID: session.sessionID)

        let now = ISO8601DateFormatter().string(from: Date())
        let created = existingCreatedAtIfPresent(lockFileURL: url) ?? now

        let record = LockRecord(
            photoRelPath: photoRelPath,
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

    /// Read ALL locks (all sessions) for a given relative photo path.
    /// This returns both fresh and stale; callers can filter with isFresh().
    static func readLocks(root: URL, photoRelPath: String) -> [LockRecord] {
        let locksFolder = lockFolderURL(forRoot: root)
        let pictureFolder = pictureLockFolderURL(locksFolder: locksFolder, photoRelPath: photoRelPath)

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: pictureFolder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

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

    /// Convenience: return all FRESH locks for this picture.
    static func readFreshLocks(root: URL, photoRelPath: String, freshMinutes: Int = 5) -> [LockRecord] {
        let now = Date()
        return readLocks(root: root, photoRelPath: photoRelPath)
            .filter { isFresh($0, now: now, freshMinutes: freshMinutes) }
    }

    /// Determine whether a lock should be considered "fresh" (warn-worthy).
    /// Default: fresh within 5 minutes.
    static func isFresh(_ lock: LockRecord, now: Date = Date(), freshMinutes: Int = 5) -> Bool {
        guard let last = ISO8601DateFormatter().date(from: lock.lastSeenUTC) else { return false }
        let delta = now.timeIntervalSince(last)
        return delta >= 0 && delta <= Double(freshMinutes * 60)
    }

    /// Should we warn? True when ANY OTHER session has a fresh lock on this picture.
    static func shouldWarn(root: URL, photoRelPath: String, currentSessionID: String, freshMinutes: Int = 5) -> Bool {
        let fresh = readFreshLocks(root: root, photoRelPath: photoRelPath, freshMinutes: freshMinutes)
        return fresh.contains { $0.sessionID != currentSessionID }
    }

    /// Return the list of OTHER sessions that are actively editing (fresh locks).
    static func activeOtherSessions(root: URL, photoRelPath: String, currentSessionID: String, freshMinutes: Int = 5) -> [LockRecord] {
        let fresh = readFreshLocks(root: root, photoRelPath: photoRelPath, freshMinutes: freshMinutes)
        return fresh.filter { $0.sessionID != currentSessionID }
    }

    /// Delete THIS SESSION's lock for a given relative photo path (best effort).
    static func removeLock(root: URL, photoRelPath: String, sessionID: String) {
        let locksFolder = lockFolderURL(forRoot: root)
        let pictureFolder = pictureLockFolderURL(locksFolder: locksFolder, photoRelPath: photoRelPath)
        let url = lockFileURL(pictureFolder: pictureFolder, sessionID: sessionID)
        try? FileManager.default.removeItem(at: url)

        // Optional cleanup: remove the picture folder if empty.
        if let remaining = try? FileManager.default.contentsOfDirectory(atPath: pictureFolder.path),
           remaining.isEmpty {
            try? FileManager.default.removeItem(at: pictureFolder)
        }
    }

    /// Optional cleanup: prune stale lock files for this picture (best effort).
    /// Useful to reduce clutter in synced folders.
    static func pruneStaleLocks(root: URL, photoRelPath: String, freshMinutes: Int = 5) {
        let locksFolder = lockFolderURL(forRoot: root)
        let pictureFolder = pictureLockFolderURL(locksFolder: locksFolder, photoRelPath: photoRelPath)

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: pictureFolder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        let now = Date()
        for url in urls where url.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: url),
                  let rec = try? JSONDecoder().decode(LockRecord.self, from: data)
            else { continue }

            if !isFresh(rec, now: now, freshMinutes: freshMinutes) {
                try? FileManager.default.removeItem(at: url)
            }
        }

        // Remove folder if empty after pruning.
        if let remaining = try? FileManager.default.contentsOfDirectory(atPath: pictureFolder.path),
           remaining.isEmpty {
            try? FileManager.default.removeItem(at: pictureFolder)
        }
    }

    // -----------------------------
    // MARK: Session Info
    // -----------------------------

    struct SessionInfo {
        let userDisplayName: String
        let deviceName: String
        let sessionID: String
        let appVersion: String
    }

    // [LOCK] Unique per app launch/run (do NOT store in UserDefaults).
    // Include PID so two instances launched at the same time are guaranteed different.
    private static let sessionIDForThisRun: String = {
        "\(UUID().uuidString)-pid\(ProcessInfo.processInfo.processIdentifier)"
    }()

    static func defaultSessionInfo() -> SessionInfo {
        let device = Host.current().localizedName ?? "Mac"
        let user = NSFullUserName() // fine for v1; can be overridden later
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"

        return SessionInfo(
            userDisplayName: user,
            deviceName: device,
            sessionID: sessionIDForThisRun,
            appVersion: version
        )
    }

    /// Expose current sessionID for callers (editor view) that need to compare.
    static func currentSessionID() -> String {
        sessionIDForThisRun
    }

    // -----------------------------
    // MARK: Private Helpers
    // -----------------------------

    private static func pictureLockFolderURL(locksFolder: URL, photoRelPath: String) -> URL {
        let hash = stableSHA256HexPrefix(photoRelPath, prefixBytes: 16)
        return locksFolder.appendingPathComponent(hash, isDirectory: true)
    }

    private static func lockFileURL(pictureFolder: URL, sessionID: String) -> URL {
        // SessionID includes UUID+pid; safe as filename, but sanitize lightly anyway.
        let safeSession = sessionID
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return pictureFolder.appendingPathComponent("lock_\(safeSession).json")
    }

    private static func stableSHA256HexPrefix(_ s: String, prefixBytes: Int) -> String {
        let data = Data(s.utf8)
        let digest = SHA256.hash(data: data)
        let bytes = Array(digest)

        let count = max(1, min(prefixBytes, bytes.count))
        return bytes.prefix(count).map { String(format: "%02x", $0) }.joined()
    }

    private static func existingCreatedAtIfPresent(lockFileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: lockFileURL),
              let record = try? JSONDecoder().decode(LockRecord.self, from: data)
        else { return nil }
        return record.createdAtUTC
    }
}
