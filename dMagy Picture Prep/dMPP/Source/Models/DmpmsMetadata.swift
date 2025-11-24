//
//  DmpmsMetadata.swift
//  dMagy Picture Prep
//

import Foundation

// dMPMS-2025-11-20-M1 — Core metadata models (pre-I/O)

/* [DMPMS-META] Complete dMPMS metadata structure. */
struct DmpmsMetadata: Codable, Hashable {
    var dmpmsVersion: String = "1.0"
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
        case sourceFile
        case title
        case description
        case dateTaken
        case tags
        case people
        case virtualCrops
        case history
    }
}

/* [DMPMS-HISTORY] Simple history event. */
struct HistoryEvent: Codable, Hashable {
    var action: String
    var timestamp: String
    var oldName: String? = nil
    var newName: String? = nil
    var cropID: String? = nil
}
