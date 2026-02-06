//
//  DmpmsCropsModels.swift
//  dMagy Picture Prep
//
//  cp-2025-11-24-CROP-MODELS1 — RectNormalized + VirtualCrop (aspectWidth/height)
//

import Foundation
import CoreGraphics

// MARK: - [VC-MODEL-RECT] RectNormalized
/// Normalized crop rectangle in image space.
/// All coordinates are 0.0–1.0 relative to the full image.
struct RectNormalized: Codable, Equatable, Hashable {
    /// Left/top origin (0.0 = left/top, 1.0 = right/bottom)
    var x: Double
    var y: Double

    /// Width/height relative to full image
    var width: Double
    var height: Double
}

// MARK: - [VC-MODEL-CROP] VirtualCrop
/// A reusable "virtual crop" definition that dMPP writes
/// and dMPS reads from .dmpms.json sidecars.
struct VirtualCrop: Identifiable, Codable, Equatable, Hashable {

    // MARK: - [VC-MODEL-CROP] Headshot semantics (Phase 1)

    enum CropKind: String, Codable, Hashable {
        case standard
        case headshot
    }

    enum HeadshotVariant: String, Codable, Hashable {
        case tight
        case full
    }

    /// Stable identifier so we can edit/delete specific crops.
    /// Example: "crop-16x9-1"
    var id: String

    /// Human-friendly label shown in the UI (e.g., “Landscape 16:9”)
    var label: String

    /// Target aspect ratio as a string, e.g. "16:9", "4:5", "3:2", or "custom".
    var aspectRatio: String

    /// Normalized rectangle in source image space.
    var rect: RectNormalized

    /// If this crop was created from a custom preset, store that preset’s stable UUID string.
    /// This makes UI labels permanent even if preset names change later.
    var sourceCustomPresetID: String? = nil

    /// Crop "kind" — standard crop vs headshot crop.
    /// Default is standard so older sidecars decode safely.
    var kind: CropKind = .standard

    /// Only used when kind == .headshot
    var headshotVariant: HeadshotVariant? = nil

    /// Only used when kind == .headshot
    /// Links to the People registry personID (exact ID type depends on your People model).
    var headshotPersonID: String? = nil
}
