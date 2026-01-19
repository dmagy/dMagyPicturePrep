import Foundation

// ================================================================
// DMPPPortableArchiveBootstrap.swift
// cp-2026-01-18-02 — create portable archive folder structure + copy README/PDF
//
// [BOOT] Called after Archive Root is known.
// Ensures: <Archive Root>/dMagy Portable Archive Data exists + required subfolders.
// Copies bundled _Read_Me_.pdf + README.md if missing (does NOT overwrite README).
// ================================================================

enum DMPPPortableArchiveBootstrap {

    // [BOOT] Single source of truth for the folder name.
    static let portableFolderName = "dMagy Portable Archive Data"

    // [BOOT] Required subfolders inside portable folder.
    static let requiredSubfolders: [String] = [
        "People",
        "Locations",
        "Tags",
        "Crops",
        "_locks",   // relative-path soft locks live here (warning only)
        "_meta",
        "_indexes"  // treat as cache/rebuildable
    ]

    // [BOOT] Public entry point.
    static func ensurePortableArchive(at archiveRootURL: URL) throws -> URL {
        let fm = FileManager.default

        // [BOOT] Build the portable folder path.
        let portableURL = archiveRootURL.appendingPathComponent(portableFolderName, isDirectory: true)

        // [BOOT] Create portable folder if missing.
        try fm.createDirectory(at: portableURL, withIntermediateDirectories: true)

        // [BOOT] Create required subfolders.
        for folder in requiredSubfolders {
            let sub = portableURL.appendingPathComponent(folder, isDirectory: true)
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        }

        // [BOOT] Copy README + PDF from app bundle (if missing).
        try copyBundledResourceIfMissing(
            resourceName: "README",
            resourceExtension: "md",
            destinationURL: portableURL.appendingPathComponent("README.md"),
            allowOverwrite: false // do NOT overwrite user edits
        )

        try copyBundledResourceIfMissing(
            resourceName: "_Read_Me_",
            resourceExtension: "pdf",
            destinationURL: portableURL.appendingPathComponent("_Read_Me_.pdf"),
            allowOverwrite: false // only copy if missing
        )

        // [BOOT] Ensure schema version metadata exists.
        try ensureSchemaVersionFile(at: portableURL.appendingPathComponent("_meta", isDirectory: true))

        return portableURL
    }

    // ------------------------------------------------------------
    // [BOOT-RES] Copy bundled resource to destination, only if needed.
    // ------------------------------------------------------------
    private static func copyBundledResourceIfMissing(
        resourceName: String,
        resourceExtension: String,
        destinationURL: URL,
        allowOverwrite: Bool
    ) throws {
        let fm = FileManager.default

        if fm.fileExists(atPath: destinationURL.path) {
            if allowOverwrite {
                try fm.removeItem(at: destinationURL)
            } else {
                return
            }
        }

        guard let sourceURL = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) else {
            throw NSError(
                domain: "DMPPPortableArchiveBootstrap",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing bundled resource: \(resourceName).\(resourceExtension)"]
            )
        }

        try fm.copyItem(at: sourceURL, to: destinationURL)
    }

    // ------------------------------------------------------------
    // [BOOT-META] Minimal schema version metadata.
    // ------------------------------------------------------------
    private static func ensureSchemaVersionFile(at metaFolderURL: URL) throws {
        let fm = FileManager.default
        let schemaURL = metaFolderURL.appendingPathComponent("schemaVersion.json")

        if fm.fileExists(atPath: schemaURL.path) { return }

        let payload: [String: Any] = [
            "schemaVersion": 1,
            "createdAtUTC": ISO8601DateFormatter().string(from: Date())
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: schemaURL, options: [.atomic])
    }
}
