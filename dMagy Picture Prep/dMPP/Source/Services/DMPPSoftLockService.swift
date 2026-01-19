import Foundation

// ================================================================
// DMPPSoftLockService.swift
// cp-2026-01-18-09 — warning-only soft locks (relative-path keyed)
//
// [LOCK] Goals:
// - Warn (only) when another user/session may be editing the SAME picture.
// - No hard blocking.
// - Key by RELATIVE picture path (relative to Picture Library Folder).
//
// Lock files live at:
// <Root>/dMagy Portable Archive Data/_locks/lock_<hash>.json
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

    /// Create or update a lock for a given relative photo path.
    static func upsertLock(root: URL, photoRelPath: String, session: SessionInfo) throws {
        let locksFolder = lockFolderURL(forRoot: root)
        try FileManager.default.createDirectory(at: locksFolder, withIntermediateDirectories: true)

        let url = lockFileURL(locksFolder: locksFolder, photoRelPath: photoRelPath)

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

    /// Read a lock (if present) for a given relative photo path.
    static func readLock(root: URL, photoRelPath: String) -> LockRecord? {
        let locksFolder = lockFolderURL(forRoot: root)
        let url = lockFileURL(locksFolder: locksFolder, photoRelPath: photoRelPath)

        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LockRecord.self, from: data)
    }

    /// Determine whether a lock should be considered "fresh" (warn-worthy).
    /// Default: fresh within 5 minutes.
    static func isFresh(_ lock: LockRecord, now: Date = Date(), freshMinutes: Int = 5) -> Bool {
        guard let last = ISO8601DateFormatter().date(from: lock.lastSeenUTC) else { return false }
        let delta = now.timeIntervalSince(last)
        return delta >= 0 && delta <= Double(freshMinutes * 60)
    }

    /// Delete a lock for a given relative photo path (best effort).
    static func removeLock(root: URL, photoRelPath: String) {
        let locksFolder = lockFolderURL(forRoot: root)
        let url = lockFileURL(locksFolder: locksFolder, photoRelPath: photoRelPath)
        try? FileManager.default.removeItem(at: url)
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

    static func defaultSessionInfo() -> SessionInfo {
        let device = Host.current().localizedName ?? "Mac"
        let user = NSFullUserName() // good enough for v1; can be overridden later
        let session = UserDefaults.standard.string(forKey: "DMPP.SessionID.v1")
            ?? {
                let s = UUID().uuidString
                UserDefaults.standard.set(s, forKey: "DMPP.SessionID.v1")
                return s
            }()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"

        return SessionInfo(
            userDisplayName: user,
            deviceName: device,
            sessionID: session,
            appVersion: version
        )
    }

    // -----------------------------
    // MARK: Private Helpers
    // -----------------------------

    private static func lockFileURL(locksFolder: URL, photoRelPath: String) -> URL {
        let hash = stableHashHex(photoRelPath)
        return locksFolder.appendingPathComponent("lock_\(hash).json")
    }

    private static func stableHashHex(_ s: String) -> String {
        // Simple deterministic hash; good enough for filenames.
        // We can upgrade to SHA256 later if desired.
        var hasher = Hasher()
        hasher.combine(s)
        let value = hasher.finalize()
        // Convert to unsigned-ish hex string
        return String(format: "%016llx", UInt64(bitPattern: Int64(value)))
    }

    private static func existingCreatedAtIfPresent(lockFileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: lockFileURL),
              let record = try? JSONDecoder().decode(LockRecord.self, from: data)
        else { return nil }
        return record.createdAtUTC
    }
}
