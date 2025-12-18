# dMPP-Context-v10.md
**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2025-12-18-CTX10  

---

## 1. Purpose of dMagy Picture Prep (dMPP)

**dMagy Picture Prep (dMPP)** is a macOS utility for preparing personal, family, and archival photographs for long-term use and rich presentation.

Its goals are to:

- Apply **structured, future-proof metadata** using the dMagy Photo Metadata Standard (**dMPMS**)
- Manage **people and identity data** independently of any single photo
- Create and persist **virtual crops** for multiple display targets
- Support a deliberate, folder-based review workflow
- Store all edits **non-destructively** in sidecar metadata files

Where **dMPS shows pictures**, **dMPP prepares them**.

---

## 2. Relationship to dMPMS and dMPS

### 2.1 dMPP ↔ dMPMS

dMPP is the **reference implementation** of dMPMS.

- Current target: **dMPMS v1.1**
- Responsibilities:
  - Load `.dmpms.json` sidecars
  - Normalize and validate metadata
  - Write forward-compatible sidecars
  - Enforce schema intent in practice

Implemented dMPMS concepts:

- `DmpmsMetadata`
- `DmpmsDateRange`
- `DmpmsIdentity`
- `DmpmsPersonInPhoto` (peopleV2)

Both structured and legacy fields are supported intentionally.

### 2.2 dMPP ↔ dMPS

- Communication occurs **only via sidecars**
- No shared runtime, database, or dependency
- dMPP prepares; dMPS consumes

This keeps dMPS lightweight and dMPP flexible.

---

## 3. Core Workflow Model

### 3.1 Sidecar-First Editing

- Images are never modified
- All edits live in `.dmpms.json`
- Sidecars are created, cleaned, or updated automatically
- Deleting a sidecar never affects the image

### 3.2 Folder-Based Review

- User selects a folder via `NSOpenPanel`
- Supported formats: `jpg, jpeg, png, heic, tif, tiff, webp`
- Images are reviewed sequentially
- Metadata saves:
  - Automatically on navigation
  - Automatically on folder change
  - Explicitly via **Save / ⌘S**

---

## 4. Technical Architecture (CTX10)

This section describes the current, concrete Swift architecture of dMPP as implemented today.

### 4.1 Application Entry

#### `dMagy_Picture_PrepApp.swift`

- App entry point
- Defines:
  - Main editor window (`DMPPImageEditorView`)
  - Settings window (`DMPPCropPreferencesView`)
- Injects shared environment objects (People / Identity store)

---

### 4.2 Editor Shell

#### `DMPPImageEditorView.swift`

- Top toolbar:
  - Folder picker
  - Full path display
- Split view:
  - Left: `DMPPCropEditorPane`
  - Right: `DMPPMetadataFormPane`
- Bottom bar:
  - Save
  - Previous / Next
  - Status text
- Responsibilities:
  - Folder scanning
  - Image list + index
  - Sidecar URL computation
  - Load / save orchestration
- Owns optional `DMPPImageEditorViewModel`

---

### 4.3 Crop Editing

#### `DMPPCropEditorPane.swift`

- Crop selection segmented control
- “New Crop” menu:
  - Built-in presets
  - Custom presets
  - Freeform
  - Manage presets shortcut
- `NSImage` display + `DMPPCropOverlayView`
- Vertical scale controls
- Delegates all state to ViewModel

#### `DMPPCropOverlayView.swift`

- Renders:
  - Outside mask
  - Crop border
  - Headshot grid
  - Freeform resize handle
- Handles drag + resize gestures
- Reports rect changes via closures

---

### 4.4 Metadata Editing

#### `DMPPMetadataFormPane.swift`

- File (read-only)
- Title
- Description
- Date / Era:
  - `dateTaken`
  - Helper text
  - Soft warnings
  - `dateRange` synchronization
- Tags:
  - Checkbox grid from preferences
  - Read-only unknown tags
  - Settings shortcut
- People (CTX10):
  - Checklist from `peopleV2`
  - Deduplicated by person
  - `shortName` primary label
  - Birth year appended only for disambiguation

---

### 4.5 ViewModel

#### `DMPPImageEditorViewModel.swift`

Owns:

- `imageURL`
- `nsImage`
- `metadata`

Responsibilities:

- Default crop computation
- Preset + Freeform crop creation
- Crop rect normalization
- Throttled crop history logging
- Save-time normalization:
  - Tag cleanup
  - People reconciliation

**CTX10:**

- `peopleV2` is authoritative
- Legacy `people: [String]` regenerated on save

---

### 4.6 Preferences & Settings

#### `DMPPUserPreferences.swift`

- Stored in `UserDefaults`
- Includes:
  - Default crop presets
  - Custom presets
  - Global tag list
  - Mandatory tag enforcement
- Emits `dmppPreferencesChanged` notifications

#### `DMPPCropPreferencesView.swift`

Tabs:

- **Crops**
- **Tags**
- **People**
  - Summary
  - “Open People Manager”

---

### 4.7 Models

- `DmpmsMetadata`
- `DmpmsDateRange`
- `RectNormalized`, `VirtualCrop`
- `DmpmsIdentity`
- `DmpmsPersonInPhoto`

Shared intentionally with dMPS.

---

### 4.8 Stores

#### `DMPPIdentityStore.swift`

- App-wide People / Identity registry
- Loads/saves JSON in Application Support
- Handles:
  - Upsert
  - Delete
  - Favorites
  - `shortName` uniqueness
- **Single source of truth** for people data

---

## 5. People & Identity System (CTX10)

### 5.1 Layers

1. **Person**
2. **Identity versions**
3. **Person-in-photo records**

### 5.2 People Manager (Primary Interface)

A dedicated **People Manager window** is the authoritative interface for managing people and identities.

### 5.3 Person-Level Fields

Shared across identities:

- `shortName`
- `preferredName`
- `aliases[]`
- `birthDate`
- `favorite`
- `notes`

Edited once in People Manager and kept in sync across identities.

### 5.4 Identity-Level Fields

Per `DmpmsIdentity`:

- `givenName`
- `middleName`
- `surname`
- `idDate`
- `idReason`

### 5.5 People in Photos (peopleV2)

Within photo metadata, people are represented using:

- `peopleV2: [DmpmsPersonInPhoto]`

This is now the primary internal representation.

Legacy `people: [String]` is treated as a derived snapshot kept in sync from `peopleV2` during save.

### 5.6 Save-Time Reconciliation

On save:

- Invalid/deleted identity references are removed
- Remaining people are reconciled to the best identity for the photo’s date
- Legacy `people[]` regenerated
- Reloading after identity deletion yields cleaned metadata (no resurrection)

---

## 6. Date & Age Handling

- Age-at-photo = `birthDate` (person) vs `dateRange.earliest` (photo)
- Hooks exist to recompute ages when photo date/era changes
- Final UI polish is still in progress

---

## 7. Known Limitations (CTX10)

- No crop rotation
- Freeform aspect not numerically editable
- Soft-only date validation
- Global tags only
- Age display not finalized
- No batch ops
- No metadata undo
- No explicit modified indicator

Intentional v1 constraints.

---

## 8. Roadmap (Reality-Checked)

### High Priority
- Finalize age-at-photo UI
- Consolidate People logic
- People search (aliases, preferred names, age)
- Metadata status (New / Existing / Modified)
- Auto-advance options
- Location metadata

### Medium
- Batch skip sidecars
- Metadata history expansion
- Optional required fields
- External editor button
- Folder-level tag defaults

### Longer-Term
- Visual people layout overlays
- Export tools
- Keyboard-driven editor mode
- Shared Swift Package
- Image quality heuristics

### Post-v1 Refactors
- History coalescing
- Preset ID hardening
- I/O controller extraction
- GeometryReader simplification
- Unified logging & diagnostics

---

## 9. Version Tracking

```text
dMPP-2025-12-18-CTX10
```

Supersedes all prior CTX documents.

---

## 10. Author Notes

This document is the authoritative behavioral contract for dMPP.  
If code and documentation diverge, fix the code.

---

## Appendix A — Architecture & Data Flow (One-Page Mental Model)

Think of dMPP as four concentric layers:

### 1) UI Layer (SwiftUI Views)
- `DMPPImageEditorView`
- `DMPPCropEditorPane`
- `DMPPMetadataFormPane`
- Settings views

Role: user interaction only. Minimal business rules.

### 2) ViewModel Layer
- `DMPPImageEditorViewModel`

Role: per-image state, crop logic, save-time normalization, UI bindings.

### 3) Domain & Stores
- `DMPPIdentityStore`
- People Manager logic
- `DMPPUserPreferences`

Role: long-lived truth for people, identities, and preferences.

### 4) Persistence Boundary
- `.dmpms.json` sidecars
- Application Support identity store
- UserDefaults preferences

Role: durable state only.

### Key Data Flows

**Open Image**
```
Folder → Image URL
      → Sidecar Load
      → Metadata → ViewModel → UI
```

**Edit People**
```
People Manager → Identity Store
               → Editor references by ID
```

**Save Image**
```
UI → ViewModel
   → Normalize (tags, people, identities)
   → Write sidecar
   → Regenerate legacy snapshots
```

**Delete Identity**
```
People Manager
→ Identity Store update
→ Next save strips references everywhere
```

---

**End of dMPP-Context-v10.md**
