# dMPP-AI-Context (dMagy Picture Prep) — v13
_Last updated: 2026-01-17 (America/Denver)_

## 0. Current Working State
- **Active work branch:** `restore/from-692c557`
- **Restore marker commit:** `c89050b` (“test for restore”)
- **Local dev location:** project is now worked on from a **local folder** (example: `~/Developer/...`) and **not** inside Dropbox.
- **Naming decision:** keep existing `DMPP*` Swift file/type naming (no large-scale renames).

---

## 1. Project Overview
**dMagy Picture Prep (dMPP)** is a macOS app (Swift + SwiftUI) that helps a user **prepare and normalize a large photo archive** by editing crops and writing **consistent, portable metadata** alongside images—so downstream tools (including dMPS and future dMagy apps) can reliably filter, sort, and present photos.

dMPP focuses on **curation + metadata authoring**, not slideshow playback.

The app supports (current working model):
- Selecting a **single root photo archive** once (first-run), then working in any subfolder later.
- Maintaining a **portable metadata settings/registry folder** under that root (so people/places/definitions are not recreated per subfolder).
- Per-photo editing:
  - Crop/frames (ex: 16:9, 8×10, etc.)
  - Date taken / era (including ranges / approximate date strings)
  - People in photo (known identities + “unknown” placeholders)
  - Locations (consistent naming / reuse)
  - Notes / tags (as defined by dMPMS)
- Writing sidecar metadata using **dMagy Photo Metadata Standard (dMPMS)** (JSON sidecars).

This document is the single source of truth for ChatGPT so context stays stable across sessions and code updates.

---

## 2. Architectural Principles
- **SwiftUI-first** for UI and composition.
- **Separation of concerns**
  - Folder/archive selection & bookmarking
  - Image loading + thumbnail pipeline
  - Metadata model (dMPMS structures)
  - Sidecar read/write (atomic, safe)
  - Editor UI (forms + pickers)
  - Global registries (People, Locations, etc.)
- **Portable archive model (critical)**
  - User picks a **root archive once** (e.g., `/PhotosArchive/`)
  - dMPP creates/uses a readable folder under that root for portable registries/indexes.
  - People/Locations are **archive-global**, per-photo selections remain **per-photo**.
- **Avoid “sync island” designs**
  - Do not require merging multiple `_dmpms` islands later.
- **Anchors govern AI-assisted edits** (see section 6).
- **Novice-friendly code changes**
  - Smaller edits, explicit anchors, checkpoints, and reversible steps.
- **Local dev working copy (Dropbox rule)**
  - Do not actively develop in a Dropbox-synced folder.
  - Use local disk for working repo; use Dropbox for zipped snapshots/backups if desired.

---

## 3. Key Components & Files (conceptual map)
File names may vary, but these responsibilities should exist and remain stable.

### App entry / scenes
- `dMagy_Picture_PrepApp.swift`
  - App entry point
  - Main window scene (editor)
  - macOS Settings scene

### Primary editor shell
- `DMPPImageEditorView.swift`
  - Layout:
    - Top toolbar: folder selection (subfolder), path display
    - Split view:
      - Left: photo list/grid (rows)
      - Right: metadata editor form for selected row
  - Coordinates active selection, navigation, and save/dirty state

### Metadata form
- `DMPPMetadataFormPane.swift` (or similar)
  - Edits current photo metadata (date/era, people, locations, notes/tags)
  - “Add unknown person” flow + checklist behavior
  - Must ensure UI edits update the current row immediately
  - Date validation UI uses `dateWarning` + `dateValidationMessage(for:)`

### People Manager (archive-global registry)
- `DMPPPeopleManagerView.swift` (or similar)
  - Add/edit/remove identities (variants, birth/death, etc.)
  - Canonical “People list” for per-photo selections

### Location Manager (recommended)
- `DMPPLocationManagerView.swift` (or similar)
  - Normalize places + variants
  - Avoid “free-text chaos”

### Data model + storage
- `DMPMS*.swift` models
  - Photo metadata + registries
- `DMPMSSidecarStore.swift` (or similar)
  - Load sidecar
  - Save sidecar atomically
- `DMPPArchiveStore.swift` (or similar)
  - Root archive selection & security-scoped bookmarks
  - Portable settings folder path
  - Load/save registries

### Row/table coordination
- `DMPPPhotoRow.swift` / `DMPPGridModel.swift` (or similar)
  - Selected image + authoritative current row metadata + dirty state
  - Fix priority issues where global list updates must apply to current row when expected

---

## 4. Core Behaviors

### 4.1 Root Archive + Subfolder Workflow (portable model)
- First run:
  - Prompt user to choose the **root archive folder**
  - Create/use portable settings folder under root
- Daily use:
  - User chooses any working folder under root
  - Same People/Location registries are available everywhere

### 4.2 Photo List + Row Editing
- Selecting a photo loads:
  - image preview
  - sidecar metadata (if present)
  - derived UI state (ages, labels, validation)
- Changes reflect in current row immediately
- Save writes sidecar safely (no partial writes)

### 4.3 People in Photo (Known + Unknown)
- Known people: references to archive-global identity records (stable IDs)
- Unknown people: placeholders added quickly, optionally resolved later
- Key rule:
  - Adding an unknown person must update BOTH:
    1) global list (if part of design), and
    2) current photo row’s people list (immediate UX expectation)

### 4.4 Date / Era + Age Calculations
Supported user-entered date strings currently include:
- `YYYY-MM-DD` (exact date)
- `YYYY-MM` (month)
- `YYYY` (year)
- `YYYYs` (decade)
- `YYYY-YYYY` (year range)
- `YYYY-MM to YYYY-MM` (month-to-month range)
- Ranges using `" to "` can also be composed from supported forms on each side.

#### Date validation rule (important UX constraint)
- **Only show a red warning** when the user input *looks like one of the supported numeric formats above* AND is invalid.
- Do **not** show red warnings for other free text entries (even if not supported yet).

#### Strict numeric date validation (implementation decision)
- Validation must reject “normalized” invalid dates (e.g., `1985-75` must not silently become a later date).
- `LooseYMD.dateFromPartsUTC` must be strict via bounds checks + round-trip verification.
- `LooseYMD.validateNumericDateString` must drive UI warnings.

#### Age display refresh must occur on:
- row selection changes
- date/dateRange edits
- people edits
- metadata sourceFile change (as applicable)

### 4.5 Locations
- Encourage selection from a registry to reuse locations
- Locations should behave like People:
  - archive-global registry
  - per-photo selection

---

## 5. Known Decisions & Constraints
- **dMPP is not a slideshow player.**
- **Portability is the point.**
  - metadata lives with photos (sidecars)
  - registries live under the user’s archive root, not opaque app-only storage
- **Bookmark failures degrade gracefully**
  - clear messaging
  - no crashes; offer “reselect root archive”
- **UI stays “fast enough”**
  - avoid blocking disk IO on main thread
  - thumbnails can be cached, but correctness wins

---

## 6. Anchors & Checkpoints

### Anchors
Use stable labels in code comments. Examples:
```swift
// [INIT] view init / setup
// [ARCH] root archive selection & bookmarks
// [SCAN] folder scan / rows build
// [ROW] row selection & metadata load
// [FORM] metadata form bindings
// [PEOPLE] people in photo logic
// [LOC] location logic
// [DATEVAL] numeric date validation + warnings
// [SAVE] sidecar write
// [CFG] settings / defaults
// [END] cleanup

Rules:

Never rename an anchor already in use.

Add new anchors for new sections.

When asking ChatGPT for changes, reference the anchor(s).

Checkpoints

Format:
cp-YYYY-MM-DD-## — short description

Recent checkpoints (2026-01-17):

cp-2026-01-17-01 — restored working branch from 692c557 and resumed work on restore/from-692c557

cp-2026-01-17-04 — added strict numeric date validation helpers to LooseYMD

cp-2026-01-17-07 — made dateFromPartsUTC strict to prevent normalized invalid months/days (e.g., 1985-75)

(Checkpoint numbers may vary based on your actual commit history; the naming convention is what matters.)

7. How ChatGPT Should Respond (Xcode-Compatible Rules)

When modifying code:

Keep existing anchors unchanged.

Provide only the changed region(s) (anchored).

Include a diff/patch block when practical.

Include brief notes:

assumptions made

how to run/test (3–5 steps)

risks/follow-ups

7.1 Small-Step Delivery and Staying on Track (critical)

Deliver changes in small steps (usually 1-2 steps at a time).

Maintain a “Remaining Steps” list when work is larger than 2 steps.

7.2 Cumulative Paste-Over Comes First

If a single paste-over is possible, provide it first before incremental snippets.

7.3 Clarifying Questions Allowed

Ask a question first if it prevents rework (file names, anchors, desired behavior).

7.4 Novice-Friendly Collaboration

Add reference-point comments for easy discussion (“see [DATEVAL]”).

Prefer reversible edits.

Keep instructions bite-sized and resumable.

8. Backlog (Active Considerations)

Portable archive settings folder naming + migration when root moves

Faster folder scanning + thumbnail caching

People workflow polish

unknown → identified conversion

ensure newly added unknown applies to current row immediately

Location manager UX parity with People manager

Validation/health indicators (missing dates, missing crop, etc.)

Bulk operations (apply location/tag to selection)

Clearer save/dirty status indicators

9. Exclusions

This context does not include:

dMPS slideshow playback features

Card Parties / OCG content

Church projects

SVVSD/DTS work, ServiceNow, procurement, compliance

Any unrelated app development work

10. Maintenance Notes

Keep this file under version control (suggested path: Docs/DMPP-AI-Context.md).

Update after major architectural changes, especially:

portable archive structure

sidecar schema

people/location registry logic

validation rules (date parsing/accepted formats)

Target length: ~3–5 pages.
