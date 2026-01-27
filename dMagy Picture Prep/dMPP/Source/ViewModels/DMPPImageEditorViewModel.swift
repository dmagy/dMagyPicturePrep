import Foundation
import SwiftUI
import AppKit
import Observation
import ImageIO
import Combine




// dMPP-2025-11-20-VM1 — ViewModel for Single Image Editor

/// [DMPP-VM] Manages one image + its dMPMS metadata.
@Observable
class DMPPImageEditorViewModel {

    // [IDS] Injected store (no singleton)
    let identityStore: DMPPIdentityStore
    
    // [DMPP-VM-IMAGE-URL] Where the actual image lives on disk.
    let imageURL: URL

    // The metadata we are editing
    var metadata: DmpmsMetadata

    // Selected crop ID for tabs
    var selectedCropID: String? = nil
    
    // cp-2025-12-18-07(AGE-STATE)



    /// [AGE-MAP] identityID -> age (years) or nil
    var agesByIdentityID: [String: Int?] = [:]
    
    // cp-2025-12-18-16(AGE-RANGE)
    var ageTextByIdentityID: [String: String] = [:]


    /// [AGE-C] Combine cancellables for live refresh subscriptions
    private var cancellables = Set<AnyCancellable>()


    // ============================================================
    // [DMPP-VM-CROP-SLIDER-CONFIG] Bounds for crop size slider
    // ============================================================

    /// Smallest and largest crop size as a fraction of the max rect.
    /// 0.1 = 10% of the image, 1.0 = full max crop for this aspect.
    private let minCropScale: Double = 0.1
    private let maxCropScale: Double = 1.0

    
    
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

    
    init(imageURL: URL, metadata: DmpmsMetadata, identityStore: DMPPIdentityStore) {
        self.imageURL = imageURL
        self.metadata = metadata
        self.identityStore = identityStore

        // ---------------------------------------------------------
        // [DMPP-META-AUTODATE] Auto-fill Date/Era for camera images
        // ---------------------------------------------------------
        // If the sidecar didn't specify a dateTaken, try to infer one
        // from EXIF (camera) metadata. This fills YYYY-MM-DD for
        // real camera photos but leaves true unknowns/scans blank.
        if self.metadata.dateTaken
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty,
           let inferred = Self.inferCaptureDateString(from: imageURL)
        {
            self.metadata.dateTaken = inferred
        }

        // ---------------------------------------------------------
        // [DMPP-CROPS-DEFAULTS] Create default crops if needed
        // ---------------------------------------------------------
        // If no crops exist (i.e., no sidecar or empty virtualCrops),
        // create defaults based on user preferences.
        if self.metadata.virtualCrops.isEmpty {

            // Load user preferences (or defaults).
            let prefs = DMPPUserPreferences.load()
            let presets = prefs.effectiveDefaultCropPresets

            // For each preset the user has chosen, create the matching crop.
            for preset in presets {
                switch preset {
                case .original:
                    addPresetOriginalCrop()

                case .landscape16x9:
                    addPresetLandscape16x9()

                case .portrait8x10:
                    addPresetPortrait8x10()

                case .headshot8x10:
                    addPresetHeadshot8x10()

                case .landscape4x6:
                    addPresetLandscape4x6()

                case .square1x1:
                    addPresetSquare1x1()
                }
            }
        }

        // Auto-select first crop if available
        if let first = self.metadata.virtualCrops.first?.id {
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
    // cp-2025-12-19-PS4(SNAPSHOT-ON-SAVE-IMPL)

    // cp-2025-12-19-PS4(SNAPSHOT-ON-SAVE-IMPL)

    private static func _isoNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }

    /// Captures the current People list (including unknown rows) into metadata.peopleV2Snapshots.
    /// Call this before destructive actions (Reset) and also on Save.
    func capturePeopleSnapshot(note: String = "Snapshot") {
        let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote = clean.isEmpty ? "Snapshot" : clean

        let snap = DmpmsPeopleSnapshot(
            id: UUID().uuidString,
            createdAtISO8601: Self._isoNow(),
            note: finalNote,
            peopleV2: metadata.peopleV2
        )

        metadata.peopleV2Snapshots.append(snap)

        // Optional guardrail: keep last 50 snapshots
        if metadata.peopleV2Snapshots.count > 50 {
            metadata.peopleV2Snapshots.removeFirst(metadata.peopleV2Snapshots.count - 50)
        }
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

    /// [DMPP-VM-GCD] Helper to compute integer aspect ratio from image size.
    private func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        if x == 0 { return max(y, 1) }
        if y == 0 { return max(x, 1) }
        while y != 0 {
            let r = x % y
            x = y
            y = r
        }
        return max(x, 1)
    }

    /// [DMPP-VM-CENTERED-RECT] Compute a centered RectNormalized for a desired aspect.
    private func defaultRect(forAspectWidth aw: Int, aspectHeight ah: Int) -> RectNormalized {
        // If we have a real image size, use the centeredRect helper.
        if let nsImage, nsImage.size.width > 0, nsImage.size.height > 0 {
            let aspectString = "\(aw):\(ah)"
            return centeredRect(forAspectRatio: aspectString, imageSize: nsImage.size)
        } else {
            // Fallback: full frame.
            return RectNormalized(x: 0, y: 0, width: 1, height: 1)
        }
    }

    /// Core helper to append a crop and select it.
    private func addCrop(
        label: String,
        aspectWidth: Int,
        aspectHeight: Int,
        rect: RectNormalized
    ) {
        // Build an id prefix from the numeric aspect when available.
        let idPrefix: String
        if aspectWidth > 0 && aspectHeight > 0 {
            idPrefix = "crop-\(aspectWidth)x\(aspectHeight)"
        } else {
            idPrefix = "crop-custom"
        }

        let id = makeUniqueCropID(prefix: idPrefix)

        // Turn numeric aspect into a string like "16:9" or mark it as "custom".
        let aspectString: String
        if aspectWidth > 0 && aspectHeight > 0 {
            aspectString = "\(aspectWidth):\(aspectHeight)"
        } else {
            aspectString = "custom"
        }

        let crop = VirtualCrop(
            id: id,
            label: label,
            aspectRatio: aspectString,
            rect: rect
        )

        metadata.virtualCrops.append(crop)
        selectedCropID = crop.id
    }

    /// Create a crop from a user-defined preset definition.
    /// This uses the same aspect/centering logic as the built-in presets.
    // MARK: - Custom preset → crop

    /// Create a crop from a user-defined custom preset, unless this image
    /// already has an identical preset (same label + aspect ratio).
    func addCrop(fromUserPreset preset: DMPPUserPreferences.CustomCropPreset) {
        let aspectString = "\(preset.aspectWidth):\(preset.aspectHeight)"

        // Don’t create duplicate custom crops for a single image.
        if hasCrop(label: preset.label, aspectRatio: aspectString) {
            return
        }

        let rect = defaultRect(
            forAspectWidth: preset.aspectWidth,
            aspectHeight: preset.aspectHeight
        )

        addCrop(
            label: preset.label,
            aspectWidth: preset.aspectWidth,
            aspectHeight: preset.aspectHeight,
            rect: rect
        )
    }




    /// [CR-PRESET-CUSTOM-NAMED] Custom preset crop (from user preferences)
    private func addPresetCustomCrop(
        label: String,
        aspectWidth: Int,
        aspectHeight: Int
    ) {
        let rect = defaultRect(forAspectWidth: aspectWidth, aspectHeight: aspectHeight)
        addCrop(
            label: label,
            aspectWidth: aspectWidth,
            aspectHeight: aspectHeight,
            rect: rect
        )
    }



    // MARK: - Screen presets

    /// [CR-PRESET-ORIGINAL] Original (full image) — aspect from actual pixels.
    func addPresetOriginalCrop() {
        // Full-frame rect
        let rect = RectNormalized(x: 0, y: 0, width: 1, height: 1)

        // Derive integer aspect ratio from the image size if possible.
        let aw: Int
        let ah: Int
        if let nsImage, nsImage.size.width > 0, nsImage.size.height > 0 {
            let w = Int(nsImage.size.width.rounded())
            let h = Int(nsImage.size.height.rounded())
            let g = gcd(w, h)
            aw = max(w / g, 1)
            ah = max(h / g, 1)
        } else {
            // Fallback: unknown aspect, treat as "freeform"
            aw = 0
            ah = 0
        }

        addCrop(
            label: "Original (full image)",
            aspectWidth: aw,
            aspectHeight: ah,
            rect: rect
        )
    }

    /// [CR-PRESET-16x9] Landscape 16:9 (screen)
    func addPresetLandscape16x9() {
        let rect = defaultRect(forAspectWidth: 16, aspectHeight: 9)
        addCrop(
            label: "Landscape 16:9",
            aspectWidth: 16,
            aspectHeight: 9,
            rect: rect
        )
    }

    /// [CR-PRESET-9x16] Portrait 9:16 (vertical screen)
    func addPresetPortrait9x16() {
        let rect = defaultRect(forAspectWidth: 9, aspectHeight: 16)
        addCrop(
            label: "Portrait 9:16",
            aspectWidth: 9,
            aspectHeight: 16,
            rect: rect
        )
    }

    /// [CR-PRESET-4x3] Landscape 4:3 (classic screen/tablet)
    func addPresetLandscape4x3() {
        let rect = defaultRect(forAspectWidth: 4, aspectHeight: 3)
        addCrop(
            label: "Landscape 4:3",
            aspectWidth: 4,
            aspectHeight: 3,
            rect: rect
        )
    }

    // MARK: - Print & frames

    /// [CR-PRESET-8×10] Portrait 8×10 (4:5)
    func addPresetPortrait8x10() {
        let rect = defaultRect(forAspectWidth: 4, aspectHeight: 5)
        addCrop(
            label: "Portrait 8×10",
            aspectWidth: 4,
            aspectHeight: 5,
            rect: rect
        )
    }

    /// [CR-PRESET-4x6] Landscape 4×6 (3:2)
    func addPresetLandscape4x6() {
        let rect = defaultRect(forAspectWidth: 3, aspectHeight: 2)
        addCrop(
            label: "Landscape 4×6",
            aspectWidth: 3,
            aspectHeight: 2,
            rect: rect
        )
    }

    // MARK: - Other

    /// [CR-PRESET-1x1] Square 1:1
    func addPresetSquare1x1() {
        let rect = defaultRect(forAspectWidth: 1, aspectHeight: 1)
        addCrop(
            label: "Square 1:1",
            aspectWidth: 1,
            aspectHeight: 1,
            rect: rect
        )
    }
    
    /// [CR-PRESET-HEADSHOT-8×10] Headshot 8×10 (4:5) – same aspect as Portrait 8×10,
    /// but labeled separately so we can show special headshot guides in the UI.
    func addPresetHeadshot8x10() {
        let rect = defaultRect(forAspectWidth: 4, aspectHeight: 5)
        addCrop(
            label: "Headshot 8×10",
            aspectWidth: 4,
            aspectHeight: 5,
            rect: rect
        )
    }
    /// [CR-PRESET-FREEFORM] Freeform crop (per-image, no fixed aspect).
     ///
     /// Uses aspectWidth = 0, aspectHeight = 0 in dMPMS to indicate a freeform crop.
     /// Starts as a centered 1:1 rect; users can then reshape it with the freeform tools.
     func addFreeformCrop() {
         // Start from a centered square-ish rect based on the actual image size.
         let rect = defaultRect(forAspectWidth: 1, aspectHeight: 1)

         addCrop(
             label: "Freeform",
             aspectWidth: 0,
             aspectHeight: 0,
             rect: rect
         )
     }

  

    /// [DMPP-VM-NEW-CROP] Generic "New Crop" action used by the button.
    /// For now, this creates another Landscape 16:9 crop.
    func newCrop() {
        addPresetLandscape16x9()
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

    // ============================================================
    // [DMPP-VM-CROP-NAV] Previous / Next crop selection helpers
    // ============================================================

    /// Select the previous crop in metadata.virtualCrops (wraps around).
    func selectPreviousCrop() {
        guard !metadata.virtualCrops.isEmpty else { return }

        let crops = metadata.virtualCrops

        // If nothing is selected yet, pick the last one.
        guard let currentID = selectedCropID,
              let currentIndex = crops.firstIndex(where: { $0.id == currentID }) else {
            selectedCropID = crops.last?.id
            return
        }

        let prevIndex = (currentIndex - 1 + crops.count) % crops.count
        selectedCropID = crops[prevIndex].id
    }

    /// Select the next crop in metadata.virtualCrops (wraps around).
    func selectNextCrop() {
        guard !metadata.virtualCrops.isEmpty else { return }

        let crops = metadata.virtualCrops

        // If nothing is selected yet, pick the first one.
        guard let currentID = selectedCropID,
              let currentIndex = crops.firstIndex(where: { $0.id == currentID }) else {
            selectedCropID = crops.first?.id
            return
        }

        let nextIndex = (currentIndex + 1) % crops.count
        selectedCropID = crops[nextIndex].id
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

        let newWidth = rect.width * clampedFactor
        let newHeight = rect.height * clampedFactor

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
    // MARK: - Helpers: detect existing crops for disabling presets

    /// Returns true if this image already has a crop with the same
    /// user-facing label *and* aspect ratio string (e.g. "21:9").
    func hasCrop(label: String, aspectRatio: String) -> Bool {
        metadata.virtualCrops.contains { crop in
            crop.label == label && crop.aspectRatio == aspectRatio
        }
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


// cp-2025-12-18-08(AGE-EXT)

import Combine

extension DMPPImageEditorViewModel {

    // [AGE-WIRE] Subscribe to identityStore changes so People Manager edits refresh ages in the editor.
    func wireAgeRefresh() {

        // Avoid double-wiring if init runs more than once in previews/tests.
        cancellables.removeAll()

        identityStore.$revision
            .sink { [weak self] _ in
                self?.recomputeAgesForCurrentImage()
            }
            .store(in: &cancellables)
    }

    // cp-2025-12-18-17(AGE-RECOMP)

    // cp-2025-12-31(AGE-RECOMP-RANGE-FIX)
    func recomputeAgesForCurrentImage() {

        let dt = metadata.dateTaken.trimmingCharacters(in: .whitespacesAndNewlines)

        let (photoStart, photoEnd): (Date?, Date?) = {
            // 1) Prefer the user-entered dateTaken string
            if !dt.isEmpty {

                // Exact day (YYYY-MM-DD) => single point
                if dt.count == 10, let d = LooseYMD.parse(dt) {
                    return (d, d)
                }

                // Otherwise interpret as a range (YYYY, YYYY-MM, decade, "A to B", etc.)
                return LooseYMD.parseRange(dt)
            }

            // 2) Fall back to metadata.dateRange if dateTaken is blank
            if let r = metadata.dateRange {
                let s = LooseYMD.parseRange(r.earliest).start
                let e = LooseYMD.parseRange(r.latest).end
                return (s, e)
            }

            return (nil, nil)
        }()

        let startForAge = photoStart
        let endForAge   = photoEnd ?? photoStart

        var nextYears: [String: Int?] = [:]
        var nextText:  [String: String] = [:]

        for row in metadata.peopleV2 {
            guard let identityID = row.identityID else { continue }

            guard let identity = identityStore.identity(forIdentityID: identityID) else {
                nextYears[identityID] = nil
                nextText[identityID] = ""
                continue
            }

            let (b0, b1) = LooseYMD.birthRange(identity.birthDate)

            // youngest age = earliest photo - latest birth
            // oldest age   = latest photo   - earliest birth
            let youngest = AgeAtPhoto.yearsOld(on: startForAge, birthDate: b1)
            let oldest   = AgeAtPhoto.yearsOld(on: endForAge,   birthDate: b0)

            nextYears[identityID] = youngest

            if let a0 = youngest, let a1 = oldest {
                if a0 == a1 {
                    nextText[identityID] = "\(a0)"
                } else {
                    nextText[identityID] = "\(min(a0, a1))–\(max(a0, a1))"
                }
            } else {
                nextText[identityID] = ""
            }
        }

        agesByIdentityID = nextYears
        ageTextByIdentityID = nextText
    }


    // cp-2025-12-19-PS5(RESET-AND-RESTORE)

    /// Snapshots the current people list, then clears it.
    /// Use this for the "Reset people" button.
    func resetPeopleList(snapshotNote: String = "Before reset") {
        capturePeopleSnapshot(note: snapshotNote)
        metadata.peopleV2.removeAll()
        recomputeAgesForCurrentImage()
    }

    /// Restores the most recent snapshot (if any) into peopleV2.
    func restoreLastPeopleSnapshot() {
        guard let last = metadata.peopleV2Snapshots.last else { return }
        metadata.peopleV2 = last.peopleV2
        recomputeAgesForCurrentImage()
    }


}


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
    // ============================================================
    // [DMPP-VM-CROP-SLIDER] UI binding for crop size slider
    // ============================================================
    
    /// Smallest and largest crop size as a fraction of the image.
    /// 0.1 = 10% of the max possible crop, 1.0 = full max crop.
    
    
    // ============================================================
    // [DMPP-VM-CROP-SLIDER] UI binding for crop size slider
    //  - Fixed-aspect crops: behave as before (scale against maxRect)
    //  - Freeform ("custom") crops: keep current aspect ratio
    // ============================================================
    var selectedCropSizeSliderValue: Double {
        get {
            guard let crop = selectedCrop,
                  let size = nsImage?.size else {
                return 1.0
            }
            
            let isFreeform = (crop.aspectRatio == "custom")
            
            if isFreeform {
                // For freeform, use the larger dimension as our "scale"
                let w = crop.rect.width
                let h = crop.rect.height
                guard w > 0, h > 0 else { return 1.0 }
                
                let rawScale = max(w, h)
                let clampedScale = min(max(rawScale, minCropScale), maxCropScale)
                
                // Map [minCropScale, maxCropScale] → [0, 1]
                return (clampedScale - minCropScale) / (maxCropScale - minCropScale)
            } else {
                // Existing behavior for fixed-aspect crops
                let maxRect = centeredRect(
                    forAspectRatio: crop.aspectRatio,
                    imageSize: size
                )
                
                guard maxRect.width > 0, maxRect.height > 0 else {
                    return 1.0
                }
                
                let scale = crop.rect.width / maxRect.width
                let clampedScale = min(max(scale, minCropScale), maxCropScale)
                
                return (clampedScale - minCropScale) / (maxCropScale - minCropScale)
            }
        }
        set {
            guard let id = selectedCropID,
                  let index = metadata.virtualCrops.firstIndex(where: { $0.id == id }),
                  let size = nsImage?.size else { return }
            
            var crop = metadata.virtualCrops[index]
            let isFreeform = (crop.aspectRatio == "custom")
            
            // Clamp slider to [0, 1], then map → [minCropScale, maxCropScale]
            let slider = min(max(newValue, 0.0), 1.0)
            let targetScale = minCropScale + (maxCropScale - minCropScale) * slider
            
            if isFreeform {
                // Freeform: preserve current aspect ratio, scale uniformly
                let aspect = crop.rect.height > 0
                ? crop.rect.width / crop.rect.height
                : 1.0
                
                var newWidth: Double
                var newHeight: Double
                
                if aspect >= 1.0 {
                    // Wider than tall; width drives scale (up to full width = 1.0)
                    newWidth = targetScale
                    newHeight = targetScale / max(aspect, 0.0001)
                } else {
                    // Taller than wide; height drives scale
                    newHeight = targetScale
                    newWidth = targetScale * aspect
                }
                
                // Keep the crop center fixed
                let centerX = crop.rect.x + crop.rect.width / 2.0
                let centerY = crop.rect.y + crop.rect.height / 2.0
                
                var newX = centerX - newWidth / 2.0
                var newY = centerY - newHeight / 2.0
                
                // Clamp inside [0, 1] × [0, 1]
                newX = min(max(newX, 0.0), 1.0 - newWidth)
                newY = min(max(newY, 0.0), 1.0 - newHeight)
                
                crop.rect = RectNormalized(
                    x: newX,
                    y: newY,
                    width: newWidth,
                    height: newHeight
                )
            } else {
                // Existing behavior for fixed-aspect crops
                let maxRect = centeredRect(
                    forAspectRatio: crop.aspectRatio,
                    imageSize: size
                )
                guard maxRect.width > 0, maxRect.height > 0 else { return }
                
                let centerX = crop.rect.x + crop.rect.width / 2.0
                let centerY = crop.rect.y + crop.rect.height / 2.0
                
                var newWidth = maxRect.width * targetScale
                var newHeight = maxRect.height * targetScale
                
                // Extra safety clamp
                newWidth = min(max(newWidth, minCropScale), maxCropScale)
                newHeight = min(max(newHeight, minCropScale), maxCropScale)
                
                var newX = centerX - newWidth / 2.0
                var newY = centerY - newHeight / 2.0
                
                // Clamp inside [0, 1] × [0, 1]
                newX = min(max(newX, 0.0), 1.0 - newWidth)
                newY = min(max(newY, 0.0), 1.0 - newHeight)
                
                crop.rect = RectNormalized(
                    x: newX,
                    y: newY,
                    width: newWidth,
                    height: newHeight
                )
            }
            
            metadata.virtualCrops[index] = crop
            
            let event = HistoryEvent(
                action: "sliderScaleCrop",
                timestamp: currentTimestampString(),
                oldName: nil,
                newName: crop.label,
                cropID: crop.id
            )
            
            if let lastIndex = metadata.history.indices.last {
                let last = metadata.history[lastIndex]
                if last.action == event.action,
                   last.cropID == event.cropID {
                    metadata.history[lastIndex] = event
                } else {
                    metadata.history.append(event)
                }
            } else {
                metadata.history.append(event)
            }
            
            saveCurrentMetadata()
            
        }
    }
    
    
    // MARK: - [VC-UPDATE-RECT] Update the rectangle of a crop
    
    /// [VC-UPDATE-RECT] Update the crop's normalized rectangle
    /// when the user drags/resizes in the UI.
    ///
    /// To avoid history spam, we *coalesce* consecutive `updateCropRect`
    /// events for the same crop into a single entry (we just overwrite
    /// the most recent one instead of appending a new row every time).
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
        
        // Coalesce with last event if it's also an updateCropRect
        if let lastIndex = metadata.history.indices.last {
            let last = metadata.history[lastIndex]
            if last.action == event.action,
               last.cropID == event.cropID {
                metadata.history[lastIndex] = event
            } else {
                metadata.history.append(event)
            }
        } else {
            metadata.history.append(event)
        }
        
        saveCurrentMetadata()
    }
    
    }

// MARK: - Built-in preset presence helpers

extension DMPPImageEditorViewModel {

    /// Original (full image) — keyed by label.
    var hasPresetOriginal: Bool {
        metadata.virtualCrops.contains { $0.label == "Original (full image)" }
    }

    /// Landscape 16:9
    var hasPresetLandscape16x9: Bool {
        metadata.virtualCrops.contains { $0.aspectRatio == "16:9" }
    }

    /// Portrait 9:16
    var hasPresetPortrait9x16: Bool {
        metadata.virtualCrops.contains { $0.aspectRatio == "9:16" }
    }

    /// Landscape 4:3
    var hasPresetLandscape4x3: Bool {
        metadata.virtualCrops.contains { $0.aspectRatio == "4:3" }
    }

    /// Portrait 8×10 (4:5)
    var hasPresetPortrait8x10: Bool {
        metadata.virtualCrops.contains {
            $0.aspectRatio == "4:5" && $0.label.contains("Portrait 8×10")
        }
    }

    /// Headshot 8×10 (4:5)
    var hasPresetHeadshot8x10: Bool {
        metadata.virtualCrops.contains {
            $0.aspectRatio == "4:5" && $0.label.contains("Headshot 8×10")
        }
    }

    /// Landscape 4×6 (3:2)
    var hasPresetLandscape4x6: Bool {
        metadata.virtualCrops.contains { $0.aspectRatio == "3:2" }
    }

    /// Square 1:1
    var hasPresetSquare1x1: Bool {
        metadata.virtualCrops.contains { $0.aspectRatio == "1:1" }
    }
}

extension DMPPImageEditorViewModel {

    /// True if a crop with the given label already exists.
    func hasCrop(withLabel label: String) -> Bool {
        metadata.virtualCrops.contains { $0.label == label }
    }

    /// Create a crop from a saved custom preset.
    func addCrop(fromCustomPreset preset: DMPPUserPreferences.CustomCropPreset) {
        let rect = defaultRect(
            forAspectWidth: preset.aspectWidth,
            aspectHeight: preset.aspectHeight
        )

        addCrop(
            label: preset.label,
            aspectWidth: preset.aspectWidth,
            aspectHeight: preset.aspectHeight,
            rect: rect
        )
    }
}
// MARK: - EXIF Date Inference

extension DMPPImageEditorViewModel {

    /// Try to infer a camera capture date from EXIF and return it as
    /// a dMPMS-style "YYYY-MM-DD" string. Returns nil if we can't.
    ///
    /// Design choice:
    /// - We only trust EXIF DateTimeOriginal.
    ///   This tends to be present for *camera* images but is often
    ///   missing or reused for scanned images, so scans stay blank.
    ///
    /// - If parsing fails, we simply return nil and leave dateTaken empty.
    static func inferCaptureDateString(from imageURL: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        else {
            return nil
        }

        // EXIF standard format: "yyyy:MM:dd HH:mm:ss"
        guard let rawDateTime = exif[kCGImagePropertyExifDateTimeOriginal]
                as? String
        else {
            // No trusted camera capture date → treat as "unknown"
            return nil
        }

        let exifFormatter = DateFormatter()
        exifFormatter.locale = Locale(identifier: "en_US_POSIX")
        exifFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        // Time zone is not critical since we only keep the date part.
        exifFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        guard let date = exifFormatter.date(from: rawDateTime) else {
            return nil
        }

        let outFormatter = DateFormatter()
        outFormatter.locale = Locale(identifier: "en_US_POSIX")
        outFormatter.dateFormat = "yyyy-MM-dd"

        return outFormatter.string(from: date)
    }
}
// MARK: - Date/Era helpers

extension DMPPImageEditorViewModel {

    /// Update the human-entered date string and keep `dateRange` in sync.
    func updateDateTaken(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        metadata.dateTaken = trimmed
        metadata.dateRange = DmpmsDateRange.from(dateTaken: trimmed)
    }
}

// MARK: - PeopleV2 reconciliation (ViewModel extension)

extension DMPPImageEditorViewModel {

    /// Keep selected people, but re-pick the best identity for the current photo date.
    /// Call this after dateTaken/dateRange changes OR before saving.
    func reconcilePeopleV2Identities(identityStore: DMPPIdentityStore)  {
        guard !metadata.peopleV2.isEmpty else { return }

        let photoEarliest = metadata.dateRange?.earliest

        for i in metadata.peopleV2.indices {
            guard let currentID = metadata.peopleV2[i].identityID,
                  let currentIdentity = identityStore.identity(withID: currentID)
            else { continue }

            // Resolve the personID for the currently stored identity
            let pidRaw = currentIdentity.personID?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            let personID = pidRaw.isEmpty ? currentIdentity.id : pidRaw

            let versions = identityStore.identityVersions(forPersonID: personID)
            guard !versions.isEmpty else { continue }

            let chosen = identityStore.bestIdentityForPhoto(
                versions: versions,
                photoEarliestYMD: photoEarliest
            )

            // Update identityID if it changed
            if metadata.peopleV2[i].identityID != chosen.id {
                metadata.peopleV2[i].identityID = chosen.id
            }

            // Refresh snapshots so the row reflects the identity-at-date
            metadata.peopleV2[i].isUnknown = false
            metadata.peopleV2[i].shortNameSnapshot = chosen.shortName
            metadata.peopleV2[i].displayNameSnapshot = chosen.fullName
            metadata.peopleV2[i].ageAtPhoto = approxAgeDescription(
                birthDateString: chosen.birthDate,
                photoEarliestYMD: photoEarliest
            )
        }

        // Keep legacy `people` in sync (1 shortName per person)
        let selectedShortNames: [String] = metadata.peopleV2.compactMap { row in
            guard let id = row.identityID,
                  let ident = identityStore.identity(withID: id) else { return nil }
            return ident.shortName
        }

        var cleaned: [String] = []
        for name in selectedShortNames {
            if !cleaned.contains(name) { cleaned.append(name) }
        }
        metadata.people = cleaned
    }

    /// If an identity was deleted from the People Manager, strip it when the image is opened.
    func stripMissingPeopleV2Identities(identityStore: DMPPIdentityStore) {
        guard !metadata.peopleV2.isEmpty else { return }

        for i in metadata.peopleV2.indices {
            guard let id = metadata.peopleV2[i].identityID else { continue }
            if identityStore.identity(withID: id) == nil {
                metadata.peopleV2[i].identityID = nil
                metadata.peopleV2[i].isUnknown = true
                // Keep snapshots as breadcrumbs.
            }
        }

        // Also clean legacy `people` so it doesn't retain deleted labels.
        let stillValidShortNames = Set(
            metadata.peopleV2.compactMap { row -> String? in
                guard let id = row.identityID,
                      let ident = identityStore.identity(withID: id) else { return nil }
                return ident.shortName
            }
        )
        metadata.people.removeAll { !stillValidShortNames.contains($0) }
    }

    // MARK: - Local helper

    /// Minimal, compile-safe age helper (years only) based on YYYY or YYYY-MM-DD.
    private func approxAgeDescription(birthDateString: String?, photoEarliestYMD: String?) -> String? {
        func year(from s: String?) -> Int? {
            guard let s else { return nil }
            let t = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard t.count >= 4 else { return nil }
            return Int(t.prefix(4))
        }

        guard let by = year(from: birthDateString),
              let py = year(from: photoEarliestYMD)
        else { return nil }

        let age = py - by
        guard age >= 0, age <= 130 else { return nil }
        return "\(age)"
    }
}
