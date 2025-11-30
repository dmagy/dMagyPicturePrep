//
//  DmpmsMetadata.swift
//  dMagy Picture Prep
//

import Foundation

// dMPMS-2025-11-30-M2 — Core metadata models (+ human-facing notice)

/* [DMPMS-META] Complete dMPMS metadata structure. */
struct DmpmsMetadata: Codable, Hashable {

    /// Default human-readable warning written into every sidecar.
    /// Intent: gently tell humans not to delete the file.
    static let defaultNotice = """
    Created by dMagy Picture Prep. Stores metadata and crop settings for this photo. Deleting it erases edits (not the original image).
    """

    // Core version for the dMPMS spec.
    var dmpmsVersion: String = "1.0"

    /// Human-facing notice so people know what this file is.
    /// Always included near the top of the JSON.
    var dmpmsNotice: String = DmpmsMetadata.defaultNotice

    /// Image filename (with extension) this sidecar belongs to.
    var sourceFile: String

    // Basic fields
    var title: String = ""
    var description: String = ""
    var dateTaken: String = ""
    var tags: [String] = []
    var people: [String] = []

    // Crops + history
    var virtualCrops: [VirtualCrop] = []
    var history: [HistoryEvent] = []

    // Explicit key order for encoding/decoding.
    // JSONEncoder (without .sortedKeys) will follow this order.
    enum CodingKeys: String, CodingKey {
        case dmpmsVersion
        case dmpmsNotice
        case sourceFile
        case title
        case description
        case dateTaken
        case tags
        case people
        case virtualCrops
        case history
    }

    // MARK: - Designated init (used by code)

    init(
        dmpmsVersion: String = "1.0",
        dmpmsNotice: String = DmpmsMetadata.defaultNotice,
        sourceFile: String,
        title: String = "",
        description: String = "",
        dateTaken: String = "",
        tags: [String] = [],
        people: [String] = [],
        virtualCrops: [VirtualCrop] = [],
        history: [HistoryEvent] = []
    ) {
        self.dmpmsVersion = dmpmsVersion
        self.dmpmsNotice = dmpmsNotice
        self.sourceFile = sourceFile
        self.title = title
        self.description = description
        self.dateTaken = dateTaken
        self.tags = tags
        self.people = people
        self.virtualCrops = virtualCrops
        self.history = history
    }

    // MARK: - Codable (backward compatible with older sidecars)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required
        dmpmsVersion = try container.decode(String.self, forKey: .dmpmsVersion)

        // New, optional in old files → fall back to defaultNotice
        dmpmsNotice = (try? container.decode(String.self, forKey: .dmpmsNotice))
            ?? DmpmsMetadata.defaultNotice

        sourceFile   = try container.decode(String.self, forKey: .sourceFile)
        title        = try container.decode(String.self, forKey: .title)
        description  = try container.decode(String.self, forKey: .description)
        dateTaken    = try container.decode(String.self, forKey: .dateTaken)
        tags         = try container.decode([String].self, forKey: .tags)
        people       = try container.decode([String].self, forKey: .people)
        virtualCrops = try container.decode([VirtualCrop].self, forKey: .virtualCrops)
        history      = try container.decode([HistoryEvent].self, forKey: .history)
    }

    // Encodable is synthesized; it will use CodingKeys order and include dmpmsNotice.
}

/* [DMPMS-HISTORY] Simple history event. */
struct HistoryEvent: Codable, Hashable {
    var action: String
    var timestamp: String
    var oldName: String? = nil
    var newName: String? = nil
    var cropID: String? = nil
}
