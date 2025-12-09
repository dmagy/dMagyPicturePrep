# dMPP-Context v7.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2025-12-07-CTX7  

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

- Current spec: **dMPMS v1.1**
  - Adds `dateRange` for more precise date/era handling.
  - Begins defining a richer **people model** (`peopleInPhoto`) at the schema level (UI/implementation still in progress).

dMPP is responsible for:

- Loading metadata from sidecar `.dmpms.json` files
- Writing updated metadata in the standardized format
- Enforcing dMPMS compatibility at runtime

### 2.2 dMPP ↔ dMPS

The apps communicate exclusively through **dMPMS sidecars**.  
dMPP sets up image metadata and virtual crops; dMPS consumes them when rendering slideshows across multiple displays.

They are intentionally **decoupled** to keep the viewer lightweight and the prep tool flexible.

---

## 3. Current Features (What’s Built Now)

**As of dMPP-2025-12-07-CTX7**

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
- Right-hand metadata pane is driven by `DmpmsMetadata` via live bindings to the ViewModel.

Current fields:

- **File**
  - Read-only `sourceFile` (image filename).
- **Title**
  - Single-line text field.
  - For new images (no sidecar), defaults to the filename **without** extension.
- **Description**
  - Multi-line text field (vertically expanding).
  - Full width inside the group box for better affordance.
- **Date / Era**
  - Label: “Date Taken or Era”.
  - Single-line `TextField` bound to `metadata.dateTaken`.
  - Helper text:
    - Line 1: “Partial dates, decades, and ranges are allowed.”
    - Line 2: `Examples: 1976-07-04, 1976-07, 1976, 1970s, 1975-1977`
  - A **soft validation helper** watches changes and:
    - On valid forms (see 3.3), silently updates `metadata.dateRange`.
    - On invalid forms, keeps the entered string but shows a gentle warning:  
      `Entered value does not match standard forms` plus the example list.

Layout notes:

- Title, Description, and Date/Era fields now take the **full usable width** inside their group boxes.
- Group boxes use consistent internal padding to visually match the left-hand crop area.

---

### 3.3 Date Semantics & `dateRange` (dMPMS v1.1)

dMPMS v1.1 adds:

- `dateTaken: String`
- `dateRange: String?` (new)

Both are stored in `DmpmsMetadata`.

#### 3.3.1 Accepted `dateTaken` formats

The Date/Era field accepts:

1. **Exact date**
   - `YYYY-MM-DD`  
     - e.g., `1976-07-04`
2. **Year + month**
   - `YYYY-MM`  
     - e.g., `1976-07`
3. **Year only**
   - `YYYY`  
     - e.g., `1976`
4. **Decade**
   - `YYYYs`  
     - e.g., `1970s`
5. **Year range**
   - `YYYY-YYYY`  
     - e.g., `1975-1977`  

Other freeform values (e.g., `Summer 1965`) are allowed but treated as **non-standard**, producing a warning.

#### 3.3.2 `dateRange` behavior

- On every change to `dateTaken`, dMPP attempts to parse and compute a canonical `dateRange`:
  - `YYYY-MM-DD` → range from that specific day to itself.
  - `YYYY-MM` → range covering that month.
  - `YYYY` → range covering the full calendar year.
  - `YYYYs` (decade) → range from `YYYY-01-01` to `YYYY+9-12-31`.
  - `YYYY-YYYY` → range from the lower year’s start to the higher year’s end (if in the correct order).
- If the input is **invalid** (e.g., `1975-1960`):
  - `dateTaken` is kept as typed.
  - `dateRange` is left `nil`.
  - A soft, non-blocking warning is shown in the UI.

This allows future tools (dMPP v2, dMPS v2) to use **dateRange** for better filtering and age calculations without forcing the user to be perfectly precise.

#### 3.3.3 Default dates for camera images

For **new sidecars** created for digital photos:

- dMPP attempts to read the capture date from image metadata (EXIF/metadata).
- If a valid date is found, it initializes:
  - `dateTaken` as a `YYYY-MM-DD` string.
  - `dateRange` from that exact date.
- For **scanned or legacy images** without reliable metadata:
  - `dateTaken` starts empty.
  - `dateRange` is `nil` until the user enters something.

---

### 3.4 Tags & People (Editor UI)

The previous “comma separated tags/people” approach has been replaced with a more structured UI.

#### 3.4.1 Tags (checkbox grid)

- dMPP uses a global **available tags** list from `DMPPUserPreferences`.
- The Tags UI presents them as a **two-column checkbox grid**:
  - Each tag appears as a checkbox:
    - Checked → the tag is included in `metadata.tags`.
    - Unchecked → removed from `metadata.tags`.
  - Changes are applied live to `metadata.tags`.

Special behavior:

- A mandatory tag named **“Do Not Display”** is always present:
  - It is **enforced in preferences** (cannot be deleted).
  - Displayed in the Tags Settings tab with a lock icon.
  - Shows up as a normal checkbox in the editor so the user can choose whether a given image should be hidden in displays.

Unknown tags:

- If `metadata.tags` contains values not found in the current `availableTags`:
  - They are not rendered as checkboxes.
  - Instead, a small caption is shown:  
    “Other tags in this photo: name1, name2”
  - This avoids silently dropping information from older sidecars or previous tag lists.

Quick link:

- A `“Add / Edit tags…”` link opens Settings to the Tags tab so users can manage the master tag list.

#### 3.4.2 People (current behavior)

- People are currently represented as a **single text field**:
  - A helper binds this to `metadata.people` via comma-separated names.
- This keeps the current v1 behavior:
  - Simple, flexible, and sidecar-readable.
- A more structured people system (see 3.11) is defined at the spec level but not yet implemented in the UI.

---

### 3.5 Virtual Crop System

Every image has one or more **virtual crops**, each represented as:

```swift
RectNormalized(x: 0–1, y: 0–1, width: 0–1, height: 0–1)
```

in image space, stored in `VirtualCrop` records inside `DmpmsMetadata.virtualCrops`.

For images **without an existing sidecar**, the `DMPPImageEditorViewModel`:

- Loads the actual image (`NSImage`).
- Loads **user preferences** from `DMPPUserPreferences`.
- Uses `effectiveDefaultCropPresets` to decide which crops to auto-create.
- For each configured preset, creates a centered, aspect-correct crop based on the image’s actual size.

Built-in presets available under the **“New Crop”** menu (and for defaults) are grouped by use case:

#### Screen

- **Original (full image)** — aspect inferred from actual pixel dimensions.
- **Landscape 16:9**
- **Portrait 9:16**
- **Landscape 4:3**

#### Print & Frames

- **Portrait 8×10** (4:5)
- **Headshot 8×10** (4:5, with special guides)
- **Landscape 4×6** (3:2)

#### Creative & Custom

- **Square 1:1**
- **Freeform** (no fixed aspect; per-image)
- **Custom presets defined in Settings** (label + W:H, optional “default for new images”)
- **Manage Custom Presets…** — opens Settings.

Additional behavior:

- Each crop has a human-readable label and stored aspect description.
- Crop IDs are unique per image.
- The **first crop** is auto-selected when an image loads.
- For a given image:
  - Presets that have already been created (by label + aspect) are **greyed out/disabled** in the New Crop menu.
  - This applies to both built-in and custom presets.
- **Freeform** crops use `aspectWidth = 0`, `aspectHeight = 0` in dMPMS to indicate “no fixed aspect”.

Users can:

- Add any of the preset crops.
- Create **Freeform** crops.
- Add crops from **custom presets** defined in Settings.
- Duplicate the current crop.
- Delete the current crop.
- Switch between crops via a **segmented control** labeled **“Crops”** above the preview.

The old thumbnail strip remains removed; the main image + overlay is the primary editor.

---

### 3.6 Interactive Crop Editing

Crop overlays are **interactive**:

- The active crop is drawn as a dashed rectangle over the scaled image.
- Everything **outside** the crop is tinted with a **black overlay at ~0.75 opacity**, so the crop area “pops” visually.
- Users can:
  - **Drag the crop** within the image area (constrained to stay fully inside).
  - **Resize the crop** using the vertical **“Crop”** control column:
    - `+` button → increases crop size (shows more of the image).
    - Tall vertical slider → continuous size control.
    - `–` button → decreases crop size (zooms in).

Aspect behavior:

- For **fixed-aspect crops**, resizing via slider/buttons preserves the aspect ratio.
- For **Freeform crops**:
  - A bottom-right square handle lets users change width/height independently.
  - Slider/buttons change scale but preserve the *current* freeform aspect (no snapping back to square).

The ViewModel:

- Converts between pixel-space rectangles and normalized rectangles.
- Ensures crop stays in bounds and dimensions remain positive.
- Records crop changes into `history` with **throttling/coalescing** to avoid floods of identical events from continuous gestures.

---

### 3.7 Headshot Preset & Guides

For consistent portrait work (e.g., Heritage site headshots), dMPP includes a dedicated **Headshot 8×10** preset:

- Uses **4:5** aspect ratio (same as Portrait 8×10).
- Labeled **“Headshot 8×10”** so the UI can attach special guides.
- Starts as a centered 4:5 crop that can be moved and resized.

When a **Headshot 8×10** crop is active:

- A dashed **crosshair overlay** appears inside the crop.
- The overlay implements an 8×10-inspired grid:
  - Vertical lines at 2/8 and 6/8 of crop width.
  - Horizontal lines at 1/10 and 7/10 of crop height.
- Guides move and scale with the crop.

These guides are visual only; they do not change the stored crop rect.

---

### 3.8 dMPMS Sidecar Read/Write

For each image, dMPP reads/writes:

```text
<filename>.<extension>.dmpms.json
```

On **Load**:

- If sidecar exists → decode and bind:
  - `sourceFile` is forced to match the current image filename.
  - `dmpmsNotice` is present or defaulted.
- If missing → `makeDefaultMetadata(for:)` creates default metadata:
  - `dmpmsVersion` = "1.1".
  - `dmpmsNotice` = default human-readable warning.
  - `sourceFile` = filename with extension.
  - `title` = filename without extension.
  - `dateTaken` and `dateRange` initialized from camera metadata if available.
  - `virtualCrops` starts empty and is filled by the ViewModel once the image is loaded.

On **Save** (Next/Previous/folder change or explicit **Save**):

- Writes JSON with `.prettyPrinted` formatting (no key sorting).
- Uses atomic replacement.
- Includes:
  - Metadata fields (title, description, dateTaken, dateRange, tags, people, etc.).
  - `virtualCrops`.
  - `history` for crop actions.
- Sidecars include a **human-facing notice**:

  ```jsonc
  "dmpmsNotice": "Created by dMagy Picture Prep. Stores metadata and crop settings for this photo. Deleting it erases edits (not the original image)."
  ```

App Sandbox:

- Sidecar reading and writing is verified with App Sandbox enabled.
- Writes are allowed only to user-selected folders and non-TCC-protected locations.

---

### 3.9 dMPMS History Tracking (Crop Operations)

`DmpmsMetadata.history` is populated for crop-related actions via `HistoryEvent` entries that record:

- `action` (e.g., `"createCrop"`, `"duplicateCrop"`, `"deleteCrop"`, `"updateCropRect"`, `"scaleCrop"`, `"sliderScaleCrop"`)
- ISO-8601 `timestamp`
- Optional `oldName` / `newName`
- `cropID` linking the event to a specific `VirtualCrop`

To avoid excessively noisy history:

- Continuous operations (dragging, slider scrubbing) are **coalesced** so that a gesture does not produce dozens of identical events.

Non-crop edits (title, description, tags, people, dates) are still not logged in `history` and are tracked only by the sidecar’s final state.

---

### 3.10 User Preferences & Settings (Crops & Tags)

dMPP includes a standard macOS **Settings** window with a tabbed view for **Crops** and **Tags**, driven by `DMPPUserPreferences`.

#### 3.10.1 Crops tab

- **Built-in presets section**
  - Checkboxes for:
    - Original (full image)
    - Landscape 16:9
    - Portrait 8×10
    - Headshot 8×10
    - Landscape 4×6
    - Square 1:1
  - These map to `defaultCropPresets`.

- **Custom presets section**
  - Each row corresponds to a `CustomCropPreset`:
    - Label
    - Width : Height (integer fields)
    - “Default” checkbox (include for new images).
  - Add Preset button → appends a new preset with default values.
  - Trash button → deletes that preset.

- When preferences change, they are immediately encoded, saved, and a  
  `dmppPreferencesChanged` notification is posted so open editors can react if needed.

#### 3.10.2 Tags tab

- **Header** explains that tags here become the checkbox list in the editor.
- For each `availableTags` entry:
  - If the tag equals the mandatory `DMPPUserPreferences.mandatoryTagName` (currently `"Do Not Display"`):
    - It is rendered as a simple text row with a small **lock** icon on the right.
    - It cannot be edited or deleted.
  - Otherwise:
    - It is editable via a `TextField`.
    - A trash button allows deletion.

- “Add Tag” button:
  - Appends `"New Tag"` to `availableTags`.

Mandatory behavior:

- On save, `DMPPUserPreferences` ensures the mandatory tag exists in `availableTags`.
- The editor ensures it can always present that tag as a checkbox.

Notification:

- As with crop preferences, changes to tags fire the same `dmppPreferencesChanged` notification.
- Open editor views listen and refresh their local `availableTags` list so newly created tags appear **immediately** in the current image.

---

### 3.11 People & Identity Model (Schema-Level Design)

The following is defined at the **dMPMS v1.1 spec level** but not yet implemented in the editor UI (beyond the legacy `people: [String]`):

#### 3.11.1 Identity registry (dMPP-level, not in sidecars)

dMPP will maintain an internal **identity registry** (e.g., in a separate JSON or within preferences), where each identity version is:

```jsonc
{
  "idid": "erin2",                  // unique identity-version ID
  "shortName": "Erin",
  "givenName": "Erin",
  "middleName": "Amanda",
  "surname": "Colburn",
  "suffix": null,
  "displayName": "Erin Amanda Colburn",

  "birthDate": "1989-05-13",        // YYYY-MM-DD where known
  "idDate": "2012-06-15",           // when this identity version started

  "isFavorite": true                // show in “favorites” column
}
```

- Multiple entries per person are supported (e.g., pre- and post-name change).
- Short names are not required to be globally unique, but:
  - The editor may warn on obvious collisions (same shortName + birthDate).
- The registry is not stored inside individual sidecars.

#### 3.11.2 `peopleInPhoto` (dMPMS v1.1)

Sidecars gain an optional `peopleInPhoto` array recording:

```jsonc
"peopleInPhoto": [
  {
    "idid": "erin2",
    "shortName": "Erin",
    "displayName": "Erin Amanda Colburn",
    "rowIndex": 1,
    "positionIndex": 2,
    "ageAtPhotoYears": 23.1
  }
]
```

Fields:

- `idid`
  - Optional but recommended link into the identity registry.
- `shortName`
  - Snapshot of the label used in this photo.
- `displayName`
  - Optional snapshot of the full name at the time of saving.
- `rowIndex`
  - 1 = front row, 2 = second row, etc.
- `positionIndex`
  - 1 = leftmost in that row, then 2, 3…
- `ageAtPhotoYears`
  - Computed from the photo’s date range and the identity’s birthDate.
  - Approximate when dates are fuzzy (decades / ranges).

#### 3.11.3 Relationship to `people: [String]`

- `people: [String]` remains for compatibility and human readability.
- For v1.1+ sidecars, it is defined as a **flattened display list**, typically:

```text
people = peopleInPhoto.sorted(by: rowIndex, positionIndex)
                      .map { $0.shortName }
```

The editor currently still uses only `people: [String]` at runtime; the `peopleInPhoto` and registry design simply define the future direction.

---

## 4. Technical Architecture

### 4.1 Key Swift Files & Responsibilities

- **`dMagy_Picture_PrepApp.swift`**
  - Application entry point.
  - Defines main window scene hosting `DMPPImageEditorView`.
  - Defines macOS **Settings** scene hosting `DMPPCropPreferencesView`.

- **`DMPPImageEditorView.swift`**
  - High-level editor UI.
  - Layout:
    - Top toolbar (folder picker + full path text).
    - Split view: `DMPPCropEditorPane` (left) + `DMPPMetadataFormPane` (right).
    - Bottom bar with Delete Crop, info text, and Save + navigation.
  - Manages:
    - Folder selection and scanning.
    - Image list and current index.
    - Sidecar URL computation and load/save calls.
  - Owns an optional `DMPPImageEditorViewModel`.

- **`DMPPCropEditorPane.swift`** (or nested type)
  - Left-hand crop pane.
  - Handles:
    - Crops segmented control.
    - “New Crop” menu with built-in + custom + Freeform + Manage Custom Presets.
    - Main `NSImage` display with `DMPPCropOverlayView` overlay.
    - Vertical crop controls (+ button, slider, – button).
  - Uses `@Environment(\.openSettings)` to open Settings from the menu.

- **`DMPPMetadataFormPane.swift`** (or nested type)
  - Right-hand metadata form:
    - File (sourceFile).
    - Title and Description (full-width text fields).
    - Date/Era group:
      - `dateTaken` text field.
      - Helper text explaining valid patterns.
      - Soft warnings for non-standard input.
      - Keeps `dateRange` in sync.
    - Tags & People:
      - Tags checkbox grid based on `availableTags` from preferences.
      - Special handling for unknown tags (“Other tags in this photo…”).
      - Link to Settings for tag management.
      - People text field (comma-separated; legacy v1 behavior).

- **`DMPPImageEditorViewModel.swift`**
  - Core logic for a single image:
    - `imageURL`, `nsImage`, `metadata`.
    - `selectedCropID` and crop list management.
  - Responsibilities:
    - Computing default crops using `DMPPUserPreferences`.
    - Adding built-in presets, custom presets, and Freeform crops.
    - Ensuring label/aspect combination uniqueness per image.
    - Updating crop rects, scaling, and maintaining invariants.
    - Logging crop events to `history` with throttling.
    - Providing tags/people helpers (`tagsText`, `updateTags`, `peopleText`, `updatePeople`).
  - Does **not yet** implement the identity registry or `peopleInPhoto`, which are still at the spec layer.

- **`DMPPCropOverlayView.swift`**
  - Draws:
    - The image-space mask (darkened outside area).
    - The crop border.
    - Headshot grid overlay for Headshot 8×10.
    - Freeform resize handle.
  - Handles gestures:
    - Dragging the crop.
    - Resizing the crop (fixed aspect vs freeform).
  - Calls back to the ViewModel via a rect-change closure.

- **`DMPPUserPreferences.swift`**
  - Encapsulates user-level settings, encoded to `UserDefaults`.
  - Includes:
    - `CropPresetID` enum.
    - `defaultCropPresets: [CropPresetID]`.
    - `customCropPresets: [CustomCropPreset]`.
    - `availableTags: [String]`.
    - `static mandatoryTagName: String` (e.g., `"Do Not Display"`).
    - `effectiveDefaultCropPresets` helper.
  - Enforces the presence of the mandatory tag on save.
  - Posts a `dmppPreferencesChanged` notification whenever preferences are saved so open editors can refresh tags/presets.

- **`DMPPCropPreferencesView.swift`**
  - Settings UI:
    - **Crops tab**:
      - Built-in presets section (checkboxes).
      - Custom presets table (label, Width:Height, default flag).
    - **Tags tab**:
      - Instructions.
      - Editable tag list.
      - Mandatory tag row (non-deletable, lock icon).
      - Add Tag button.
  - Observes `prefs` via `@State` and saves on change.

- **`Models/DmpmsCropsModels.swift`**
  - `RectNormalized` and `VirtualCrop` models.
  - Codable, Hashable.
  - Used by both ViewModel and dMPMS metadata.

- **`Models/DmpmsMetadata.swift`**
  - dMPMS v1.1 schema implementation:
    - `dmpmsVersion`, `dmpmsNotice`.
    - `sourceFile`, `title`, `description`.
    - `dateTaken`, `dateRange`.
    - `tags`, `people`.
    - `virtualCrops`.
    - `history`.
    - (Schema-level plan for `peopleInPhoto`, not yet active in the app.)
  - Custom decoding to:
    - Handle older sidecars without `dmpmsNotice` or `dateRange`.
    - Default new fields appropriately.

---

## 5. Known Limitations (as of CTX7)

- Crop overlays:
  - Still do not support rotation.
  - Freeform aspect is visually editable but cannot be numerically typed in yet.
- Dates:
  - Validation is soft; app does not block saving invalid formats.
  - `dateRange` relies on parsing `dateTaken` and is only as accurate as available metadata.
- Tags:
  - Tag list is global, not per-project or per-folder.
  - “Unknown tags” are read-only (displayed as text only, not checkboxes).
- People:
  - Editor still uses a simple text field and `people: [String]` only.
  - Identity registry and `peopleInPhoto` schema are not yet implemented in the runtime.
- No bulk operations:
  - No “batch skip existing sidecars” or batch-default-crop operations yet.
- No explicit “has sidecar / modified” status indicator in the UI.
- No history/undo for non-crop metadata edits.
- No dedicated “Preview only” mode beyond the existing editor view.

These remain intentional v1 constraints.

---

## 6. Roadmap (Short-Term)

### 6.1 High Priority

- options around editing into folders, chackbox: include subfolders
- show resolution when scaling
- Per-image metadata status (New / Existing / Modified).
- When clicking Add/Edit tags... in UI have settings go to the correct tab
- Auto-advance option after Save. - option to go to next image or next image without existing dmpms.json
- In Settings make some metadata optionally required or tested, for example if title still = file name give a warning before moving the next picture. This is to help people like me not miss a step.
- add Location Section
- Make portait resize center on face crop
- Better visual affordances for crop limits (snap-to-edges, safe zones, warning when hitting bounds).
- Additional preferences in `DMPPUserPreferences` for metadata defaults (e.g., date patterns, auto-tags from folder).
- First implementation pass of the **identity registry + `peopleInPhoto`**:
  - Two-column favorites/all-others checkbox UI.
  - Row/position capture for people in group photos.
  - Age-at-photo calculation using `dateRange` and birthDate.

### 6.2 Medium

- investigate option of voice entry for description
- add a button to open the current image in another  installed default  app on the computer for color correction, etc.
- Batch skip existing metadata / sidecars.
- Extend dMPMS `history[]` to include non-crop edits.
- Project-level or folder-level tag sets (in addition to the global list).

### 6.3 Longer-Term

- Deep dMPS integration (crop choice per display and per slideshow).
- Export tools (cropped previews, thumbnails, contact sheets).
- Rich keyboard shortcut workflow (“Editor Mode”).
- Swift Package for shared metadata models between dMPS and dMPP.
- Image quality checks (noise, sharpness detection) and visual flags.
- Visual overlay for people layout (e.g., labeled dots by row/position).

### 6.4 Post-v1 Review & Refactor Targets

- **Sidecar history coalescing**
  - Further reduce redundant `updateCropRect`/scale entries by:
    - Logging primarily at the end of interactions.
    - Optionally summarizing a sequence of changes into a single, more descriptive event.

- **Preset semantics hardening**
  - Replace string-based label checks with enums or stable IDs for presets.
  - Allow renaming/localization of preset labels without breaking existing images.

- **Separation of concerns**
  - Move folder navigation and sidecar I/O into a small controller/manager type:
    - `DMPPImageEditorView` focuses on UI.
    - Controller handles filesystem, sandbox, and error reporting.

- **Layout & Geometry simplification**
  - Revisit `GeometryReader` usage to:
    - Reduce nesting.
    - Improve behavior at extreme window sizes.
    - Make the layout easier to reason about.

- **Error & diagnostics polish**
  - Replace ad-hoc `print()` diagnostics with:
    - A small logging utility.
    - Optional UI feedback (e.g., non-modal banners) for save/load errors and sandbox issues.

---

## 7. Version Tracking

This document uses the version tag:

```text
dMPP-2025-12-07-CTX7
```

Previous revisions:

```text
dMPP-2025-12-04-CTX6
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
dMPP-2026-01-10-CTX8-peopleModel
dMPP-2026-02-18-CTX9-batchOps
dMPP-2026-03-02-CTX10-statusUI
```

---

## 8. Author Notes

This file serves as the authoritative record for:

- Architectural decisions
- Workflow definitions
- Schema changes (dMPMS evolution)
- Constraints encountered (sandboxing, metadata rules, etc.)
- Progress milestones

Keeping it up to date helps future development stay intentional rather than reactive, especially as dMPP, dMPS, and dMPMS evolve together.

---

## 9. Delta from dMPP-2025-12-04-CTX6

Changes introduced in **CTX7** relative to **CTX6**:

1. **dMPMS v1.1 Adoption**
   - Upgraded the spec reference from v1.0 to **v1.1**.
   - `DmpmsMetadata` now includes:
     - `dateRange` (derived from `dateTaken`).
     - Continued support for `dmpmsNotice` (human-facing sidecar warning).

2. **Date/Era Handling**
   - Clarified the accepted forms for `dateTaken`:
     - Exact dates (`YYYY-MM-DD`), year-month (`YYYY-MM`), year (`YYYY`), decades (`YYYYs`), and ranges (`YYYY-YYYY`).
   - Introduced `dateRange` semantics:
     - Computed canonical ranges for each valid pattern.
     - Left `nil` for invalid or freeform strings.
   - Added a soft warning message for non-standard entries (“Entered value does not match standard forms…”).

3. **Default Dates for Camera Images**
   - Documented behavior where new sidecars for digital photos attempt to:
     - Read the capture date from image metadata.
     - Initialize `dateTaken` (as `YYYY-MM-DD`) and `dateRange` accordingly.
   - For scanned/legacy images without reliable metadata, dates remain empty until user input.

4. **Tags as Checkbox Grid + Mandatory Tag**
   - Replaced the previous “comma-separated tags” UI with:
     - A two-column checkbox grid driven by `availableTags` from preferences.
     - Behaviour that keeps `metadata.tags` in sync with checkboxes.
   - Introduced the mandatory **“Do Not Display”** tag:
     - Always present in `availableTags`.
     - Non-deletable in the Tags Settings tab (lock icon).
     - Available as a normal checkbox in the editor so users can opt images out of slideshows.
   - Added handling for “unknown” tags:
     - Tags present in `metadata.tags` but not in `availableTags` are shown as a separate informational line.

5. **Tags Settings Tab**
   - Extended `DMPPCropPreferencesView` to a **tabbed** Settings UI with:
     - A **Crops** tab (existing content).
     - A **Tags** tab allowing:
       - Editing of `availableTags`.
       - Non-deletable mandatory tag row.
       - “Add Tag” button to append new tags.
   - Updated documentation to reflect this two-tab layout.

6. **Preferences Change Notification Hook-Up**
   - Clarified that:
     - `DMPPUserPreferences.save()` posts a `dmppPreferencesChanged` notification.
     - Editor views listen for this notification and refresh their:
       - `availableTags` list.
       - (Later: crop presets, identity registry, etc.)
   - Ensures newly added tags appear immediately in the current image without navigation.

7. **People & Identity Model (Spec-Level Design)**
   - Introduced `peopleInPhoto` as a new dMPMS v1.1 field (schema only):
     - Links to identity entries via `idid`.
     - Stores row/position, shortName, displayName, and age-at-photo.
   - Defined the **identity registry** concept for dMPP:
     - Identity-version records with `idid`, structured names, birthDate, idDate, and `isFavorite`.
   - Clarified that:
     - The editor currently still uses only `people: [String]` at runtime.
     - Identity registry and `peopleInPhoto` are planned for a future iteration and listed in the roadmap.

8. **Metadata Pane Layout Polish**
   - Documented:
     - Full-width Title and Description fields inside their group boxes.
     - Consistent padding across metadata sections.
     - Clearer Date/Era helper text and examples.

9. **Roadmap & Refactor Targets**
   - Updated roadmap to explicitly call out:
     - Implementation of identity registry + `peopleInPhoto`.
     - Use of `dateRange` and birthDate for age calculations.
   - Carried forward post-v1 refactor targets (history coalescing, preset semantics, layout simplification, error/diagnostics polish).

---

## End of dMPP-Context-v7.md
