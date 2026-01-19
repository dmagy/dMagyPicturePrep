import Foundation
import CryptoKit

// ================================================================
// DMPPSoftLockService.swift
// cp-2026-01-18-09A — warning-only soft locks (relative-path keyed)
// - Uses SHA256 for stable filenames across launches/devices.
//
// [LOCK] Goals:
// - Warn (only) when another user/session may be editing the SAME picture.
// - No hard blocking.
// - Key by RELATIVE picture path (relative to Picture Library Folder).
//
// Lock files live at:
// <Root>/dMagy Portable Archive Data/_locks/lock_<sha256prefix>.json
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

    // [LOCK] Unique per app launch/run (do NOT store in UserDefaults).
    // This makes testing with 2 instances work and prevents false "same session" matches.
    private static let sessionIDForThisRun: String = {
        // Include PID so two instances launched at the same time are guaranteed different.
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


    // -----------------------------
    // MARK: Private Helpers
    // -----------------------------

    private static func lockFileURL(locksFolder: URL, photoRelPath: String) -> URL {
        let hash = stableSHA256HexPrefix(photoRelPath, prefixBytes: 16) // shorter filename, still very safe
        return locksFolder.appendingPathComponent("lock_\(hash).json")
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
