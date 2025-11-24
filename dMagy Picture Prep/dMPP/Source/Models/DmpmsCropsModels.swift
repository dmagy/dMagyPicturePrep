//
//  DmpmsCropsModels.swift
//  dMagy Picture Prep
//
//  dMPMS-2025-11-20-M1 — Core crop models
//

import Foundation

// MARK: - [DMPMS-RECT] Normalized rectangle for virtual crops.
struct RectNormalized: Codable, Hashable {
    var x: Double   // 0.0–1.0
    var y: Double
    var width: Double
    var height: Double
}

// MARK: - [DMPMS-CROP] Virtual crop definition.
// Matches DMPPImageEditorViewModel and DmpmsMetadata.
struct VirtualCrop: Identifiable, Codable, Hashable {
    var id: String              // dMPMS uses String IDs
    var label: String
    var aspectRatio: String     // e.g. "16:9", "8:10"
    var rect: RectNormalized
}
