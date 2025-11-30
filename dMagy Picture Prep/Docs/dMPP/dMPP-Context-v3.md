# dMPP-Context v3.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2025-11-24-CTX3

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

**As of dMPP-2025-11-24-CTX3**

---

### **3.1 Folder Selection & Image Navigation**

* Uses `NSOpenPanel` to pick any accessible folder

* Scans for supported image formats:

  `jpg, jpeg, png, heic, tif, tiff, webp`

* Builds an ordered list of images

* Supports:

  * **Next Image**
  * **Previous Image**
  * Automatic saving when switching images or folders

* Gracefully handles switching folders (saving current metadata first)

* Navigation controls (`Previous` / `Next`) are anchored at the bottom-right of the metadata column so they stay in a consistent place relative to the window.

---

### **3.2 Image Preview & Metadata Binding**

* Displays a large, scalable image preview using `NSImage`

* Metadata form with live bindings to `DmpmsMetadata`:

  * `title`  
    *For new images (no sidecar), defaults to the filename without extension.*
  * `description`
  * `dateTaken` (supports full and partial dates: YYYY-MM-DD, YYYY-MM, YYYY, YYYYs)
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

For images **without an existing sidecar**, the `DMPPImageEditorViewModel` now:

* Loads the actual image (`NSImage`)
* Computes aspect-correct, centered default crops using the real image size:
  * **Landscape 16:9**
  * **Portrait 8×10 (4:5)**
* Adds those crops to `metadata.virtualCrops`

Users can:

* Add preset crops (16:9, 8×10, 1:1)
* Add a new default 16:9 crop
* Duplicate any existing crop
* Delete any crop
* Switch between crops via a **segmented control** labeled **“Crops”** above the preview
* See a live crop overlay directly on the large image

The **thumbnail preview strip** below the editor has been removed for now; the primary interaction is the main image plus overlay.

---

### **3.4 Interactive Crop Editing**

Crop overlays are now **interactive**:

* The active crop is drawn as a dashed rectangle (using `RectNormalized`) over the scaled image.
* Users can:
  * **Drag the crop** within the image area to re-center it.
  * **Resize the crop** while preserving aspect ratio using:
    * A vertical **“Crop”** control column to the right of the image:
      * `+` button → zoom in (larger crop area)
      * Tall vertical slider → continuous zoom control
      * `–` button → zoom out (smaller crop area)
    * Optional plus/minus shortcuts in code (`scaleSelectedCrop(by:)`).

The ViewModel converts between pixel-space rectangles and normalized rectangles and enforces:

* Crop stays within the image bounds
* Width/height remain positive
* Aspect ratio constraints for the crop

These edits are immediately reflected in `DmpmsMetadata.virtualCrops`.

---

### **3.5 dMPMS Sidecar Read/Write (Complete & Verified)**

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

On **Save** (Next/Previous/folder change):

* Writes JSON with `.prettyPrinted` formatting  
  *(keys are written in struct declaration order; no artificial sorting).*
* Uses atomic replacement to prevent corruption
* Includes default or user-created crops
* Persists the `history` array for crop operations
* Works across multiple navigation events

**Sidecar reading and writing remain verified with App Sandbox enabled.**

---

### **3.6 dMPMS History Tracking (Crop Operations)**

`DmpmsMetadata.history` is now **actively populated** for crop-related actions via `HistoryEvent` entries that record:

* `action` (e.g., `"createCrop"`, `"duplicateCrop"`, `"deleteCrop"`, `"updateCropRect", "scaleCrop"`)
* ISO-8601 `timestamp`
* Optional `oldName` / `newName` when labels change
* `cropID` linking the event to a specific `VirtualCrop`

History is currently focused on crop lifecycle and layout changes, not general metadata edits.

---

### **3.7 macOS Sandbox Behavior (Resolved & Documented)**

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

This behavior is now part of the permanent project record.

---

## **4. Technical Architecture**

### **4.1 Key Swift Components**

| File                             | Responsibility                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------ |
| `DMPPImageEditorView.swift`      | UI layout, image loading, navigation, sidecar I/O, high-level editor panes     |
| `DMPPImageEditorViewModel.swift` | Crop management, interactive crop math, metadata binding, tag/people helpers   |
| `DMPPCropOverlayView.swift`      | Draws the dashed crop rectangle and handles drag/interaction events            |
| `Models/DmpmsCropsModels.swift`  | dMPMS crop-related models (`RectNormalized`, `VirtualCrop`)                    |
| `Models/DmpmsMetadata.swift`     | Core dMPMS metadata (`DmpmsMetadata`, `HistoryEvent`)                           |
| `dMagy_Picture_PrepApp.swift`    | Application entry point                                                        |
| `Resources/*`                    | Default images or helper assets                                                |

---

### **4.2 Data Flow Overview**

```
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
    based on image size (16:9 + 8×10)
           ↓
User edits metadata + crops in UI
 (drag crop, zoom via slider/buttons,
  edit title/date/tags/people)
           ↓
On image change or folder change:
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

## **5. Known Limitations (as of CTX3)**

* Crop overlays are:
  * Movable and zoomable, but
  * Still locked to a fixed aspect ratio per crop (no arbitrary freeform resize)
  * No rotation support
* No “has metadata” indicator in UI
* No batch processing or “skip images with sidecars”
* No history or undo system for non-crop metadata changes (title, date, tags, etc.)
* No visual preview of *output* crops separate from the main editor
* No keyboard-driven workflow

These are feature opportunities, not blockers.

---

## **6. Roadmap (Short-Term)**

### **6.1 High Priority**

* Per-image metadata status (New / Existing / Modified)
* Auto-advance option after save
* Better visual affordances for crop limits (e.g., snap-to-edges, safe-zone guides)

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
dMPP-2025-11-24-CTX3
```

Future revisions should use:

```
dMPP-YYYY-MM-DD-CTX#
```

or feature-specific variants:

```
dMPP-2026-01-10-CTX4-cropPolish
dMPP-2026-02-18-CTX5-batchOps
dMPP-2026-03-02-CTX6-statusUI
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

## **End of dMPP-Context-v3.md**
