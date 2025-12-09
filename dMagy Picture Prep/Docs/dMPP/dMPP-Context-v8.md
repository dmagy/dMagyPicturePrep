

````markdown
# dMPP-Context v8.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2025-12-09-CTX8  

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
  - Introduces a richer **people model** at the schema level:
    - `DmpmsIdentity` and `DmpmsPersonInPhoto` types (implemented in code).
    - Future-facing support for structured per-photo people records alongside the legacy `people: [String]`.

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

**As of dMPP-2025-12-09-CTX8**

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
  - Uses the full usable width inside its group box.
- **Description**
  - Multi-line text field (vertically expanding).
  - Uses the full usable width inside its group box.
  - Extra internal padding to make the description block feel like a proper “text area.”
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

- Title, Description, and Date/Era fields take the **full width** inside their group boxes.
- Group boxes use consistent internal padding so the right pane visually balances the crop editor.

---

### 3.3 Date Semantics & `dateRange` (dMPMS v1.1)

dMPMS v1.1 adds:

- `dateTaken: String`  
- `dateRange: DmpmsDateRange?` (new; structured earliest/latest dates)

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

`DmpmsDateRange` stores:

- `earliest: "YYYY-MM-DD"`  
- `latest:  "YYYY-MM-DD"`

On every change to `dateTaken`, dMPP attempts to parse and compute a canonical `dateRange`:

- `YYYY-MM-DD` → that exact day for both earliest/latest.  
- `YYYY-MM` → whole calendar month.  
- `YYYY` → whole calendar year.  
- `YYYYs` (decade) → `YYYY-01-01` through `YYYY+9-12-31`.  
- `YYYY-YYYY` → lower-year start to higher-year end (only if `start <= end`).

If the input is **invalid** (e.g., `1975-1960`):

- `dateTaken` is kept as typed.
- `dateRange` is left `nil`.
- A soft, non-blocking warning is shown in the UI.

This allows future tools (dMPP v2, dMPS v2) to use **dateRange** for better filtering and age calculations without forcing perfect precision.

#### 3.3.3 Default dates for camera images

For **new sidecars** created for digital photos:

- dMPP attempts to read the capture date from image metadata (EXIF/metadata).
- If a valid date is found, it initializes:
  - `dateTaken` as a `YYYY-MM-DD` string.
  - `dateRange` from that exact date.

For **scanned or legacy images** without reliable metadata:

- `dateTaken` starts empty.
- `dateRange` is `nil` until the user enters something.

---

### 3.4 Tags & People (Editor UI)

The previous “comma separated tags/people” approach for tags has been replaced with a more structured UI.

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
  - Displayed in the Tags Settings tab with a lock icon and dark-red styling.
  - Shows up as a normal checkbox in the editor so the user can choose whether a given image should be hidden in displays.

Unknown tags:

- If `metadata.tags` contains values not found in the current `availableTags`:
  - They are not rendered as checkboxes.
  - Instead, a small caption is shown, e.g.:  
    `Other tags in this photo: Halloween, NSFW`
  - This avoids silently dropping information from older sidecars or previous tag lists.

Quick link:

- A `“Add / Edit tags…”` link opens Settings and takes the user directly to the **Tags** tab so they can manage the master tag list.

#### 3.4.2 People (current editor behavior)

- In the main editor, people are still represented as a **single text field**:
  - A helper binds this to `metadata.people` via comma-separated names.
- This preserves current v1 behavior:
  - Simple, flexible, and sidecar-readable.
- The richer people system (identity registry + per-photo rows) is implemented at the **model/store level** (see 3.11) but has not yet replaced the simple text field in the main editor UI.

---

### 3.5 Virtual Crop System

Every image has one or more **virtual crops**, each represented as:

```swift
RectNormalized(x: 0–1, y: 0–1, width: 0–1, height: 0–1)
````

in image space, stored in `VirtualCrop` records inside `DmpmsMetadata.virtualCrops`.

For images **without an existing sidecar**, the `DMPPImageEditorViewModel`:

* Loads the actual image (`NSImage`).
* Loads **user preferences** from `DMPPUserPreferences`.
* Uses `effectiveDefaultCropPresets` to decide which crops to auto-create.
* For each configured preset, creates a centered, aspect-correct crop based on the image’s actual size.

Built-in presets available under the **“New Crop”** menu (and for defaults) are grouped by use case:

#### Screen

* **Original (full image)** — aspect inferred from actual pixel dimensions.
* **Landscape 16:9**
* **Portrait 9:16**
* **Landscape 4:3**

#### Print & Frames

* **Portrait 8×10** (4:5)
* **Headshot 8×10** (4:5, with special guides)
* **Landscape 4×6** (3:2)

#### Creative & Custom

* **Square 1:1**
* **Freeform** (no fixed aspect; per-image)
* **Custom presets defined in Settings** (label + W:H, optional “default for new images”)
* **Manage Custom Presets…** — opens Settings to the Crops tab.

Additional behavior:

* Each crop has a human-readable label and stored aspect description.
* Crop IDs are unique per image.
* The **first crop** is auto-selected when an image loads.
* For a given image:

  * Presets that have already been created (by label + aspect) are **greyed out/disabled** in the New Crop menu.
  * This applies to both built-in and custom presets.
* **Freeform** crops use `aspectWidth = 0`, `aspectHeight = 0` in dMPMS to indicate “no fixed aspect”.

Users can:

* Add any of the preset crops.
* Create **Freeform** crops.
* Add crops from **custom presets** defined in Settings.
* Duplicate the current crop.
* Delete the current crop.
* Switch between crops via a **segmented control** labeled **“Crops”** above the preview.

The old thumbnail strip remains removed; the main image + overlay is the primary editor.

---

### 3.6 Interactive Crop Editing

Crop overlays are **interactive**:

* The active crop is drawn as a dashed rectangle over the scaled image.
* Everything **outside** the crop is tinted with a **black overlay at ~0.75 opacity**, so the crop area “pops” visually.
* Users can:

  * **Drag the crop** within the image area (constrained to stay fully inside).
  * **Resize the crop** using the vertical **“Crop”** control column:

    * `+` button → increases crop size (shows more of the image).
    * Tall vertical slider → continuous size control.
    * `–` button → decreases crop size (zooms in).

Aspect behavior:

* For **fixed-aspect crops**, resizing via slider/buttons preserves the aspect ratio.
* For **Freeform crops**:

  * A bottom-right square handle lets users change width/height independently.
  * Slider/buttons change scale but preserve the *current* freeform aspect (no snapping back to square).

The ViewModel:

* Converts between pixel-space rectangles and normalized rectangles.
* Ensures crop stays in bounds and dimensions remain positive.
* Records crop changes into `history` with **throttling/coalescing** to avoid floods of identical events from continuous gestures.

---

### 3.7 Headshot Preset & Guides

For consistent portrait work (e.g., Heritage site headshots), dMPP includes a dedicated **Headshot 8×10** preset:

* Uses **4:5** aspect ratio (same as Portrait 8×10).
* Labeled **“Headshot 8×10”** so the UI can attach special guides.
* Starts as a centered 4:5 crop that can be moved and resized.

When a **Headshot 8×10** crop is active:

* A dashed **crosshair overlay** appears inside the crop.
* The overlay implements an 8×10-inspired grid:

  * Vertical lines at 2/8 and 6/8 of crop width.
  * Horizontal lines at 1/10 and 7/10 of crop height.
* Guides move and scale with the crop.

These guides are visual only; they do not change the stored crop rect.

---

### 3.8 dMPMS Sidecar Read/Write

For each image, dMPP reads/writes:

```text
<filename>.<extension>.dmpms.json
```

On **Load**:

* If sidecar exists → decode and bind:

  * `sourceFile` is forced to match the current image filename.
  * `dmpmsNotice` is present or defaulted.
* If missing → `makeDefaultMetadata(for:)` creates default metadata:

  * `dmpmsVersion` = `"1.1"`.
  * `dmpmsNotice` = default human-readable warning.
  * `sourceFile` = filename with extension.
  * `title` = filename without extension.
  * `dateTaken` and `dateRange` initialized from camera metadata if available.
  * `virtualCrops` starts empty and is filled by the ViewModel once the image is loaded.

On **Save** (Next/Previous/folder change or explicit **Save**):

* Writes JSON with `.prettyPrinted` formatting (no key sorting).
* Uses atomic replacement.
* Includes:

  * Metadata fields (title, description, dateTaken, dateRange, tags, people, and upcoming peopleV2 fields).
  * `virtualCrops`.
  * `history` for crop actions.
* Sidecars include a **human-facing notice**:

  ```jsonc
  "dmpmsNotice": "Created by dMagy Picture Prep. Stores metadata and crop settings for this photo. Deleting it erases edits (not the original image)."
  ```

App Sandbox:

* Sidecar reading and writing is verified with App Sandbox enabled.
* Writes are allowed only to user-selected folders and non-TCC-protected locations.

---

### 3.9 dMPMS History Tracking (Crop Operations)

`DmpmsMetadata.history` is populated for crop-related actions via `HistoryEvent` entries that record:

* `action` (e.g., `"createCrop"`, `"duplicateCrop"`, `"deleteCrop"`, `"updateCropRect"`, `"scaleCrop"`, `"sliderScaleCrop"`)
* ISO-8601 `timestamp`
* Optional `oldName` / `newName`
* `cropID` linking the event to a specific `VirtualCrop`

To avoid excessively noisy history:

* Continuous operations (dragging, slider scrubbing) are **coalesced** so that a gesture does not produce dozens of identical events.

Non-crop edits (title, description, tags, people, dates) are still not logged in `history` and are tracked only by the sidecar’s final state.

---

### 3.10 User Preferences & Settings (Crops & Tags)

dMPP includes a standard macOS **Settings** window with a tabbed view for **Crops** and **Tags**, driven by `DMPPUserPreferences`.

#### 3.10.1 Crops tab

* **Built-in presets section**

  * Checkboxes for:

    * Original (full image)
    * Landscape 16:9
    * Portrait 8×10
    * Headshot 8×10
    * Landscape 4×6
    * Square 1:1
  * These map to `defaultCropPresets`.

* **Custom presets section**

  * Each row corresponds to a `CustomCropPreset`:

    * Label
    * Width : Height (integer fields)
    * “Default” checkbox (include for new images).
  * Add Preset button → appends a new preset with default values.
  * Trash button → deletes that preset.

* When preferences change, they are immediately encoded, saved, and a
  `dmppPreferencesChanged` notification is posted so open editors can react if needed.

#### 3.10.2 Tags tab

* **Header** explains that tags here become the checkbox list in the editor.

* For each `availableTags` entry:

  * If the tag equals the mandatory `DMPPUserPreferences.mandatoryTagName` (currently `"Do Not Display"`):

    * It is rendered as a simple text row with a small **lock** icon on the right.
    * It cannot be edited or deleted.
  * Otherwise:

    * It is editable via a `TextField`.
    * A trash button allows deletion.

* “Add Tag” button:

  * Appends `"New Tag"` to `availableTags`.

Mandatory behavior:

* On save, `DMPPUserPreferences` ensures the mandatory tag exists in `availableTags`.
* The editor ensures it can always present that tag as a checkbox.

Notification:

* As with crop preferences, changes to tags fire the same `dmppPreferencesChanged` notification.
* Open editor views listen and refresh their local `availableTags` list so newly created tags appear **immediately** in the current image.

---

### 3.11 People & Identity Model (Models + Store, UI TBD)

The richer people model is now **implemented in code** but not yet fully surfaced in the editor UI.

#### 3.11.1 Identity records (`DmpmsIdentity`)

Defined in `DmpmsPeopleModels.swift` as:

* Stable identity-version record with fields such as:

  * `id: String` — unique identity ID (e.g., UUID or human-readable like `"erin1"`).
  * `shortName: String` — UI label; intended to be unique.
  * `givenName: String`
  * `middleName: String?`
  * `surname: String`
  * `birthDate: String?` — uses the same date grammar as `dateTaken` (full date recommended).
  * `idDate: String` — when this identity version became valid (e.g., marriage).
  * `idReason: String` — explanation such as “birth”, “marriage”, “divorce”.
  * `isFavorite: Bool` — drives “favorites” column in future UI.
  * `notes: String?` — free-form notes.
  * `isUnknownPlaceholder: Bool` — true for identities used to represent “Unknown person (left of Dan)” in group photos.

* Computed `fullName` helper builds a display name from the structured name parts.

Multiple identities can represent the same person over time (e.g., pre- and post-marriage surnames).

#### 3.11.2 Per-photo people (`DmpmsPersonInPhoto`)

Also defined in `DmpmsPeopleModels.swift` as a normalized “this person in this photo” record, with fields such as:

* `id: String` — unique per-photo row ID.
* `identityID: String?` — references a `DmpmsIdentity.id` when known; `nil` for pure unknown placeholders.
* `isUnknown: Bool` — marks rows that exist only to preserve left-to-right layout where a person isn’t identified.
* `shortNameSnapshot: String` — label as it appears in this photo.
* `displayNameSnapshot: String` — human-facing snapshot (e.g., full name at time of photo).
* `ageAtPhoto: String?` — e.g., `"3"`, `"42"`, `"late 30s"` (computed later from `birthDate` and `dateRange`).
* `rowIndex: Int` — 0 = front row, 1 = second row, etc.
* `rowName: String?` — optional label (“front”, “second”, “third”).
* `positionIndex: Int` — 0 = leftmost in that row, then 1, 2, …
* `roleHint: String?` — e.g., “bride”, “groom”, “birthday child”.

These are designed to live in `DmpmsMetadata.peopleV2` / `peopleInPhoto` in future sidecars while legacy `people: [String]` remains as a flattened summary.

#### 3.11.3 Identity store (`DMPPIdentityStore`)

`DMPPIdentityStore` is an `@Observable` singleton responsible for:

* Persisting all identities to a JSON file at:
  `~/Library/Application Support/dMagyPicturePrep/identities.json`
* Loading that file at app startup and providing:

  * `identities: [DmpmsIdentity]` as the in-memory source of truth.
  * Sorted views for UI:

    * `identitiesSortedForUI` — favorites first, then others, both alphabetized by `shortName`.
    * `favoriteIdentities` and `nonFavoriteIdentities`.
  * Query helpers:

    * `identity(withID:)`
    * `identities(withShortName:)`
* Mutation helpers:

  * `upsert(_:)` — insert or replace by ID, then save.
  * `delete(identityID:)` — remove by ID, then save.
  * `isShortNameInUse(_:excludingID:)` — helps future UI enforce or at least warn about shortName uniqueness.

The store is **application-wide** and not tied to any single editor view. It is intended to be used by:

* Settings / People Manager UI.
* Editor people-checkbox UI (when implemented).
* Any future tooling that needs to look up identities.

#### 3.11.4 Current People tab behavior (Settings)

A basic **People** tab is now wired into Settings with a simple table editor for identities. At this stage:

* It is intended as a **bootstrap** interface while the full “People Manager” design is fleshed out.
* Longer-term, this tab will likely become:

  * A summary + “Open People Manager…” entry rather than a full editor.
  * The main editing experience will move to a dedicated window with:

    * Search/filter
    * Sorting
    * Bulk operations
    * Import/export
    * Rich editing of identity fields (incl. `idDate`, `idReason`, `isFavorite`, `isUnknownPlaceholder`).

For now, the architecture (models + store) is in place; the UI will catch up iteratively.

---

## 4. Technical Architecture

### 4.1 Key Swift Files & Responsibilities

* **`dMagy_Picture_PrepApp.swift`**

  * Application entry point.
  * Defines main window scene hosting `DMPPImageEditorView`.
  * Defines macOS **Settings** scene hosting `DMPPCropPreferencesView`.

* **`DMPPImageEditorView.swift`**

  * High-level editor UI.
  * Layout:

    * Top toolbar (folder picker + full path text).
    * Split view: `DMPPCropEditorPane` (left) + `DMPPMetadataFormPane` (right).
    * Bottom bar with Delete Crop, info text, and Save + navigation.
  * Manages:

    * Folder selection and scanning.
    * Image list and current index.
    * Sidecar URL computation and load/save calls.
  * Owns an optional `DMPPImageEditorViewModel`.

* **`DMPPCropEditorPane.swift`** (or nested type)

  * Left-hand crop pane.
  * Handles:

    * Crops segmented control.
    * “New Crop” menu with built-in + custom + Freeform + Manage Custom Presets.
    * Main `NSImage` display with `DMPPCropOverlayView` overlay.
    * Vertical crop controls (+ button, slider, – button).
  * Uses `@Environment(\.openSettings)` to open Settings from the menu.

* **`DMPPMetadataFormPane.swift`** (or nested type)

  * Right-hand metadata form:

    * File (sourceFile).
    * Title and Description (full-width text fields).
    * Date/Era group:

      * `dateTaken` text field.
      * Helper text explaining valid patterns.
      * Soft warnings for non-standard input.
      * Keeps `dateRange` in sync.
    * Tags & People:

      * Tags checkbox grid based on `availableTags` from preferences.
      * Special handling for unknown tags (“Other tags in this photo…”).
      * Link to Settings for tag management.
      * People text field (comma-separated; current v1 behavior).

* **`DMPPImageEditorViewModel.swift`**

  * Core logic for a single image:

    * `imageURL`, `nsImage`, `metadata`.
    * `selectedCropID` and crop list management.
  * Responsibilities:

    * Computing default crops using `DMPPUserPreferences`.
    * Adding built-in presets, custom presets, and Freeform crops.
    * Ensuring label/aspect combination uniqueness per image.
    * Updating crop rects, scaling, and maintaining invariants.
    * Logging crop events to `history` with throttling.
    * Providing tags/people helpers (`tagsText`, `updateTags`, `peopleText`, `updatePeople`).
  * Does not yet fully integrate `DmpmsPersonInPhoto` in the main editor UI; that’s part of the roadmap.

* **`DMPPCropOverlayView.swift`**

  * Draws:

    * The image-space mask (darkened outside area).
    * The crop border.
    * Headshot grid overlay for Headshot 8×10.
    * Freeform resize handle.
  * Handles gestures:

    * Dragging the crop.
    * Resizing the crop (fixed aspect vs freeform).
  * Calls back to the ViewModel via a rect-change closure.

* **`DMPPUserPreferences.swift`**

  * Encapsulates user-level settings, encoded to `UserDefaults`.
  * Includes:

    * `CropPresetID` enum.
    * `defaultCropPresets: [CropPresetID]`.
    * `customCropPresets: [CustomCropPreset]`.
    * `availableTags: [String]`.
    * `static mandatoryTagName: String` (e.g., `"Do Not Display"`).
    * `effectiveDefaultCropPresets` helper.
  * Enforces the presence of the mandatory tag on save.
  * Posts a `dmppPreferencesChanged` notification whenever preferences are saved so open editors can refresh tags/presets.

* **`DMPPCropPreferencesView.swift`**

  * Settings UI:

    * **Crops tab**:

      * Built-in presets section (checkboxes).
      * Custom presets table (label, Width:Height, default flag).
    * **Tags tab**:

      * Instructions.
      * Editable tag list.
      * Mandatory tag row (non-deletable, lock icon).
      * Add Tag button.
    * (People tab currently experimental; likely to evolve into a summary + “Open People Manager” pattern.)

* **`Models/DmpmsCropsModels.swift`**

  * `RectNormalized` and `VirtualCrop` models.
  * Codable, Hashable.
  * Used by both ViewModel and dMPMS metadata.

* **`Models/DmpmsMetadata.swift`**

  * dMPMS v1.1 schema implementation:

    * `dmpmsVersion`, `dmpmsNotice`.
    * `sourceFile`, `title`, `description`.
    * `dateTaken`, `dateRange`.
    * `tags`, `people`.
    * `virtualCrops`.
    * `history`.
    * (Future: `peopleV2` / `peopleInPhoto` field using `DmpmsPersonInPhoto`.)

* **`Models/DmpmsPeopleModels.swift`**

  * Identity and per-photo people models:

    * `DmpmsIdentity` (identity over time).
    * `DmpmsPersonInPhoto` (this person, in this specific photo).
  * Codable & Hashable; designed to be shared between dMPP and dMPS.

* **`Stores/DMPPIdentityStore.swift`**

  * App-wide identity registry store:

    * Loads/saves `DmpmsIdentity` list to JSON in Application Support.
    * Provides sorted favorites/non-favorites for UI.
    * Handles upsert, delete, and simple uniqueness checks for `shortName`.

---

## 5. Known Limitations (as of CTX8)

* Crop overlays:

  * Still do not support rotation.
  * Freeform aspect is visually editable but cannot be numerically typed in yet.
* Dates:

  * Validation is soft; app does not block saving invalid formats.
  * `dateRange` relies on parsing `dateTaken` and is only as accurate as available metadata.
* Tags:

  * Tag list is global, not per-project or per-folder.
  * “Unknown tags” are read-only (displayed as text only, not checkboxes).
* People:

  * Editor still uses a simple text field and `people: [String]` only.
  * Identity registry and `DmpmsPersonInPhoto` are implemented but not yet surfaced as the main people UI.
  * No row/position capture UI yet; no age-at-photo calculation in the editor.
* No bulk operations:

  * No “batch skip existing sidecars” or batch-default-crop operations yet.
* No explicit “has sidecar / modified” status indicator in the UI.
* No history/undo for non-crop metadata edits.
* No dedicated “Preview only” mode beyond the existing editor view.

These remain intentional v1 constraints.

---

## 6. Roadmap (Short-Term)

### 6.1 High Priority

* Options around editing into folders (e.g., checkbox: include subfolders).
* Show resolution / size feedback when scaling crops.
* Per-image metadata status (New / Existing / Modified).
* When clicking **Add/Edit tags…** in the editor, ensure Settings opens directly to the Tags tab.
* Auto-advance option after Save:

  * Option to go to next image.
  * Option to go to next image without an existing `.dmpms.json`.
* In Settings, make some metadata optionally required or flagged:

  * e.g., if title still equals filename, warn before moving to next picture.
* Add **Location** section.
* Make portrait resize optionally center around a detected or user-specified face crop.
* Better visual affordances for crop limits (snap-to-edges, safe zones, warning when hitting bounds).
* Additional preferences in `DMPPUserPreferences` for metadata defaults (e.g., date patterns, auto-tags from folder).
* First implementation pass of the **identity registry + peopleV2 UI**:

  * Two-column favorites / all-others checkbox layout.
  * Row/position capture for people in group photos.
  * Age-at-photo calculation using `dateRange` and `birthDate`.
  * Support for “Unknown person” placeholders in the row layout.

### 6.2 Medium

* Investigate option of voice entry for description.
* Add a button to open the current image in another installed default app (for color correction, etc.).
* Batch skip existing metadata / sidecars.
* Extend dMPMS `history[]` to include non-crop edits.
* Project-level or folder-level tag sets (in addition to the global list).

### 6.3 Longer-Term

* Deep dMPS integration (crop choice per display and per slideshow).
* Export tools (cropped previews, thumbnails, contact sheets).
* Rich keyboard shortcut workflow (“Editor Mode”).
* Swift Package for shared metadata models between dMPS and dMPP.
* Image quality checks (noise, sharpness detection) and visual flags.
* Visual overlay for people layout (e.g., labeled dots by row/position, unknown placeholders clearly indicated).

### 6.4 Post-v1 Review & Refactor Targets

* **Sidecar history coalescing**

  * Further reduce redundant `updateCropRect`/scale entries by:

    * Logging primarily at the end of interactions.
    * Optionally summarizing a sequence of changes into a single, more descriptive event.

* **Preset semantics hardening**

  * Replace string-based label checks with enums or stable IDs for presets.
  * Allow renaming/localization of preset labels without breaking existing images.

* **Separation of concerns**

  * Move folder navigation and sidecar I/O into a small controller/manager type:

    * `DMPPImageEditorView` focuses on UI.
    * Controller handles filesystem, sandbox, and error reporting.

* **Layout & Geometry simplification**

  * Revisit `GeometryReader` usage to:

    * Reduce nesting.
    * Improve behavior at extreme window sizes.
    * Make the layout easier to reason about.

* **Error & diagnostics polish**

  * Replace ad-hoc `print()` diagnostics with:

    * A small logging utility.
    * Optional UI feedback (e.g., non-modal banners) for save/load errors and sandbox issues.

---

## 7. Version Tracking

This document uses the version tag:

```text
dMPP-2025-12-09-CTX8
```

Previous revisions:

```text
dMPP-2025-12-07-CTX7
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
dMPP-2026-01-10-CTX9-peopleUI
dMPP-2026-02-18-CTX10-batchOps
dMPP-2026-03-02-CTX11-statusUI
```

---

## 8. Author Notes

This file serves as the authoritative record for:

* Architectural decisions
* Workflow definitions
* Schema changes (dMPMS evolution)
* Constraints encountered (sandboxing, metadata rules, etc.)
* Progress milestones

Keeping it up to date helps future development stay intentional rather than reactive, especially as dMPP, dMPS, and dMPMS evolve together.

---

## 9. Delta from dMPP-2025-12-07-CTX7

Changes introduced in **CTX8** relative to **CTX7**:

1. **Identity & People Models Implemented**

   * Added `DmpmsIdentity` and `DmpmsPersonInPhoto` models in `DmpmsPeopleModels.swift`.
   * Introduced structured fields for:

     * Full name components (given/middle/surname).
     * `birthDate`, `idDate`, and `idReason`.
     * Favorites and notes.
     * Row/position layout and “unknown person” placeholders for group photos.

2. **Identity Store (`DMPPIdentityStore`)**

   * Implemented an `@Observable` singleton to:

     * Load/save identity records to a JSON file in Application Support.
     * Provide favorites-first, alphabetized identity lists for UI.
     * Handle upsert/delete operations and shortName usage checks.
   * Positioned as the single source of truth for identity data across dMPP.

3. **People Model Direction Clarified**

   * Documented that:

     * The legacy `people: [String]` remains in `DmpmsMetadata` for now.
     * A richer `peopleV2` / `peopleInPhoto` field is planned to store `DmpmsPersonInPhoto` rows.
   * Clarified the role of `isUnknownPlaceholder` for representing unnamed individuals in group photos while preserving layout.

4. **Context Doc Alignment with Code**

   * Updated sections 2, 3.4, 3.8, 3.11, and 4 to reflect:

     * Adoption of dMPMS v1.1 with `dateRange`.
     * Implementation status of the identity models and store.
     * Current limitations of the UI relative to the underlying models.
   * Preserved v7 behavior descriptions for crops, tags, and date handling, with minor clarifications.

5. **Roadmap Updates**

   * Made People Manager / identity-based UI a clearly stated high-priority roadmap item:

     * Two-column favorites/all-others layout.
     * Row/position capture.
     * Age-at-photo calculation.
     * “Unknown person” support.
   * Retained and slightly clarified existing roadmap items for batch operations, status UI, and refactors.

---

## End of dMPP-Context-v8.md

