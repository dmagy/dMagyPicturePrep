import Foundation
import SwiftUI
import AppKit
import Observation

// dMPP-2025-11-20-VM1 — ViewModel for Single Image Editor

/// [DMPP-VM] Manages one image + its dMPMS metadata.
@Observable
class DMPPImageEditorViewModel {

    // [DMPP-VM-IMAGE-URL] Where the actual image lives on disk.
    let imageURL: URL

    // The metadata we are editing
    var metadata: DmpmsMetadata

    // Selected crop ID for tabs
    var selectedCropID: String? = nil

    // [DMPP-VM-ASPECT-LABEL] Human-readable aspect description for the selected crop.
    var selectedCropAspectDescription: String {
        guard let crop = selectedCrop else {
            return "No crop selected"
        }

        let declared = crop.aspectRatio

        let w = crop.rect.width
        let h = crop.rect.height

        guard h > 0 else {
            return declared
        }

        // Normalized rect already encodes the ratio; we just display it.
        let actual = w / h
        let rounded = (actual * 100).rounded() / 100  // 2 decimal places

        return "\(declared) (\(rounded):1)"
    }

    
    init(imageURL: URL, metadata: DmpmsMetadata) {
        self.imageURL = imageURL
        self.metadata = metadata

        // Auto-select first crop if available
        if let first = metadata.virtualCrops.first?.id {
            self.selectedCropID = first
        }
    }

    // [DMPP-VM-NSIMAGE] Convenience for SwiftUI Image(nsImage:)
    var nsImage: NSImage? {
        NSImage(contentsOf: imageURL)
    }

    // [DMPP-VM-CROP-LOOKUP] Return the selected crop (mutable).
    var selectedCrop: VirtualCrop? {
        get {
            guard let id = selectedCropID else { return nil }
            return metadata.virtualCrops.first { $0.id == id }
        }
        set {
            guard let id = selectedCropID,
                  let index = metadata.virtualCrops.firstIndex(where: { $0.id == id }),
                  let new = newValue else { return }
            metadata.virtualCrops[index] = new
        }
    }

    // [DMPP-VM-UPDATE-FIELDS] Helpers for editing metadata arrays.
    func updateTags(_ raw: String) {
        metadata.tags = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    func updatePeople(_ raw: String) {
        metadata.people = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // [DMPP-VM-SAVE] Local stub so crop helpers compile.
    // The actual sidecar writing is handled by the higher-level owner.
    func saveCurrentMetadata() {
        // For now this is a no-op. The owner view/controller
        // already reads vm.metadata and writes the sidecar.
    }

    
    // [DMPP-VM-TAG-FIELDS] Helpers for converting back to display.
    var tagsText: String {
        metadata.tags.joined(separator: ", ")
    }

    var peopleText: String {
        metadata.people.joined(separator: ", ")
    }

    // ============================================================
    // [DMPP-VM-CROPS] Crop management: add / duplicate / delete
    // ============================================================

    /// Add a preset 16:9 landscape crop.
    func addPresetCropLandscape() {
        let aspect = "16:9"

        let rect: RectNormalized
        if let size = nsImage?.size {
            rect = centeredRect(forAspectRatio: aspect, imageSize: size)
        } else {
            // Fallback if we somehow don't have an image yet.
            rect = RectNormalized(x: 0.0, y: 0.1, width: 1.0, height: 0.8)
        }

        createVirtualCrop(
            label: "Landscape 16:9",
            aspectRatio: aspect,
            rect: rect
        )
    }

    /// Add a preset 8x10 portrait crop.
    func addPresetCropPortrait() {
        let aspect = "8:10"

        let rect: RectNormalized
        if let size = nsImage?.size {
            rect = centeredRect(forAspectRatio: aspect, imageSize: size)
        } else {
            rect = RectNormalized(x: 0.15, y: 0.0, width: 0.70, height: 1.0)
        }

        createVirtualCrop(
            label: "Portrait 8x10",
            aspectRatio: aspect,
            rect: rect
        )
    }

    /// Add a preset 1:1 square crop.
    func addPresetCropSquare() {
        let aspect = "1:1"

        let rect: RectNormalized
        if let size = nsImage?.size {
            rect = centeredRect(forAspectRatio: aspect, imageSize: size)
        } else {
            rect = RectNormalized(x: 0.15, y: 0.1, width: 0.7, height: 0.7)
        }

        createVirtualCrop(
            label: "Square 1:1",
            aspectRatio: aspect,
            rect: rect
        )
    }

    /// [DMPP-VM-NEW-CROP] Generic "New Crop" action used by the button.
    /// Currently defaults to a new landscape crop.
    func newCrop() {
        addPresetCropLandscape()
    }



    /// [DMPP-VM-DUP-CROP] Duplicate the currently selected crop (if any).
    func duplicateSelectedCrop() {
        guard let crop = selectedCrop else { return }

        // Remember how many crops we had before.
        let beforeCount = metadata.virtualCrops.count

        // Use the history-aware helper.
        duplicateVirtualCrop(cropID: crop.id)

        // After duplication, the new crop should be the last one appended.
        if metadata.virtualCrops.count == beforeCount + 1,
           let newCrop = metadata.virtualCrops.last {
            selectedCropID = newCrop.id
        }
    }

    /// [DMPP-VM-DEL-CROP] Delete the currently selected crop (if any).
    func deleteSelectedCrop() {
        guard let id = selectedCropID,
              let index = metadata.virtualCrops.firstIndex(where: { $0.id == id }) else {
            return
        }

        // Use the history-aware helper to actually remove + log the event.
        deleteVirtualCrop(cropID: id)

        // Choose a new selection: next crop, or previous, or none.
        if metadata.virtualCrops.indices.contains(index) {
            selectedCropID = metadata.virtualCrops[index].id
        } else if metadata.virtualCrops.indices.contains(index - 1) {
            selectedCropID = metadata.virtualCrops[index - 1].id
        } else {
            selectedCropID = nil
        }
    }
    // ============================================================
    // [DMPP-VM-CROP-SCALE] Scale selected crop around its center
    // ============================================================

    /// Uniformly scale the currently selected crop around its center.
    /// `factor` > 1.0 makes the crop larger (shows more image).
    /// `factor` < 1.0 makes the crop smaller (zooms in).
    func scaleSelectedCrop(by factor: Double) {
        guard let id = selectedCropID,
              let index = metadata.virtualCrops.firstIndex(where: { $0.id == id }),
              factor > 0
        else { return }

        var crop = metadata.virtualCrops[index]
        var rect = crop.rect

        // Minimum and maximum size as a fraction of the image.
        let minSize: Double = 0.05   // don't let the crop get smaller than 5%
        let maxSize: Double = 1.0    // never larger than the full image

        // Clamp factor so we don't exceed bounds or go below min size.
        let maxFactorWidth = maxSize / rect.width
        let maxFactorHeight = maxSize / rect.height

        let minFactorWidth = minSize / rect.width
        let minFactorHeight = minSize / rect.height

        var clampedFactor = factor
        clampedFactor = min(clampedFactor, maxFactorWidth, maxFactorHeight)
        clampedFactor = max(clampedFactor, max(minFactorWidth, minFactorHeight))

        // Preserve the crop's center point.
        let centerX = rect.x + rect.width / 2.0
        let centerY = rect.y + rect.height / 2.0

        var newWidth = rect.width * clampedFactor
        var newHeight = rect.height * clampedFactor

        // Recompute origin so the center stays the same.
        var newX = centerX - newWidth / 2.0
        var newY = centerY - newHeight / 2.0

        // Clamp so the crop stays entirely within [0, 1].
        newX = min(max(newX, 0.0), 1.0 - newWidth)
        newY = min(max(newY, 0.0), 1.0 - newHeight)

        rect = RectNormalized(x: newX, y: newY, width: newWidth, height: newHeight)
        crop.rect = rect
        metadata.virtualCrops[index] = crop

        // Record a simple history event.
        let event = HistoryEvent(
            action: "scaleCrop",
            timestamp: currentTimestampString(),
            oldName: nil,
            newName: crop.label,
            cropID: crop.id
        )
        metadata.history.append(event)

        saveCurrentMetadata()
    }


    // MARK: - Private crop helpers

    /// Core helper to append a crop and select it.
    private func addCrop(aspectRatio: String, rect: RectNormalized, label: String) {
        let idPrefix = "crop-\(aspectRatio.replacingOccurrences(of: ":", with: "x"))"
        let id = makeUniqueCropID(prefix: idPrefix)

        let crop = VirtualCrop(
            id: id,
            label: label,
            aspectRatio: aspectRatio,
            rect: rect
        )

        metadata.virtualCrops.append(crop)
        selectedCropID = crop.id
    }

    // MARK: - [DMPP-VM-ASPECT] Build a centered rect for a given aspect ratio

    /// Creates a centered RectNormalized that fits entirely within the image
    /// while preserving the target aspect ratio (e.g. "16:9", "8:10", "1:1").
    private func centeredRect(
        forAspectRatio aspectString: String,
        imageSize: CGSize
    ) -> RectNormalized {
        // Parse "W:H" into numbers.
        let parts = aspectString.split(separator: ":")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w > 0, h > 0
        else {
            // Fallback: full image if parsing fails
            return RectNormalized(x: 0, y: 0, width: 1, height: 1)
        }

        let targetAR = w / h
        let imageAR = Double(imageSize.width / max(imageSize.height, 1))

        // ratio of target AR to image AR
        let k = targetAR / imageAR

        let widthNorm: Double
        let heightNorm: Double

        if k >= 1 {
            // Target is "wider" than image: full width, reduce height.
            widthNorm = 1.0
            heightNorm = 1.0 / k
        } else {
            // Target is "taller" than image: full height, reduce width.
            widthNorm = k
            heightNorm = 1.0
        }

        let x = (1.0 - widthNorm) / 2.0
        let y = (1.0 - heightNorm) / 2.0

        return RectNormalized(x: x, y: y, width: widthNorm, height: heightNorm)
    }

    
    /// Ensure crop IDs are unique within this image.
    private func makeUniqueCropID(prefix: String) -> String {
        let existing = Set(metadata.virtualCrops.map { $0.id })
        if !existing.contains(prefix) {
            return prefix
        }

        var counter = 2
        var candidate = "\(prefix)-\(counter)"
        while existing.contains(candidate) {
            counter += 1
            candidate = "\(prefix)-\(counter)"
        }
        return candidate
    }
}
//
//  cp-2025-11-22-VC5 — Core virtual crop helpers using dMPMS models
//

import Foundation
import CoreGraphics

extension DMPPImageEditorViewModel {

    // MARK: - [VC-TS] Timestamp helper

    /// [VC-TS] Return an ISO8601 timestamp string for HistoryEvent.
    private func currentTimestampString() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Date())
    }

    // MARK: - [VC-CREATE] Create a new virtual crop

    /// [VC-CREATE] Create a brand-new virtual crop and save metadata.
    ///
    /// - Parameters:
    ///   - label: Human-readable name, e.g. "16:9 Landscape" or "Living Room TV"
    ///   - aspectRatio: Stored as a string like "16:9" or "8:10"
    ///   - rect: Normalized rectangle (0–1) in image space
    func createVirtualCrop(
        label: String,
        aspectRatio: String,
        rect: RectNormalized
    ) {
        // Basic validation so we don't write nonsense.
        guard rect.width > 0,
              rect.height > 0,
              rect.x >= 0,
              rect.y >= 0,
              rect.x + rect.width <= 1.0001,
              rect.y + rect.height <= 1.0001 else {
            print("[VC-CREATE] Invalid RectNormalized: \(rect)")
            return
        }

        let cropID = UUID().uuidString

        // Build the new crop.
        let crop = VirtualCrop(
            id: cropID,
            label: label,
            aspectRatio: aspectRatio,
            rect: rect
        )

        // Append to metadata.
        metadata.virtualCrops.append(crop)

        // Record history.
        let event = HistoryEvent(
            action: "createCrop",
            timestamp: currentTimestampString(),
            oldName: nil,
            newName: label,
            cropID: cropID
        )
        metadata.history.append(event)

        // Persist to sidecar.
        saveCurrentMetadata()
    }

    // MARK: - [VC-DUP] Duplicate an existing crop

    /// [VC-DUP] Duplicate an existing crop by id (e.g., for "Duplicate" button).
    func duplicateVirtualCrop(cropID: String) {
        guard let index = metadata.virtualCrops.firstIndex(where: { $0.id == cropID }) else {
            print("[VC-DUP] No crop found with id \(cropID)")
            return
        }

        let existing = metadata.virtualCrops[index]

        let newID = UUID().uuidString
        let newLabel = existing.label + " Copy"

        let duplicate = VirtualCrop(
            id: newID,
            label: newLabel,
            aspectRatio: existing.aspectRatio,
            rect: existing.rect
        )

        metadata.virtualCrops.append(duplicate)

        let event = HistoryEvent(
            action: "duplicateCrop",
            timestamp: currentTimestampString(),
            oldName: existing.label,
            newName: newLabel,
            cropID: newID
        )
        metadata.history.append(event)

        saveCurrentMetadata()
    }

    // MARK: - [VC-DELETE] Delete a crop

    /// [VC-DELETE] Remove a crop by id.
    func deleteVirtualCrop(cropID: String) {
        guard let index = metadata.virtualCrops.firstIndex(where: { $0.id == cropID }) else {
            print("[VC-DELETE] No crop found with id \(cropID)")
            return
        }

        let removed = metadata.virtualCrops.remove(at: index)

        let event = HistoryEvent(
            action: "deleteCrop",
            timestamp: currentTimestampString(),
            oldName: removed.label,
            newName: nil,
            cropID: removed.id
        )
        metadata.history.append(event)

        saveCurrentMetadata()
    }

    // MARK: - [VC-UPDATE-RECT] Update the rectangle of a crop

    /// [VC-UPDATE-RECT] Update the crop's normalized rectangle
    /// when the user drags/resizes in the UI.
    func updateVirtualCropRect(
        cropID: String,
        newRect: RectNormalized
    ) {
        guard let index = metadata.virtualCrops.firstIndex(where: { $0.id == cropID }) else {
            print("[VC-UPDATE-RECT] No crop found with id \(cropID)")
            return
        }

        guard newRect.width > 0,
              newRect.height > 0,
              newRect.x >= 0,
              newRect.y >= 0,
              newRect.x + newRect.width <= 1.0001,
              newRect.y + newRect.height <= 1.0001 else {
            print("[VC-UPDATE-RECT] Invalid RectNormalized: \(newRect)")
            return
        }

        metadata.virtualCrops[index].rect = newRect

        let event = HistoryEvent(
            action: "updateCropRect",
            timestamp: currentTimestampString(),
            oldName: nil,
            newName: metadata.virtualCrops[index].label,
            cropID: cropID
        )
        metadata.history.append(event)

        saveCurrentMetadata()
    }
}
