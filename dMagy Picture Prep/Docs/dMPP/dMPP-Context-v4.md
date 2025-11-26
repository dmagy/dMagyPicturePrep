# dMPP-Context v4.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2025-11-26-CTX4  

---

## **1. Purpose of dMagy Picture Prep (dMPP)**

dMPP is a macOS utility that prepares personal and archival photographs for advanced display workflows. It provides an efficient, non-destructive way to:

* Assign rich metadata according to the **dMagy Photo Metadata Standard (dMPMS)**
* Create and manage **virtual crops** customized for multiple display targets
* Navigate through folders of images in a structured reviewing workflow
* Persist edits in **sidecar metadata files** for use in other applications (e.g., dMagy Picture Show)

Where **dMPS shows pictures**, **dMPP prepares them**.

----

## **2. Relationship to dMPMS and dMPS**

### **dMPP ↔ dMPMS**

dMPP is the first full implementation of the dMPMS metadata standard.
It is responsible for:

* Loading metadata from sidecar `.dmpms.json` files
* Writing updated metadata in the standardized format
* Enforcing dMPMS compatibility at runtime

### **dMPP ↔ dMPS**

The apps communicate exclusively through **dMPMS sidecars**.  
dMPP sets up image metadata and virtual crops; dMPS consumes them when rendering slideshows across multiple displays.

They are intentionally **decoupled** to keep the viewer lightweight and the prep tool flexible.

---

## **3. Current Features (What’s Built Now)**

**As of dMPP-2025-11-26-CTX4**

---

### **3.1 Folder Selection & Image Navigation**

* Uses `NSOpenPanel` to pick any accessible folder

* Scans for supported image formats:

  `jpg, jpeg, png, heic, tif, tiff, webp`

* Builds an ordered list of images

* Supports:

  * **Previous Picture**
  * **Next Picture**
  * Automatic saving when switching images or folders
  * Explicit **Save** button (Command–S) for “save before you move on” behavior

* Gracefully handles switching folders (saving current metadata first)

* Navigation controls are anchored in a **bottom bar** so they stay in a consistent place relative to the window.

---

### **3.2 Image Preview & Metadata Binding**

* Displays a large, scalable image preview using `NSImage`

* Metadata form with live bindings to `DmpmsMetadata`:

  * `title`  
    *For new images (no sidecar), defaults to the filename **without** extension.*
  * `description`
  * `dateTaken` (supports full and partial dates: `YYYY-MM-DD`, `YYYY-MM`, `YYYY`, `YYYYs`)
  * `tags` (comma-separated)
  * `people` (comma-separated)

* UI uses SwiftUI `Form`, `TextField`, and binding helpers

All editing is live-bound to the ViewModel.

---

### **3.3 Virtual Crop System**

Every image ultimately has one or more **virtual crops**, each represented as:

```swift
RectNormalized(x: 0–1, y: 0–1, width: 0–1, height: 0–1)
```

in image space, and stored in `VirtualCrop` records inside `DmpmsMetadata.virtualCrops`.

For images **without an existing sidecar**, the `DMPPImageEditorViewModel`:

* Loads the actual image (`NSImage`)
* Computes aspect-correct, centered default crops using the real image size:
  * **Landscape 16:9**
  * **Portrait 8×10 (4:5)**

Users can add a variety of presets via a **“New Crop”** menu, grouped by use case:

**Screen**

* Original (full image) — aspect inferred from the actual pixel dimensions  
* Landscape 16:9  
* Portrait 9:16  
* Landscape 4:3  

**Print & Frames**

* Portrait 8×10 (4:5)  
* Headshot 8×10 (4:5) — same aspect as 8×10, but with special headshot guides  

**Other**

* Square 1:1  
* Custom… (freeform aspect; still normalized to the image)

Additional behavior:

* Each crop has a human-readable label and aspect description.
* Crop IDs are generated to be unique per image.
* The **first crop** is auto-selected when an image loads.

Users can:

* Add any of the above presets
* Add “Original” full-frame crops
* Duplicate the current crop
* Delete the current crop
* Switch between crops via a **segmented control** labeled **“Crops”** above the preview

The **thumbnail preview strip** from earlier versions remains removed; the primary interaction is now the main image plus overlay.

---

### **3.4 Interactive Crop Editing**

Crop overlays are **interactive**:

* The active crop is drawn as a dashed rectangle (using `RectNormalized`) over the scaled image.
* Users can:
  * **Drag the crop** within the image area to re-center it (movement is constrained to stay fully within the image).
  * **Resize the crop** while preserving the crop’s aspect ratio using a dedicated **“Crop”** control column to the right of the image:
    * `+` button → makes the crop **larger** (shows more of the image)
    * Tall vertical slider → continuous size control
    * `–` button → makes the crop **smaller** (zooms in)

The ViewModel:

* Converts between pixel-space rectangles and normalized rectangles
* Ensures:
  * Crop stays within the image bounds
  * Width/height remain positive
  * Aspect ratio constraints for the crop are preserved
* Records crop changes into `history` for later review

These edits are immediately reflected in `DmpmsMetadata.virtualCrops`.

---

### **3.5 Headshot Preset & Guides**

For consistent portrait work (e.g., Heritage site headshots), dMPP now includes a specific **Headshot 8×10** preset:

* Uses the same **4:5** aspect ratio as Portrait 8×10.
* Labeled separately as **“Headshot 8×10”** so the UI can attach special guides.
* Starts as a centered 4:5 crop that can still be moved and resized.

When a **Headshot 8×10** crop is active:

* A dashed **crosshair overlay** appears inside the crop, drawn in white.
* The overlay implements an 8×10-inspired grid:
  * Vertical lines at 2/8 and 6/8 of the crop width
  * Horizontal lines at 1/10 and 7/10 of the crop height
* The guides move and scale **with** the crop, so they always align with the current headshot frame.

These guides are purely visual; they don’t change the stored crop rect.

---

### **3.6 dMPMS Sidecar Read/Write (Complete & Verified)**

For each image, dMPP reads/writes:

```
<filename>.<extension>.dmpms.json
```

On **Load**:

* If sidecar exists → decode and bind
  * `sourceFile` is forced to match the current image filename.
* If missing → `makeDefaultMetadata(for:)` creates default metadata:
  * `sourceFile` = filename with extension
  * `title` = filename without extension
  * `virtualCrops` starts empty and is filled by the ViewModel once the image is loaded.

On **Save** (Next/Previous/folder change or explicit **Save**):

* Writes JSON with `.prettyPrinted` formatting  
  *(keys are written in struct declaration order; no artificial sorting).*
* Uses atomic replacement to prevent corruption
* Includes default or user-created crops
* Persists the `history` array for crop operations
* Works across multiple navigation events

**Sidecar reading and writing remain verified with App Sandbox enabled.**

---

### **3.7 dMPMS History Tracking (Crop Operations)**

`DmpmsMetadata.history` is actively populated for crop-related actions via `HistoryEvent` entries that record:

* `action` (e.g., `"createCrop"`, `"duplicateCrop"`, `"deleteCrop"`, `"updateCropRect"`, `"scaleCrop"`, `"sliderScaleCrop"`)
* ISO-8601 `timestamp`
* Optional `oldName` / `newName` when labels change
* `cropID` linking the event to a specific `VirtualCrop`

History is currently focused on crop lifecycle and layout changes, not general metadata edits.

---

### **3.8 macOS Sandbox Behavior (Resolved & Documented)**

macOS restricts writing to certain folder names:

* Pictures
* Desktop
* Documents
* Downloads
* Movies
* Music

even when they appear *inside cloud folders* (Dropbox, etc.).

To support writing to user-selected locations:

* dMPP uses the App Sandbox entitlement:
  **User Selected File → Read/Write**

This enables safe, user-approved writing to:

* Any folder chosen in the open panel
* Any non-TCC-protected folders
* Cloud-synced folders (as long as the folder name isn’t special)

This behavior is part of the permanent project record.

---

### **3.9 Save & Bottom Bar UI**

The bottom bar now combines:

* A **“Delete Crop”** pill on the left, visually attached to the editor area:
  * Red rounded pill inside a white rounded “tab” background
  * Deletes the currently selected crop (if any)
* A centered helper line:
  * “Edits are saved separately; your original photo is never changed.”
  * Reinforces the non-destructive model for less-technical users
* A **Save + navigation cluster** on the right:
  * **Save** (bordered prominent, Command–S shortcut)
  * **Previous Picture**
  * **Previous Crop**
  * **Next Crop**
  * **Next Picture**

This keeps the core navigation and save actions **always visible and reachable in one place**.

---

## **4. Technical Architecture**

### **4.1 Key Swift Components**

| File                             | Responsibility                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------ |
| `DMPPImageEditorView.swift`      | UI layout, image loading, navigation, sidecar I/O, high-level editor panes     |
| `DMPPImageEditorViewModel.swift` | Crop management, interactive crop math, metadata binding, tag/people helpers   |
| `DMPPCropOverlayView.swift`      | Draws the dashed crop rectangle and (for headshots) crosshair guides + drag    |
| `Models/DmpmsCropsModels.swift`  | dMPMS crop-related models (`RectNormalized`, `VirtualCrop`)                    |
| `Models/DmpmsMetadata.swift`     | Core dMPMS metadata (`DmpmsMetadata`, `HistoryEvent`)                           |
| `dMagy_Picture_PrepApp.swift`    | Application entry point                                                        |
| `Resources/*`                    | Default images or helper assets                                                |

---

### **4.2 Data Flow Overview**

```text
Choose Folder → Scan directory → Build list of images
           ↓                         ↓
    loadImage(index)            Supported extensions
           ↓
  Attempt to load sidecar
    if exists → decode
    else → default metadata (no crops)
           ↓
Bind metadata to ViewModel
           ↓
If virtualCrops is empty:
    compute aspect-correct default crops
    based on image size (16:9 + 8x10)
           ↓
User edits metadata + crops in UI
 (drag crop, zoom via slider/buttons,
  edit title/date/tags/people)
           ↓
On explicit Save or image/folder change:
    saveCurrentMetadata()
           ↓
Writes <filename>.<ext>.dmpms.json
 (including virtualCrops + history[])
```

This flow is stable and verified in the current build.

---

### **4.3 Why Sidecars Are Core to dMPP**

Sidecars are:

* Non-destructive
* Compatible with cloud-syncing
* Human-readable
* Versionable
* Extensible
* Separate from the original image
* Lightweight enough to process in batches

This was a central design decision from the beginning of the project.

---

## **5. Known Limitations (as of CTX4)**

* Crop overlays are:
  * Movable and zoomable
  * Still locked to a fixed aspect ratio per crop (no arbitrary freeform resize)
  * Not rotatable
* No “has metadata / has sidecar” indicator in UI
* No batch processing or “skip images with sidecars”
* No history or undo system for non-crop metadata changes (title, date, tags, etc.)
* No visual preview of *output* crops separate from the main editor
* No keyboard-driven workflow beyond Command–S

These are feature opportunities, not blockers.

---

## **6. Roadmap (Short-Term)**

### **6.1 High Priority**

* Per-image metadata status (New / Existing / Modified)
* Auto-advance option after save
* Better visual affordances for crop limits (snap-to-edges, safe zones, warning when hitting bounds)
* Preference for **which crop presets** appear by default (per workflow)

### **6.2 Medium**

* Batch skip existing metadata
* Duplicate current settings to next image
* Batch-create default crops for a folder
* Extend dMPMS `history[]` to include non-crop edits
* Optional thumbnail strip re-introduced as a secondary view (if needed)

### **6.3 Longer-Term**

* dMPS integration (crop choice per display)
* Export tools (cropped previews, thumbnails)
* Keyboard shortcut workflow ("Editor Mode")
* Potential Swift Package for shared metadata models
* Image quality checks (noise, sharpness detection)

---

## **7. Version Tracking**

This document uses the version tag:

```
dMPP-2025-11-26-CTX4
```

Previous revision:

```
dMPP-2025-11-24-CTX3
```

Future revisions should use:

```text
dMPP-YYYY-MM-DD-CTX#
```

or feature-specific variants:

```text
dMPP-2026-01-10-CTX5-cropPolish
dMPP-2026-02-18-CTX6-batchOps
dMPP-2026-03-02-CTX7-statusUI
```

---

## **8. Author Notes**

This file serves as the authoritative record for:

* Architectural decisions
* Workflow definitions
* Constraints encountered (sandboxing, metadata rules, etc.)
* Progress milestones

Updating this document regularly ensures future development remains clear and intentional rather than reactive.

---

## **9. Delta from dMPP-2025-11-24-CTX3**

Changes introduced in **CTX4** relative to **CTX3**:

1. **Crop Preset Expansion**
   * Replaced the earlier “16:9 / 8×10 / 1:1 + extra 16:9” mindset with a broader, grouped preset set:
     * **Screen:** Original (full image), Landscape 16:9, Portrait 9:16, Landscape 4:3  
     * **Print & Frames:** Portrait 8×10, Headshot 8×10, Landscape 4×6  
     * **Other:** Square 1:1, Custom…

2. **Headshot Preset & Guides**
   * Added a dedicated **Headshot 8×10** preset sharing the 4:5 aspect ratio with Portrait 8×10.
   * Implemented **dashed crosshair guides** drawn inside the crop (based on an 8×10-style grid).
   * Ensured guides move and scale correctly with the crop.

3. **Crop UI Row Reorganization**
   * Reworked the top-left editor region into a single row containing:
     * A **segmented “Crops” control** for existing crops (left).
     * A **“New Crop”** menu for presets (right, on the same row).
   * Confirmed the old thumbnail preview strip remains removed.

4. **Save Button & Bottom Bar Layout**
   * Introduced an explicit **Save** button (with Command–S shortcut) in the bottom bar.
   * Renamed navigation buttons to:
     * **Previous Picture**, **Previous Crop**, **Next Crop**, **Next Picture**.
   * Centralized the **helper text**:  
     *“Edits are saved separately; your original photo is never changed.”*
   * Placed **Delete Crop** in a red pill inside a white rounded “tab” that visually attaches to the editor area.

5. **History Actions Refinement**
   * Clarified and extended crop-related history event names, including `"sliderScaleCrop"` for slider-driven size changes (in addition to `scaleCrop` and others).

6. **Documentation Updates**
   * Updated all feature sections to reflect:
     * The expanded preset library
     * The headshot-specific behavior
     * The presence of the bottom bar, Save button, and new button labels
   * Updated known limitations and roadmap to match the current reality of CTX4.

---

## **End of dMPP-Context-v4.md**
