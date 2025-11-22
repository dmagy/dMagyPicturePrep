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
        addCrop(
            aspectRatio: "16:9",
            rect: RectNormalized(x: 0.0, y: 0.1, width: 1.0, height: 0.8),
            label: "Landscape 16:9"
        )
    }

    /// Add a preset 8x10 portrait crop.
    func addPresetCropPortrait() {
        addCrop(
            aspectRatio: "8:10",
            rect: RectNormalized(x: 0.15, y: 0.0, width: 0.7, height: 1.0),
            label: "Portrait 8x10"
        )
    }

    /// Add a preset 1:1 square crop.
    func addPresetCropSquare() {
        addCrop(
            aspectRatio: "1:1",
            rect: RectNormalized(x: 0.15, y: 0.1, width: 0.7, height: 0.7),
            label: "Square 1:1"
        )
    }

    /// [DMPP-VM-NEW-CROP] Generic "New Crop" action used by the button.
    /// For now, this just creates another landscape 16:9 crop.
    func newCrop() {
        addPresetCropLandscape()
    }

    /// [DMPP-VM-DUP-CROP] Duplicate the currently selected crop (if any).
    func duplicateSelectedCrop() {
        guard let crop = selectedCrop else { return }

        var copy = crop
        copy.id = makeUniqueCropID(prefix: crop.id + "-copy")
        copy.label = crop.label.isEmpty ? "Copy" : "\(crop.label) Copy"

        metadata.virtualCrops.append(copy)
        selectedCropID = copy.id
    }

    /// [DMPP-VM-DEL-CROP] Delete the currently selected crop (if any).
    func deleteSelectedCrop() {
        guard let id = selectedCropID,
              let index = metadata.virtualCrops.firstIndex(where: { $0.id == id }) else {
            return
        }

        metadata.virtualCrops.remove(at: index)

        // Choose a new selection: next crop, or previous, or none.
        if metadata.virtualCrops.indices.contains(index) {
            selectedCropID = metadata.virtualCrops[index].id
        } else if metadata.virtualCrops.indices.contains(index - 1) {
            selectedCropID = metadata.virtualCrops[index - 1].id
        } else {
            selectedCropID = nil
        }
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
