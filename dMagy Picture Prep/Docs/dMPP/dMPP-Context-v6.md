# dMPP-Context v6.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2025-12-04-CTX6  

---

## 1. Purpose of dMagy Picture Prep (dMPP)

dMPP is a macOS utility that prepares personal and archival photographs for advanced display workflows. It provides an efficient, non-destructive way to:

- Assign rich metadata according to the **dMagy Photo Metadata Standard (dMPMS)**
- Create and manage **virtual crops** customized for multiple display targets
- Navigate through folders of images in a structured reviewing workflow
- Persist edits in **sidecar metadata files** for use in other applications (e.g., dMagy Picture Show)

Where **dMPS shows pictures**, **dMPP prepares them**.

---

## 2. Relationship to dMPMS and dMPS

### 2.1 dMPP ↔ dMPMS

dMPP is the first full implementation of the dMPMS metadata standard.  
It is responsible for:

- Loading metadata from sidecar `.dmpms.json` files
- Writing updated metadata in the standardized format
- Enforcing dMPMS compatibility at runtime

### 2.2 dMPP ↔ dMPS

The apps communicate exclusively through **dMPMS sidecars**.  
dMPP sets up image metadata and virtual crops; dMPS consumes them when rendering slideshows across multiple displays.

They are intentionally **decoupled** to keep the viewer lightweight and the prep tool flexible.

---

## 3. Current Features (What’s Built Now)

**As of dMPP-2025-12-04-CTX6**

---

### 3.1 Folder Selection & Image Navigation

- Uses `NSOpenPanel` to pick any accessible folder.
- Scans for supported image formats:  
  `jpg, jpeg, png, heic, tif, tiff, webp`
- Builds an ordered list of images.
- Supports:
  - **Previous Picture**
  - **Next Picture**
  - Automatic saving when switching images or folders
  - Explicit **Save** button (**Command–S**) for “save before you move on” behavior
- Gracefully handles switching folders (saving current metadata first).
- Navigation controls live in a **bottom bar** so they stay in a consistent place relative to the window.

---

### 3.2 Image Preview & Metadata Binding

- Displays a large, scalable image preview using `NSImage`.
- Metadata form with live bindings to `DmpmsMetadata`:
  - `title`  
    - For new images (no sidecar), defaults to the filename **without** extension.
  - `description`
  - `dateTaken` (supports full and partial dates: `YYYY-MM-DD`, `YYYY-MM`, `YYYY`, `YYYYs`)
  - `tags` (comma-separated)
  - `people` (comma-separated)
- UI uses SwiftUI `Form`, `TextField`, and binding helpers.

All editing is live-bound to the ViewModel.

---

### 3.3 Virtual Crop System

Every image has one or more **virtual crops**, each represented as:

```swift
RectNormalized(x: 0–1, y: 0–1, width: 0–1, height: 0–1)
```

in image space, stored in `VirtualCrop` records inside `DmpmsMetadata.virtualCrops`.

For images **without an existing sidecar**, the `DMPPImageEditorViewModel` now:

- Loads the actual image (`NSImage`).
- Loads **user preferences** from `DMPPUserPreferences`.
- Uses `defaultCropPresets` / `effectiveDefaultCropPresets` to decide which crops to auto-create.
- For each configured preset, creates a centered, aspect-correct crop based on the image’s actual size.

Built-in presets available under the **“New Crop”** menu (and for defaults) are grouped by use case:

#### Screen

- **Original (full image)** — aspect inferred from actual pixel dimensions
- **Landscape 16:9**
- **Portrait 9:16**
- **Landscape 4:3**

#### Print & Frames

- **Portrait 8×10** (4:5)
- **Headshot 8×10** (4:5, with special guides)
- **Landscape 4×6** (3:2)

#### Custom & Other

- **Square 1:1**
- **Freeform** (no fixed aspect; per-image)
- **Custom presets defined in Settings** (label + W:H, opt-in as defaults)
- **Manage Custom Presets…** — opens Settings to manage custom crop presets

Additional behavior:

- Each crop has a human-readable label and stored aspect description.
- Crop IDs are generated to be unique per image.
- The **first crop** is auto-selected when an image loads.
- For a given image, presets that have already been created (by label) are **greyed out/disabled** in the New Crop menu to avoid duplicates:
  - This applies to both built-in presets and user-defined custom presets.
- **Freeform** crops use `aspectWidth = 0`, `aspectHeight = 0` in dMPMS to indicate “no fixed aspect”.

Users can:

- Add any of the preset crops (Screen / Print & Frames / Custom).
- Create **Freeform** crops.
- Add crops from **custom presets** defined in Settings.
- Duplicate the current crop.
- Delete the current crop.
- Switch between crops via a **segmented control** labeled **“Crops”** above the preview.

The old thumbnail strip remains removed; the main image + overlay is the primary editor.

---

### 3.4 Interactive Crop Editing

Crop overlays are **interactive**:

- The active crop is drawn as a dashed rectangle over the scaled image.
- Everything **outside** the crop is tinted with a **black overlay at ~0.75 opacity**, so the crop area “pops” visually.
- Users can:
  - **Drag the crop** within the image area (constrained to stay fully inside the image).
  - **Resize the crop** using the vertical **“Crop”** control column:
    - `+` button → increase crop size (shows more of the image).
    - Tall vertical slider → continuous size control.
    - `–` button → decrease crop size (zooms in).

Aspect behavior:

- For **fixed-aspect crops**, resizing via the slider/buttons preserves the aspect ratio.
- For **Freeform crops**, the user can:
  - Drag the crop as usual.
  - Resize using a **bottom-right square handle**, which adjusts width and height independently, creating non-locked shapes.
  - Still adjust overall scale with the slider/buttons; the app keeps the FREEFORM aspect rather than snapping back to square.

The ViewModel:

- Converts between pixel-space rectangles and normalized rectangles.
- Ensures:
  - Crop stays within image bounds.
  - Width/height remain positive.
- Records crop changes into `history` for later review (with some throttling to avoid flood of duplicate events).

---

### 3.5 Headshot Preset & Guides

For consistent portrait work (e.g., Heritage site headshots), dMPP includes a dedicated **Headshot 8×10** preset:

- Uses the same **4:5** aspect ratio as Portrait 8×10.
- Labeled **“Headshot 8×10”** so the UI can attach special guides.
- Starts as a centered 4:5 crop that can be moved and resized.

When a **Headshot 8×10** crop is active:

- A dashed **crosshair overlay** appears inside the crop.
- The overlay implements an 8×10-inspired grid:
  - Vertical lines at 2/8 and 6/8 of crop width.
  - Horizontal lines at 1/10 and 7/10 of crop height.
- Guides move and scale with the crop so they always align with the frame.

These guides are purely visual and do not change the stored crop rect.

---

### 3.6 dMPMS Sidecar Read/Write (Complete & Verified)

For each image, dMPP reads/writes:

```text
<filename>.<extension>.dmpms.json
```

On **Load**:

- If sidecar exists → decode and bind:
  - `sourceFile` is forced to match the current image filename.
- If missing → `makeDefaultMetadata(for:)` creates default metadata:
  - `sourceFile` = filename with extension.
  - `title` = filename without extension.
  - `virtualCrops` starts empty and is filled by the ViewModel once the image is loaded.

On **Save** (Next/Previous/folder change or explicit **Save**):

- Writes JSON with `.prettyPrinted` formatting  
  (keys are written in struct declaration order; no artificial sorting).
- Uses atomic replacement to prevent corruption.
- Includes default or user-created crops.
- Persists the `history` array for crop operations.
- Works across multiple navigation events.

Sidecar files now include a **human-readable warning field** near the top of the JSON (e.g., `fileNote` or equivalent) explaining that:

- The file was generated by **dMagy Picture Prep**.
- It stores metadata and crop settings for the associated image.
- Users should not delete or manually edit it unless they know what they’re doing.

**Sidecar reading and writing remain verified with App Sandbox enabled.**

---

### 3.7 dMPMS History Tracking (Crop Operations)

`DmpmsMetadata.history` is populated for crop-related actions via `HistoryEvent` entries that record:

- `action` (e.g., `"createCrop"`, `"duplicateCrop"`, `"deleteCrop"`, `"updateCropRect"`, `"scaleCrop"`, `"sliderScaleCrop"`)
- ISO-8601 `timestamp`
- Optional `oldName` / `newName` when labels change
- `cropID` linking the event to a specific `VirtualCrop`

History is focused on crop lifecycle and layout changes, not general metadata edits.

To avoid excessively noisy history (especially while dragging or scrubbing the slider):

- Updates are **throttled/coalesced** so that a drag/resize gesture doesn’t generate dozens of identical `updateCropRect` events with the same timestamp and label.

---

### 3.8 macOS Sandbox Behavior (Resolved & Documented)

macOS restricts writing to certain folder names:

- Pictures
- Desktop
- Documents
- Downloads
- Movies
- Music

even when they appear *inside* cloud folders (Dropbox, etc.).

To support writing to user-selected locations:

- dMPP uses the App Sandbox entitlement:  
  **User Selected File → Read/Write**

This enables safe, user-approved writing to:

- Any folder chosen in the open panel
- Any non-TCC-protected folders
- Cloud-synced folders (as long as the folder name isn’t one of the restricted names above)

This behavior is part of the permanent project record.

---

### 3.9 Save & Bottom Bar UI

The bottom bar combines:

- A **“Delete Crop”** pill on the left, visually attached to the editor area:
  - Red rounded pill inside a white rounded “tab” background.
  - Deletes the currently selected crop (if any).
- A centered helper line:
  - “Edits are saved separately; your original photo is never changed.”
  - Reinforces the non-destructive model for less-technical users.
- A **Save + navigation cluster** on the right:
  - **Save** (bordered prominent, Command–S shortcut)
  - **Previous Picture**
  - **Previous Crop**
  - **Next Crop**
  - **Next Picture**

This keeps core navigation and save actions **always visible and reachable**.

---

### 3.10 User Preferences & Settings (Defaults + Custom Presets)

dMPP now includes a **Settings** window (standard macOS Settings scene) with a **“Crop Presets”** section powered by `DMPPUserPreferences`.

Key parts:

#### 3.10.1 User Preferences Model

`DMPPUserPreferences` (Codable, stored in `UserDefaults`) currently includes:

- `enum CropPresetID: String, Codable, CaseIterable` for built-in presets:
  - `.original`
  - `.landscape16x9`
  - `.portrait8x10`
  - `.headshot8x10`
  - `.landscape4x6`
  - `.square1x1`
- `var defaultCropPresets: [CropPresetID]`  
  - Ordered list of which presets should be auto-created for **new images** with no crops.
  - Users can toggle each built-in preset on/off via checkboxes.
- `var customCropPresets: [CustomCropPreset]`  
  where `CustomCropPreset` is a small struct:
  - `id` (UUID)
  - `label: String`
  - `aspectWidth: Int`
  - `aspectHeight: Int`
  - `isDefaultForNewImages: Bool`
- `effectiveDefaultCropPresets` helper:
  - De-duplicates presets while preserving order.
  - If the user turns **everything off**, falls back to `.original` only (so dMPP can still be used for “metadata-only” workflows).

#### 3.10.2 Crop Preferences UI

The Settings window includes:

- **Built-in defaults section**:
  - Checkboxes for:
    - Original (full image)
    - Landscape 16:9
    - Portrait 8×10
    - Headshot 8×10
    - Landscape 4×6
    - Square 1:1
  - These map directly to `defaultCropPresets`.

- **Custom presets table/list**:
  - One row per `CustomCropPreset`.
  - Columns:
    - **Label**
    - **Width : Height** (integer aspect)
    - **Default for new images** (toggle)
  - Controls:
    - **Add** button — appends a new row with default values.
    - **Delete** button or table delete control — removes selected custom presets.

Custom presets are:

- Stored entirely in preferences (not in the sidecars).
- Offered as additional options in the **“New Crop”** menu.
- Optionally auto-created for new images when `isDefaultForNewImages` is true.

#### 3.10.3 Integration with the Editor

- On Editor init, when no crops exist, the ViewModel:
  - Loads preferences.
  - Applies all selected **built-in presets**.
  - Applies any **custom presets** that are marked `isDefaultForNewImages`.
- In the **“New Crop”** menu:
  - Custom presets appear under the Custom section, named by their label.
  - Each custom preset menu item is **disabled** when an existing crop shares the same label for that image.
  - A **“Manage Custom Presets…”** menu item opens the Settings window (`openSettings`) so users can edit presets in context.

---

## 4. Technical Architecture

### 4.1 Key Swift Files & Responsibilities

Below is the current Swift file layout and the primary responsibility of each file.

- **`dMagy_Picture_PrepApp.swift`**  
  - Application entry point (SwiftUI `@main`).
  - Defines main window scene.
  - Defines macOS **Settings** scene that hosts `DMPPCropPreferencesView`.

- **`DMPPImageEditorView.swift`**  
  - High-level editor UI.
  - Hosts the main layout:
    - Top toolbar (folder picker + path).
    - Split view: crop editor pane + metadata form.
    - Bottom bar (Delete Crop, info line, Save + navigation).
  - Manages folder selection and image list.
  - Orchestrates sidecar read/write through helper methods.
  - Creates and owns a single `DMPPImageEditorViewModel?`.

- **`DMPPCropEditorPane.swift`** (if separated; otherwise as nested in `DMPPImageEditorView`)  
  - Left-hand side of the main editor.
  - Handles:
    - **Crops** segmented control.
    - **New Crop** menu (built-in + custom presets + Freeform + Manage Custom Presets…).
    - Main image preview with crop overlay.
    - Vertical Crop control column (+, slider, –).
  - Uses `@Environment(\.openSettings)` to open Settings from the “Manage Custom Presets…” menu item.

- **`DMPPMetadataFormPane.swift`** (if separated; otherwise nested)  
  - Right-hand metadata pane.
  - Displays and binds:
    - `sourceFile`
    - `title`
    - `description`
    - `dateTaken`
    - `tags` and `people` (via text helpers).

- **`DMPPImageEditorViewModel.swift`**  
  - Core editor logic and state for a single image.
  - Responsibilities:
    - Holds `imageURL`, `nsImage`, and `metadata: DmpmsMetadata`.
    - Manages `virtualCrops` and `selectedCropID`.
    - Computes default crops when no sidecar crops exist, using `DMPPUserPreferences`.
    - Provides methods like:
      - `addPresetOriginalCrop()`, `addPresetLandscape16x9()`, `addPresetPortrait8x10()`, `addPresetHeadshot8x10()`, `addPresetLandscape4x3()`, `addPresetLandscape4x6()`, `addPresetSquare1x1()`, `addFreeformCrop()`, `addCrop(fromCustomPreset:)`, etc.
      - `updateVirtualCropRect`, `scaleSelectedCrop(by:)`, `selectNextCrop()`, `selectPreviousCrop()`, `deleteSelectedCrop()`.
    - Handles history event creation for crop operations.

- **`DMPPCropOverlayView.swift`**  
  - SwiftUI view responsible for:
    - Drawing the tinted mask outside the crop.
    - Drawing the dashed border for the crop.
    - Drawing **headshot grid** guides when needed.
    - Hit-testing and gestures for:
      - Dragging the crop.
      - Freeform resize handle behavior.
    - Reporting rect changes back via closures.

- **`DMPPUserPreferences.swift`**  
  - Stores user-level preferences:
    - Built-in default crop presets (`defaultCropPresets`).
    - Custom crop presets (`customCropPresets`).
  - Encodes/decodes preferences to and from `UserDefaults`.
  - Provides helpers like `effectiveDefaultCropPresets`.

- **`DMPPCropPreferencesView.swift`**  
  - Settings UI for Crop Presets.
  - Binds to `DMPPUserPreferences`:
    - Renders checkboxes for built-in defaults.
    - Renders a table/list for custom presets (label, Width : Height, Default for new images).
    - Provides Add/Delete controls.
  - Saves back to preferences on change.

- **`Models/DmpmsCropsModels.swift`**  
  - Data models related to cropping:
    - `RectNormalized` (x, y, width, height in 0–1 image space).
    - `VirtualCrop` (id, label, aspect, rect).
  - Codable and Hashable to be stored in sidecars.

- **`Models/DmpmsMetadata.swift`**  
  - Core dMPMS metadata:
    - `DmpmsMetadata` (title, sourceFile, description, dateTaken, tags, people, virtualCrops, history, and the file note).
    - `HistoryEvent` for change logging.
  - Defines coding key order so sidecars are written in a stable, predictable structure.

---

## 5. Known Limitations (as of CTX6)

- Crop overlays:
  - Are movable and zoomable.
  - Fixed-aspect crops still **cannot rotate**.
  - Freeform crops do not yet support typed-in numeric W:H or snapping to common ratios.
- No “has metadata / has sidecar” indicator in the main UI.
- No batch processing or “skip images with sidecars”.
- No history or undo system for non-crop metadata changes (title, date, tags, etc.).
- No separate “output preview” distinct from the main editor.
- No full keyboard-driven workflow beyond Command–S and standard nav.

These remain feature opportunities, not blockers.

---

## 6. Roadmap (Short-Term)

### 6.1 High Priority

- Per-image metadata status (New / Existing / Modified).
- Auto-advance option after Save.
- Better visual affordances for crop limits (snap-to-edges, safe zones, warning when hitting bounds).
- Additional preferences in `DMPPUserPreferences` for metadata defaults (e.g., date patterns, auto-tags from folder).
- Optional “Preview mode” that hides UI chrome and shows just the cropped result.

### 6.2 Medium

- Batch skip existing metadata / sidecars.
- Duplicate current settings (metadata + crops) to the next image.
- Batch-create default crops for a folder, honoring user preferences.
- Extend dMPMS `history[]` to include non-crop edits.
- Optional thumbnail strip re-introduced as a secondary view.

### 6.3 Longer-Term

- Deep dMPS integration (crop choice per display and per slideshow).
- Export tools (cropped previews, thumbnails, contact sheets).
- Rich keyboard shortcut workflow (“Editor Mode”).
- Swift Package for shared metadata models between dMPS and dMPP.
- Image quality checks (noise, sharpness detection) and visual flags.

---

## 7. Version Tracking

This document uses the version tag:

```text
dMPP-2025-12-04-CTX6
```

Previous revisions:

```text
dMPP-2025-11-30-CTX5
dMPP-2025-11-26-CTX4
dMPP-2025-11-24-CTX3
```

Future revisions should use:

```text
dMPP-YYYY-MM-DD-CTX#
```

or feature-specific variants:

```text
dMPP-2026-01-10-CTX7-cropPolish
dMPP-2026-02-18-CTX8-batchOps
dMPP-2026-03-02-CTX9-statusUI
```

---

## 8. Author Notes

This file serves as the authoritative record for:

- Architectural decisions
- Workflow definitions
- Constraints encountered (sandboxing, metadata rules, etc.)
- Progress milestones

Updating this document regularly helps keep future development clear and intentional rather than reactive.

---

## 9. Delta from dMPP-2025-11-30-CTX5

Changes introduced in **CTX6** relative to **CTX5**:

1. **User Preferences for Crop Defaults**
   - Implemented `DMPPUserPreferences` with:
     - `CropPresetID` for built-in presets.
     - `defaultCropPresets` for which presets are created on new images.
     - `customCropPresets` to store user-defined presets (label + W:H + default flag).
   - Added `effectiveDefaultCropPresets` to de-duplicate presets and guarantee at least one crop (Original) when everything is turned off.

2. **Settings Window & Crop Presets UI**
   - Added a standard macOS Settings window (App Settings scene).
   - Introduced `DMPPCropPreferencesView`:
     - Checkboxes for built-in default presets.
     - Table/list for custom presets with label, Width : Height, and “Default for new images” toggle.
     - Add/Delete controls for managing custom presets.
   - Hooked Settings to the app menu and wired **“Manage Custom Presets…”** from the New Crop menu to open the Settings window via `openSettings`.

3. **Default Crop Creation Now Respects Preferences**
   - Replaced hard-coded “start with 16:9 + 8×10” behavior:
     - When an image has no crops, the ViewModel:
       - Loads `DMPPUserPreferences`.
       - Creates crops for each selected built-in preset.
       - Creates crops for any custom presets flagged as default for new images.
   - Ensured that the **first created crop** becomes the selected crop.

4. **Custom Presets in New Crop Menu**
   - Added custom preset items to the **“New Crop”** menu:
     - Each appears with its label.
     - Selecting it creates a crop using the defined W:H ratio and label.
   - Custom preset menu items are now **disabled** when a crop with the same label already exists for the current image, preventing duplicates.

5. **Freeform Aspect Persistence & History Throttling**
   - Ensured Freeform crops:
     - Retain their non-square aspect when using the slider/buttons (no more snapping back to square).
   - Tightened history recording so:
     - Rapid drag/resize operations do not generate large bursts of identical `updateCropRect` entries.
     - History is still accurate but more compact and readable.

6. **Sidecar FileNote / Warning**
   - Extended `DmpmsMetadata` to include a top-level “file note” style field explaining:
     - The file’s purpose.
     - That it was created by dMagy Picture Prep.
     - That manual deletion or editing may impact slideshows and metadata workflows.

7. **Documentation & File List Updates**
   - Updated the context document to:
     - Reflect user preferences and custom preset behavior.
     - Describe the Settings window and how it interacts with default crops.
     - Document the current Swift file layout and the responsibility of each major file for future maintenance.

---

## End of dMPP-Context-v6.md
