# dMPP-Context-v11.md

**dMagy Picture Prep — Application Context & Architecture Overview**
**Version:** dMPP-2025-12-22-CTX11
**Supersedes:** dMPP-2025-12-18-CTX10

---

## 0. What changed since CTX10 (Reality Delta)

dMPP has moved from “PeopleV2 works” to “PeopleV2 works *and is survivable by normal humans*”.

Key changes:

* **Row context is now per-image**: `activeRowIndex` is owned by `DMPPImageEditorView` and re-synced on each image load.
* The “Unknown” workflow has been reframed as **“one-off person”**: label someone for this photo without creating a managed identity.
* **People UI streamlined**:

  * Summary lines per row now visually differentiate **managed identities** vs **one-offs**.
  * Snapshots + destructive actions moved under an **Advanced** `DisclosureGroup` (collapsed by default).
  * “Restore last snapshot” button removed (redundant with per-snapshot Restore actions).
* **Reset People confirmation UX updated**: now offers **Save** or **Skip** snapshot before clearing.
* **Save button enablement**: Save can be disabled unless metadata differs from loaded baseline (hash-based dirty tracking).
* Roadmap items moved closer to implementation:

  * Include Subfolders option (folder scan)
  * “New-only / skip existing metadata” browsing mode (wording still in flux)
  * Metadata status indicator (New / Existing / Modified)

---

## 1. Purpose of dMagy Picture Prep (dMPP)

**dMagy Picture Prep (dMPP)** is a macOS utility for preparing personal, family, and archival photographs for long-term use and rich presentation.

Its goals are to:

* Apply **structured, future-proof metadata** using the dMagy Photo Metadata Standard (**dMPMS**)
* Manage **people and identity data** independently of any single photo
* Create and persist **virtual crops** for multiple display targets
* Support a deliberate, folder-based review workflow
* Store all edits **non-destructively** in `.dmpms.json` metadata files

Where **dMPS shows pictures**, **dMPP prepares them**.

---

## 2. Relationship to dMPMS and dMPS

### 2.1 dMPP ↔ dMPMS

dMPP is the **reference implementation** of dMPMS.

* Current target: **dMPMS v1.1**
* Responsibilities:

  * Load `.dmpms.json`
  * Normalize and validate metadata
  * Write forward-compatible files
  * Enforce schema intent in practice

Implemented dMPMS concepts:

* `DmpmsMetadata`
* `DmpmsDateRange`
* `DmpmsIdentity`
* `DmpmsPersonInPhoto` (`peopleV2`)
* `DmpmsPeopleSnapshot`

Both structured and legacy fields are supported intentionally.

### 2.2 dMPP ↔ dMPS

* Communication occurs **only via `.dmpms.json`**
* No shared runtime, database, or dependency
* dMPP prepares; dMPS consumes

This keeps dMPS lightweight and dMPP flexible.

---

## 3. Core Workflow Model

### 3.1 Metadata-First Editing

* Images are never modified
* All edits live in `.dmpms.json`
* Deleting a `.dmpms.json` never affects the image

### 3.2 Folder-Based Review

* User selects a folder via `NSOpenPanel`
* Supported formats: `jpg, jpeg, png, heic, tif, tiff, webp`
* Images are reviewed sequentially
* Metadata saves:

  * Automatically on navigation (current behavior)
  * Automatically on folder change
  * Explicitly via **Save / ⌘S** (and Save can be disabled if no changes)

> Terminology note: internally this is “sidecar”, but UI/UX avoids that word.

---

## 4. Technical Architecture (CTX11)

### 4.1 Application Entry

#### `dMagy_Picture_PrepApp.swift`

* App entry point
* Defines:

  * Main editor window (`DMPPImageEditorView`)
  * Settings window (`DMPPCropPreferencesView`)
  * People Manager window
* Injects shared environment objects (Identity store, preferences access)

---

### 4.2 Editor Shell

#### `DMPPImageEditorView.swift`

UI layout:

* Top toolbar:

  * Folder picker (“Choose Folder…” / folder name)
  * Optional options near folder (planned: Include Subfolders, New-only browsing)
  * Full path display (planned: clickable to open in Finder)
* Split view:

  * Left: `DMPPCropEditorPane`
  * Right: `DMPPMetadataFormPane`
* Bottom bar:

  * Save
  * Previous / Next picture
  * Previous / Next crop
  * Info text

Owns core navigation and orchestration:

* Folder scanning → `imageURLs`
* `currentIndex`
* `.dmpms.json` URL computation
* Load / save orchestration
* Owns optional `DMPPImageEditorViewModel?`

**CTX11 state ownership change (important):**

* `activeRowIndex` is owned by **EditorView** (`@State private var activeRowIndex: Int`)
* Passed into `DMPPMetadataFormPane` as a **Binding**:

  * `@Binding var activeRowIndex: Int`
* On each image load, editor runs:

  * `syncActiveRowIndexFromCurrentPhoto()`
    which sets `activeRowIndex = maxRowIndex(for this photo)`

This fixes the bug where a row selection “leaked” to the next photo (especially visible when encountering an image with no `.dmpms.json`).

---

### 4.3 Crop Editing

#### `DMPPCropEditorPane.swift`

* Crop selection segmented control
* “New Crop” menu:

  * Built-in presets
  * Custom presets
  * Freeform
  * Manage presets shortcut
* `NSImage` display + `DMPPCropOverlayView`
* Vertical zoom/scale controls
* Delegates crop state and actions to ViewModel

#### `DMPPCropOverlayView.swift`

* Renders overlay elements and handles drag/resize
* Reports normalized rect updates via closures

---

### 4.4 Metadata Editing

#### `DMPPMetadataFormPane.swift`

Edits per-photo metadata:

* File (read-only)
* Title
* Description
* Date / Era:

  * `dateTaken` with soft validation
  * synchronizes `dateRange`
  * triggers age recomputation
* Tags:

  * checkbox grid from preferences
  * Settings shortcut

#### People section (CTX11)

**Data source:** `vm.metadata.peopleV2`

UI structure:

1. **Summary (always visible)**

   * “Check people in this photo left to right, row by row”
   * Lists people grouped by row (row label column + list column)
   * Visual differentiation:

     * **Managed identities** (has `identityID` and not unknown) are emphasized
     * **One-off people** are de-emphasized but readable

2. **Primary actions (always visible)**

   * **Add one-off person…**
   * **Start next row**
   * (Removed) “Current row: …” label to reduce clutter

3. **Advanced (collapsed by default)**

   * Reset People… (destructive)
   * Snapshots list and Capture snapshot…

---

### 4.5 ViewModel

#### `DMPPImageEditorViewModel.swift`

Owns:

* `imageURL`
* `nsImage`
* `metadata`

Responsibilities:

* Default crop computation
* Preset + freeform crop creation
* Crop rect normalization
* Throttled crop history logging
* `peopleV2` reconciliation utilities
* Age recomputation hooks (date changes, image changes)

---

### 4.6 Preferences & Settings

#### `DMPPUserPreferences.swift`

* Stored in `UserDefaults`
* Includes:

  * built-in + custom crop presets
  * global tag list
  * any enforcement rules
* Emits `dmppPreferencesChanged`

#### `DMPPCropPreferencesView.swift`

Tabs:

* **Crops**
* **Tags**

---

### 4.7 Models

* `DmpmsMetadata`
* `DmpmsDateRange`
* `RectNormalized`, `VirtualCrop`
* `DmpmsIdentity`
* `DmpmsPersonInPhoto`
* `DmpmsPeopleSnapshot`

Shared intentionally with dMPS.

---

### 4.8 Stores

#### `DMPPIdentityStore.swift`

* App-wide People / Identity registry
* Loads/saves JSON in Application Support
* Handles:

  * create/update/delete
  * favorites
  * shortName uniqueness
  * identity version selection by photo date

---

## 5. People & Identity System (CTX11)

### 5.1 Layers

1. **Person**
2. **Identity versions**
3. **Person-in-photo records (`peopleV2`)**

### 5.2 People Manager (authoritative)

A dedicated People Manager window remains the authoritative interface for managed people/identities.

### 5.3 People in Photos (`peopleV2`)

`peopleV2: [DmpmsPersonInPhoto]` is the internal truth.

Key fields:

* `identityID: String?`

  * present for managed identities
  * nil for one-offs
* `isUnknown: Bool`

  * currently used for “not from manager” (one-offs). (Name is legacy and mildly misleading; accepted for v1.1.)
* `rowIndex: Int` and `positionIndex: Int`

  * define row grouping and left-to-right ordering
* `roleHint: String?`

  * reserved for special semantics (e.g., legacy row marker concept)

### 5.4 One-off people

User-visible concept: **“one-off person”**
Implementation: `DmpmsPersonInPhoto(identityID: nil, isUnknown: true, ...)`

Behavior:

* Appears in this photo’s summary list
* Does not create or require an Identity Store record
* Can coexist with managed people in the same row

### 5.5 Per-image row context

`activeRowIndex` is **per image**, not global.

* Synced on load: `activeRowIndex = max(rowIndex in this photo)`
* “Start next row” increments it (even if current photo has no people yet)

---

## 6. Date & Age Handling (CTX11)

* Age-at-photo is computed from:

  * identity birth year
  * photo `dateRange` (derived from `dateTaken`)
* UI currently shows ages inline next to names where available.
* The “impossible age” warning is now questionable value:

  * With checkbox filtering to “alive during photo range”, the “*” case should be rare.
  * Decision pending: likely remove warning or move it into Advanced.

---

## 7. Save Semantics & “Dirty” Tracking (CTX11)

### 7.1 Save-time normalization (still required)

On save:

* Remove rows referencing identities deleted from Identity Store
* Reconcile remaining rows to the best identity for the photo date
* Refresh snapshots like `shortNameSnapshot`, `displayNameSnapshot`
* Keep legacy `people[]` regenerated from `peopleV2`

### 7.2 Save button enablement (dirty state)

Goal:

* Avoid encouraging “click Save every time”
* Only enable Save when something materially changed

Approach:

* Store a baseline hash at image load: `loadedMetadataHash`
* Compare against a current hash of `vm.metadata` (excluding derived fields like `ageAtPhoto`)

This allows:

* Save disabled when no changes
* Still keep ⌘S shortcut (recommended to keep; it becomes a no-op when disabled)

---

## 8. Snapshots (CTX11)

### 8.1 Capture Snapshot

Snapshots save the current `peopleV2` list into the photo’s metadata for later restore.

Updates in CTX11:

* Snapshot **note is optional** and should not default to date/time text.
* Snapshot list presentation goal:

  * Timestamp as the “title row” with Restore/Delete actions
  * Full people list displayed (not artificially truncated)
  * Note displayed as optional content (not forced)

### 8.2 Reset People UX

Reset should no longer force a snapshot.

Desired confirmation flow:

Text:
“This will clear the current People list for this photo (including one-offs and row markers). Do you want to save a snapshot for later?”

Buttons:

* **Save** (captures snapshot, then clears)
* **Skip** (clears without snapshot)

Note: macOS may auto-insert a Cancel option in some alert styles; treat it as acceptable behavior unless it compromises the flow.

---

## 9. Workflow Options (Emerging)

These are now first-class UX concepts, not just “future ideas”.

### 9.1 Include Subfolders (planned)

Add a checkbox next to the folder picker to include images in subfolders during scan.

### 9.2 “Show only unprepped pictures” browsing mode 

 -skip images that already have `.dmpms.json` present.


---

## 10. Known Limitations (still true unless implemented)


* Soft-only date validation
* Global tags only
* No batch operations
* No full metadata undo
* “sidecar” terminology avoided in UI

---

## 11. Roadmap (Reality-Checked)

### High Priority


### Medium

* Batch skip / batch actions

* Optional required fields
* External editor button
* Folder-level tag defaults

### Longer-Term

* Visual people layout overlays
* Export tools
* Keyboard-driven editor mode
* Shared Swift Package between dMPP and dMPS

### Post-v1 Refactors

* History coalescing
* Preset ID hardening
* I/O controller extraction
* GeometryReader simplification
* Unified logging & diagnostics

---

## 12. Version Tracking

```text
dMPP-2025-12-22-CTX11
```

If code and documentation diverge, fix the code.

---

**End of dMPP-Context-v11.md**

