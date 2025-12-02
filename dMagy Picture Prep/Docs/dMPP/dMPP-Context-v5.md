# dMPP-Context v5.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2025-11-30-CTX5  

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

**As of dMPP-2025-11-30-CTX5**

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

For images **without an existing sidecar**, the `DMPPImageEditorViewModel` now:

* Loads the actual image (`NSImage`)
* Consults **user preferences** (see §3.10) for which default presets to create
* Computes aspect-correct, centered default crops using the real image size
* Instantiates those crops in the order defined by the user

Out of the box, the default set is:

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
* Freeform (aspect-free crop stored as “custom”)  
* Custom… (internal/freeform option, currently similar to Freeform but reserved for future UI)

Additional behavior:

* Each crop has a human-readable label and aspect description.
* Crop IDs are generated to be unique per image.
* The **first crop** is auto-selected when an image loads.

Users can:

* Add any of the above presets (subject to the “one per preset” rule; see §3.11)
* Add “Original” full-frame crops
* Duplicate the current crop
* Delete the current crop
* Switch between crops via a **segmented control** labeled **“Crops”** above the preview

The **thumbnail preview strip** from earlier versions remains removed; the primary interaction is now the main image plus overlay.

---

### **3.4 Interactive Crop Editing**

Crop overlays are **interactive**:

* The active crop is drawn as a dashed rectangle (using `RectNormalized`) over the scaled image.
* The rest of the image is covered with a semi-transparent **black tint**, with a clear “hole” over the crop:
  * This makes the in-crop region “pop” and gives a strong sense of “this is the part that will show.”
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
  * Aspect ratio constraints for the crop are preserved for fixed-aspect crops
* Records crop changes into `history` for later review

These edits are immediately reflected in `DmpmsMetadata.virtualCrops`.

*(Note: **Freeform** crops are represented as aspect-free (width/height can vary independently) but still share some scaling behaviors with fixed-aspect crops; full “drag-handle” editing is a future enhancement.)*

---

### **3.5 Headshot Preset & Guides**

For consistent portrait work (e.g., Heritage site headshots), dMPP includes a specific **Headshot 8×10** preset:

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

```text
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

A new top-level string field, **`metadataComment`**, is now included in each dMPMS file:

* Example content: `"Generated and maintained by dMagy Picture Prep. Do not edit or delete this file unless you know what you’re doing."`
* This provides a **human-readable warning** for anyone who discovers the file in a synced folder.

**Sidecar reading and writing remain verified with App Sandbox enabled.**

---

### **3.7 dMPMS History Tracking (Crop Operations)**

`DmpmsMetadata.history` is actively populated for crop-related actions via `HistoryEvent` entries that record:

* `action` (e.g., `"createCrop"`, `"duplicateCrop"`, `"deleteCrop"`, `"updateCropRect"`, `"scaleCrop"`, `"sliderScaleCrop"`)
* ISO-8601 `timestamp`
* Optional `oldName` / `newName` when labels change
* `cropID` linking the event to a specific `VirtualCrop`

Notes:

* Drag-based updates currently generate **multiple `updateCropRect` events** during a drag gesture.
* This produces very detailed but sometimes *dense* histories; future versions may throttle or coalesce events (e.g., “drag start / drag end”) to keep files more compact.

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

The bottom bar combines:

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

### **3.10 User Preferences for Default Crop Presets**

dMPP now includes a user-level preferences model:

```swift
struct DMPPUserPreferences: Codable {
    enum CropPresetID: String, Codable, CaseIterable {
        case original
        case landscape16x9
        case portrait8x10
        case headshot8x10
        case landscape4x6
        case square1x1
        // (Freeform is always created explicitly, not as an automatic default.)
    }

    var defaultCropPresets: [CropPresetID] = [
        .landscape16x9,
        .portrait8x10
    ]

    static func load() -> DMPPUserPreferences { … }
    func save() { … }
}
```

Key behaviors:

* Preferences are stored in `UserDefaults` as a JSON blob under a stable key.
* `defaultCropPresets` defines:
  * Which presets should be created **automatically** when an image with no crops is first opened.
  * The **order** in which those crops appear.
* If preferences are missing or corrupted:
  * dMPP falls back to the built-in default of `Landscape 16:9` + `Portrait 8×10`.

The ViewModel’s initializer now:

1. Loads `DMPPUserPreferences` via `DMPPUserPreferences.load()`.
2. If the image has no `virtualCrops`, it uses `defaultCropPresets` to decide which `addPreset…` methods to call for that image size.

This decouples the app’s behavior from any hard-coded set of defaults and lets different users tailor their starting set to their own workflows (e.g., “screen-only,” “print-first,” etc.).

---

### **3.11 “One of Each” Rule for Built-in Presets**

To avoid having multiple indistinguishable copies of the same preset for a single image:

* Each built-in preset (Original, 16:9, Portrait 8×10, Headshot, etc.) is intended to have **at most one instance per image**.
* The **“New Crop”** menu:
  * Uses an internal mapping from existing crops → `CropPresetID`.
  * Disables menu items for presets that are already present for the current image.
  * Leaves other items enabled so they can be added as needed.

You can still:

* Duplicate an existing crop if you want a second 16:9 with a different framing.
* Add Freeform crops explicitly.

The “one-of-each” rule primarily keeps the New Crop menu readable and avoids accidental clutter.

---

### **3.12 Preferences UI & macOS Settings Integration**

dMPP now exposes a dedicated **Preferences / Settings** window for crop defaults:

* Implemented as a SwiftUI `Settings` scene:

  ```swift
  @main
  struct dMagy_Picture_PrepApp: App {
      var body: some Scene {
          WindowGroup {
              DMPPImageEditorView()
          }
          Settings {
              DMPPCropPreferencesView()
          }
      }
  }
  ```

* On macOS, this appears under the app menu as:
  * **dMagy Picture Prep → Settings…** (or **Preferences…**, depending on OS version)
  * Keyboard shortcut: **⌘,**

The `DMPPCropPreferencesView`:

* Presents the list of known `CropPresetID` values.
* Lets the user:
  * Choose which presets should be included in `defaultCropPresets`.
  * Arrange their order (so, for example, 4×6 could come before 8×10).
* Saves changes back into `DMPPUserPreferences` via `save()`.

The preferences model is intentionally extendable for future **metadata defaults** (date patterns, tag policies, etc.) without changing the overall wiring.

---

## **4. Technical Architecture**

### **4.1 Key Swift Components**

| File                             | Responsibility                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------ |
| `DMPPImageEditorView.swift`      | UI layout, image loading, navigation, sidecar I/O, high-level editor panes     |
| `DMPPImageEditorViewModel.swift` | Crop management, interactive crop math, metadata binding, tag/people helpers   |
| `DMPPCropOverlayView.swift`      | Draws the tinted overlay, dashed crop rectangle, and (for headshots) guides    |
| `Models/DmpmsCropsModels.swift`  | dMPMS crop-related models (`RectNormalized`, `VirtualCrop`)                    |
| `Models/DmpmsMetadata.swift`     | Core dMPMS metadata (`DmpmsMetadata`, `HistoryEvent`, `metadataComment`)       |
| `DMPPUserPreferences.swift`      | User-level defaults for crop presets and future metadata preferences           |
| `DMPPCropPreferencesView.swift`  | SwiftUI Preferences UI for configuring default crop presets                    |
| `dMagy_Picture_PrepApp.swift`    | Application entry point + main window + Settings scene                         |
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
    Load DMPPUserPreferences
    For each defaultCropPresets item:
        add corresponding preset using image size
           ↓
User edits metadata + crops in UI
 (drag crop, zoom via slider/buttons,
  edit title/date/tags/people)
           ↓
On explicit Save or image/folder change:
    saveCurrentMetadata()
           ↓
Writes <filename>.<ext>.dmpms.json
 including:
   - metadataComment
   - virtualCrops
   - history[]
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

## **5. Known Limitations (as of CTX5)**

* Crop overlays are:
  * Movable and zoomable
  * Still locked to a fixed aspect ratio per crop (with partial support for freeform)
  * Not rotatable
* Freeform crops:
  * Are stored with aspect-free rects, but
  * Do not yet have a full “drag handle per edge/corner” editor.
* No “has metadata / has sidecar” indicator in UI
* No batch processing or “skip images with sidecars”
* No history or undo system for non-crop metadata changes (title, date, tags, etc.)
* Dragging can generate many `updateCropRect` history entries for a single operation
* No visual preview of *output* crops separate from the main editor
* No keyboard-driven workflow beyond Command–S

These are feature opportunities, not blockers.

---

## **6. Roadmap (Short-Term)**

### **6.1 High Priority**

* Per-image metadata status (New / Existing / Modified)
* Auto-advance option after save
* Better visual affordances for crop limits (snap-to-edges, safe zones, warning when hitting bounds)
* Additional preferences:
  * Which default metadata fields to auto-populate
  * Optional auto-tagging behavior

### **6.2 Medium**

* Batch skip existing metadata
* Duplicate current settings to next image
* Batch-create default crops for a folder
* Extend dMPMS `history[]` to include non-crop edits
* Optional thumbnail strip re-introduced as a secondary view (if needed)
* Smarter history (coalescing drag events into single “move” entries)

### **6.3 Longer-Term**

* dMPS integration (crop choice per display)
* Export tools (cropped previews, thumbnails)
* Keyboard shortcut workflow ("Editor Mode")
* Potential Swift Package for shared metadata models
* Image quality checks (noise, sharpness detection)

---

## **7. Version Tracking**

This document uses the version tag:

```text
dMPP-2025-11-30-CTX5
```

Previous revision:

```text
dMPP-2025-11-26-CTX4
```

Future revisions should use:

```text
dMPP-YYYY-MM-DD-CTX#
```

or feature-specific variants:

```text
dMPP-2026-01-10-CTX6-cropPolish
dMPP-2026-02-18-CTX7-batchOps
dMPP-2026-03-02-CTX8-statusUI
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

## **9. Delta from dMPP-2025-11-26-CTX4**

Changes introduced in **CTX5** relative to **CTX4**:

1. **User Preferences for Crop Defaults**
   * Introduced `DMPPUserPreferences` with a `CropPresetID` enum and a `defaultCropPresets` array.
   * Default auto-created crops (when an image has no sidecar) are now driven by user preferences rather than hard-coded.
   * Preferences are persisted in `UserDefaults` and loaded by the `DMPPImageEditorViewModel` initializer.

2. **Preferences UI & Settings Integration**
   * Added a SwiftUI `Settings` scene hosting `DMPPCropPreferencesView`.
   * Users can open **Settings/Preferences** (⌘,) to configure:
     * Which built-in crop presets are created automatically.
     * The order of those presets.
   * This lays groundwork for future metadata-related preferences.

3. **“One of Each” Rule in New Crop Menu**
   * Implemented logic to map existing crops to canonical `CropPresetID` values.
   * The **“New Crop”** menu now disables presets that already exist for the current image, keeping at most one instance of each built-in preset.
   * Freeform crops and duplicated crops remain available for “expert” use cases.

4. **Freeform Crop Type**
   * Introduced a distinct **Freeform** crop option:
     * Stored with `aspectWidth` / `aspectHeight` set to `0`, marking it as “custom/freeform.”
   * Behaves like other crops in navigation and storage, while setting the stage for richer freeform editing (drag handles, arbitrary aspect changes).

5. **Tinted Outside-Crop Overlay Refinement**
   * Standardized on a darker black tint around the active crop, with a clear “hole” over the crop area.
   * This improves visual focus and gives users a stronger sense of “final framing” without requiring a separate preview mode.

6. **dMPMS JSON Comment Field**
   * Extended `DmpmsMetadata` with a `metadataComment` string field.
   * Each `.dmpms.json` file now includes a short warning that:
     * Identifies the file as generated/maintained by dMagy Picture Prep.
     * Advises users not to edit or delete it unless they know what they’re doing.

7. **History Notes and Future Throttling**
   * Documented current behavior where drag operations generate multiple `updateCropRect` history entries.
   * Clarified intent to introduce throttling or coalescing in future versions to keep histories readable and file sizes smaller.

8. **Documentation & Architecture Table Updates**
   * Updated the architecture table to include:
     * `DMPPUserPreferences.swift`
     * `DMPPCropPreferencesView.swift`
   * Reworked the data flow diagram to show:
     * Preference loading
     * Preset-driven crop creation
     * The new `metadataComment` field in sidecar writes.

---

## **End of dMPP-Context-v5.md**
