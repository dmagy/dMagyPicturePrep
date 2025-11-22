import Foundation

// dMPMS-2025-11-20-M1 — Core metadata models (pre-I/O)

/* [DMPMS-RECT] Normalized rectangle for virtual crops. */
struct RectNormalized: Codable, Hashable {
    var x: Double   // 0.0–1.0
    var y: Double
    var width: Double
    var height: Double
}

/* [DMPMS-CROP] Virtual crop definition. */
struct VirtualCrop: Identifiable, Codable, Hashable {
    var id: String
    var label: String
    var aspectRatio: String   // e.g. "16:9", "8:10"
    var rect: RectNormalized
}

/* [DMPMS-HISTORY] Simple history event. */
struct HistoryEvent: Codable, Hashable {
    var action: String
    var timestamp: String
    var oldName: String? = nil
    var newName: String? = nil
    var cropID: String? = nil
}

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
}
