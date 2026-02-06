# dMPP-AI-Context-v2 (dMagy Picture Prep)

*Last updated: 2026-02-04 (America/Denver)*

> This document is the single source of truth for ChatGPT so context stays stable across sessions and code updates.
> **Goal:** Update for accuracy. Do not condense or remove content unless it is no longer accurate.

---

## 0. Current Working State

* **Current branch:** `main`
* **Branch status:** local `main` is pushed and aligned with `origin/main` (you completed a merge commit: `Merge branch 'restore/from-692c557'` and pushed).
* **Repo location update message observed:** Git remote reported the repo moved; use the new location:

  * `https://github.com/dmagy/dMagyPicturePrep.git` (note the lower-case owner in the message)
  * You also pushed successfully to `https://github.com/dMagy/dMagyPicturePrep.git` as shown in output.
* **Local dev location:** project is worked on from a **local folder** (example: `~/Developer/...`) and **not** inside Dropbox.
* **Naming decision:** keep existing `DMPP*` Swift file/type naming (no large-scale renames).
* **No `.shared` singletons for app stores:** app stores are injected via `@EnvironmentObject` (you confirmed `.shared` is only used for `NSWorkspace` now).

---

## 1. Project Overview

**dMagy Picture Prep (dMPP)** is a macOS app (Swift + SwiftUI) that helps a user **prepare and normalize a large photo archive** by editing crops and writing **consistent, portable metadata** alongside images—so downstream tools (including dMPS and future dMagy apps) can reliably filter, sort, and present photos.

dMPP focuses on **curation + metadata authoring**, not slideshow playback.

The app supports (current working model):

* Selecting a **single root photo archive** (first-run / when needed), then working in any subfolder later.
* Maintaining a **portable metadata settings/registry folder** under that root (so people/places/definitions are not recreated per subfolder).
* Per-photo editing:

  * Crop/frames (ex: 16:9, 8×10, etc.)
  * Date taken / era (including ranges / approximate date strings)
  * People in photo (known identities + “unknown” placeholders)
  * Locations (consistent naming / reuse)
  * Notes / tags (as defined by dMPMS)
* Writing sidecar metadata using **dMagy Photo Metadata Standard (dMPMS)** (JSON sidecars).

---

## 2. Architectural Principles

* **SwiftUI-first** for UI and composition.
* **Separation of concerns**

  * Root/archive selection & bookmarking
  * Image loading + thumbnail pipeline
  * Metadata model (dMPMS structures)
  * Sidecar read/write (atomic, safe)
  * Editor UI (forms + pickers)
  * Archive-global registries (People, Locations, Tags, Crops)
* **Portable archive model (critical)**

  * User picks a **root archive** (e.g., `/PhotosArchive/`)
  * dMPP creates/uses a readable folder under that root for portable registries/indexes.
  * People/Locations/Tags are **archive-global**, per-photo selections remain **per-photo**.
* **Avoid “sync island” designs**

  * Do not require merging multiple registry islands later.
* **Anchors govern AI-assisted edits** (see section 6).
* **Novice-friendly code changes**

  * Smaller edits, explicit anchors, checkpoints, and reversible steps.
* **Local dev working copy (Dropbox rule)**

  * Do not actively develop in a Dropbox-synced folder.
  * Use local disk for working repo; use Dropbox for zipped snapshots/backups if desired.

---

## 3. Portable Archive (Implemented)

### 3.1 Portable folder name + intent

* **Portable folder name (single source of truth):**
  `dMagy Portable Archive Data`

* Purpose: archive-global registries that travel with the archive root and are readable by humans.

### 3.2 Bootstrap behavior

* A bootstrap service ensures the portable folder and required subfolders exist **after the archive root is known**.
* Bootstrap also copies bundled “read me” assets (only if missing; does not overwrite user-edited README).

**Required subfolders currently include:**

* `People`
* `Locations`
* `Tags`
* `Crops`
* `_locks` (relative-path soft locks; warning only)
* `_meta`
* `_indexes` (treated as cache/rebuildable)

### 3.3 “Where is it on disk?”

Under the **Picture Library Folder** (archive root):

```
<Picture Library Folder>/
  dMagy Portable Archive Data/
    People/
    Locations/
    Tags/
    Crops/
    _locks/
    _meta/
    _indexes/
    README.md
    _Read_Me_.pdf
```

### 3.4 General Settings (implemented concept)

* A **General** tab exists (or is in-progress) to show:

  * Selected Picture Library Folder (root)
  * Portable Archive Data folder path
  * “Show in Finder” actions
  * Copy path actions (fingerprint chip + copy buttons style is used elsewhere and can be reused here)

---

## 4. Key Components & Files (conceptual map)

File names may vary, but these responsibilities exist and remain stable.

### App entry / scenes

* `dMagy_Picture_PrepApp.swift`

  * App entry point
  * Main window scene (editor)
  * macOS Settings scene
  * Injects environment objects (archive store, identity store, tag store, location store, preferences, etc.)

### Archive root “gate”

* A root gate view exists that:

  * If root is set → shows the main editor
  * If root is not set → shows the “Choose your Picture Library Folder” setup UI
  * Ensures identity store is configured for the active root
  * Auto-prompts on true first run (no saved bookmark)

### Primary editor shell

* `DMPPImageEditorView.swift`

  * Layout:

    * Top toolbar: folder selection (subfolder), path display, toggles
    * Split view: crop pane + metadata pane
  * Coordinates active selection, navigation, and save/dirty state

### Metadata form

* `DMPPMetadataFormPane.swift` (or similar)

  * Edits current photo metadata (date/era, people, locations, tags, etc.)
  * People checklists + “unknown person” flow
  * Must ensure UI edits update the current row immediately
  * Date validation UI uses `dateWarning` + `dateValidationMessage(for:)`

### People Manager (archive-global registry)

* `DMPPPeopleManagerView.swift`

  * Uses `@EnvironmentObject` stores:

    * `DMPPIdentityStore`
    * `DMPPArchiveStore`
  * Loads/saves identities in the portable archive (People folder)
  * Supports identity “versions” / life events
  * Supports reserved behaviors:

    * “Death” event does not create a new name
  * Has “Linked file (advanced)” disclosure behavior (or similar) for showing the actual JSON file path
  * Includes a person selection list + detail editor

### Locations Manager (Settings tab)

* Location editing UI exists inside Settings (Locations tab).
* Portable persistence is now supported (locations.json). UI can still bind to `prefs.userLocations` while syncing to portable JSON.

### Tags Manager (Settings tab)

* Tag management moved beyond plain `[String]`:

  * Tags now have:

    * `name`
    * `description` (multiline, editable, including reserved tags)
    * reserved tags enforced
    * default tags seeded for new users (see Tags section below)
* “Linked file (advanced)” is desired/added for Tags tab (as you requested).
* Tag edits persist to portable `tags.json`.

### Sidecar storage

* Sidecar metadata remains `*.dmpms.json` stored alongside images.
* Atomic writes are required.

---

## 5. Stores, Ownership, and Injection Model (Implemented Direction)

### 5.1 No singleton stores

* Identity, archive, tag, and location stores are **not** accessed via `.shared`.
* They are owned by the app and injected via environment:

  * `@EnvironmentObject var identityStore: DMPPIdentityStore`
  * `@EnvironmentObject var archiveStore: DMPPArchiveStore`
  * `@EnvironmentObject var tagStore: DMPPTagStore`
  * `@EnvironmentObject var locationStore: DMPPLocationStore` (if/when wired)

### 5.2 Identity store configuration is root-driven

* Identity store is configured using the active archive root URL.
* Configuration is triggered:

  * `.onAppear`
  * `.onChange(of: archiveStore.archiveRootURL)`
* Gate views ensure this is done early so downstream views don’t accidentally operate on a non-configured instance.

### 5.3 Transitional model: prefs vs portable JSON

Some UI still uses `prefs` as the immediate binding model, while portable JSON becomes authoritative.

**Current successful pattern (used for Tags and can be mirrored for Locations):**

* On appear / on root change:

  1. Configure store for root, seeding from prefs if portable is empty
  2. Migrate from legacy prefs if needed (only when portable empty/only reserved)
  3. Sync portable truth back into prefs for the rest of the app to use
* On prefs changes:

  * Persist to store, which sanitizes + enforces reserved tags, then syncs back to prefs if needed.

---

## 6. Core Behaviors

### 6.1 Root Archive + Subfolder Workflow (portable model)

* First run:

  * Prompt user to choose the **root archive folder**
  * Create/use portable settings folder under root
* Daily use:

  * User chooses any working folder under root
  * Same People/Location/Tag registries are available everywhere

### 6.2 Photo List + Row Editing

* Selecting a photo loads:

  * image preview
  * sidecar metadata (if present)
  * derived UI state (ages, labels, validation)
* Changes reflect in current row immediately.
* Save writes sidecar safely (no partial writes).

### 6.3 People in Photo (Known + Unknown)

* Known people: references to archive-global identity records (stable IDs).
* Unknown people: placeholders added quickly, optionally resolved later.
* Key rule:

  * Adding an unknown person must update BOTH:

    1. global list (if part of design), and
    2. current photo row’s people list (immediate UX expectation)

### 6.4 Date / Era + Age Calculations

Supported user-entered date strings currently include:

* `YYYY-MM-DD` (exact date)
* `YYYY-MM` (month)
* `YYYY` (year)
* `YYYYs` (decade)
* `YYYY-YYYY` (year range)
* `YYYY-MM to YYYY-MM` (month-to-month range)
* Ranges using `" to "` can also be composed from supported forms on each side.

#### Date validation rule (important UX constraint)

* **Only show a red warning** when the user input *looks like one of the supported numeric formats above* AND is invalid.
* Do **not** show red warnings for other free text entries (even if not supported yet).

#### Strict numeric date validation (implementation decision)

* Validation must reject “normalized” invalid dates (e.g., `1985-75` must not silently become a later date).
* `LooseYMD.dateFromPartsUTC` must be strict via bounds checks + round-trip verification.
* `LooseYMD.validateNumericDateString` must drive UI warnings.

#### Age display refresh must occur on:

* row selection changes
* date/dateRange edits
* people edits
* metadata sourceFile change (as applicable)

### 6.5 Locations

* Encourage selection from a registry to reuse locations.
* Locations behave like People:

  * archive-global registry
  * per-photo selection

---

## 7. Tags (Implemented Direction + Current State)

### 7.1 Portable storage

* Tags are stored under:

  * `<Picture Library Folder>/dMagy Portable Archive Data/Tags/tags.json`

### 7.2 Schema model (current)

Tags are now records, not just strings. Each tag can include:

* `id` (stable UUID string)
* `name` (checkbox label)
* `description` (user-maintained; multiline)
* `isReserved`

Reserved tags exist and cannot be renamed/deleted in the UI, but their descriptions are editable.

### 7.3 Reserved tags

Reserved tag names:

* `Do Not Display`
* `Flagged`

### 7.4 Default tags for new users

Default non-reserved tags currently include:

* `Halloween`
* `NSFW`

Default descriptions exist (you defined them) and should be seeded on first creation of records.

### 7.5 Editing behavior notes

* Description trailing space issue has been resolved.
* Tag name trailing space issue has been resolved (current).
* Normalize & Save:

  * A button exists and is wired.
  * It should normalize/clean duplicates and spacing and write `tags.json`.
  * **Important UX note discovered:** aggressive normalization on every keystroke caused spaces to disappear mid-typing; normalization should not run on each character for name/description edits.

### 7.6 “Linked file (advanced)”

* Tags tab should include a “Linked file (advanced)” disclosure section similar to People/General.
* The panel should show:

  * Filename capsule / chip
  * Full path (selectable)
  * Copy file name, copy full path, show in Finder

---

## 8. Locations (Implemented Direction + Current State)

### 8.1 Portable storage

* Locations are stored under:

  * `<Picture Library Folder>/dMagy Portable Archive Data/Locations/locations.json`

### 8.2 Confirming “switched to JSON model”

A practical confirmation method (you already used successfully):

* Edit `locations.json` by hand (e.g., change a short name)
* Relaunch dMPP
* Verify the UI reflects the change

This demonstrates locations are loading from portable JSON (or syncing from it into the UI model).

### 8.3 Transitional model still applies

* Settings UI may continue to bind to `prefs.userLocations` while:

  * syncing from portable JSON on appear / root change
  * persisting back to portable JSON on edits

---

## 9. People (Implemented Direction + Current State)

### 9.1 People Manager uses environment objects

* People manager views use:

  * `@EnvironmentObject var identityStore: DMPPIdentityStore`
  * `@EnvironmentObject var archiveStore: DMPPArchiveStore`

### 9.2 Root-driven store configuration

* People manager ensures identity store is configured for the active root via `.onAppear` / `.onChange` patterns.

### 9.3 Linked file (advanced)

* A “Linked file (advanced)” panel exists for People (or is expected), showing the person JSON path and helper actions.
* UX decision: the “Linked file” section should be hidden behind a disclosure control so average users don’t feel punished for being normal.

---

## 10. Crops (Current State + Planned)

### 10.1 Current status

* Crops exist as per-photo virtual crops (sidecar).
* Crop presets and crop list UI exist.
* Crops portable registry migration is planned (Crops folder exists in portable archive bootstrap).

### 10.2 Planned major change: multiple headshots per image (not yet implemented)

You have a planned design for headshots:

* `crop.kind = .headshot`
* `crop.variant = tight | full`
* `crop.personID = … (required)`
* `crop.displayLabel = "<ShortName> — Headshot (Tight)"` (or Full)

Rules / decisions:

* No headshot without a person (personID required).
* Person link is not editable.
* If a person is deleted, UI should show headshot crops as “missing person” (sidecar retains personID).
* Only one headshot per person per type.
* Option A: **no headshot defaults**; headshots only appear when added.
* Grouping: in the crop strip, headshots should appear grouped (dropdown) by variant and person (e.g., Headshot (Full) → Amy, Anna…).
* UX desire: reduce clicks when adding multiple headshots (if a Tight headshot exists for the picture, subsequent headshots likely use Tight unless the user switches variant).
* Person picker likely seeded from checked people in metadata; open decision: whether that requires save or immediate persistence.

---

## 11. Anchors & Checkpoints

### 11.1 Anchors

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
```

Rules:

* Never rename an anchor already in use.
* Add new anchors for new sections.
* When asking ChatGPT for changes, reference the anchor(s).

### 11.2 Checkpoints

Format:

* `cp-YYYY-MM-DD-## — short description`

Recent checkpoint convention remains valid.
Note: earlier entries referencing “active work branch restore/from-692c557” are now historical since that work has been merged into `main`.

---

## 12. How ChatGPT Should Respond (Xcode-Compatible Rules)

When modifying code:

* Keep existing anchors unchanged.
* Provide only the changed region(s) (anchored) when possible.
* If a single paste-over is requested, provide full paste-over first.
* Include a diff/patch block when practical.
* Include brief notes:

  * assumptions made
  * how to run/test (3–5 steps)
  * risks/follow-ups

### 12.1 Small-step delivery and staying on track (critical)

* Deliver changes in small steps (usually 1–2 steps at a time).
* Maintain a “Remaining Steps” list when work is larger than 2 steps.

### 12.2 Cumulative paste-over comes first

* If a single paste-over is possible, provide it first before incremental snippets.

### 12.3 Clarifying questions allowed

* Ask a question first if it prevents rework (file names, anchors, desired behavior).

### 12.4 Novice-friendly collaboration

* Add reference-point comments for easy discussion (“see [DATEVAL]”).
* Prefer reversible edits.
* Keep instructions bite-sized and resumable.

---

## 13. Backlog (Active Considerations)

Portable archive + UX:

* Portable archive settings folder naming + migration when root moves
* First-run instruction window / help
* Review `_Read_Me_` and add examples
* Validation/health indicators (missing dates, missing crop, etc.)
* Clearer save/dirty status indicators

Performance:

* Faster folder scanning + thumbnail caching (correctness wins; avoid blocking main thread)

People:

* People workflow polish
* Unknown → identified conversion
* Ensure newly added unknown applies to current row immediately
* Missing-reference handling (sidecar contains IDs not in registry)

Locations:

* Location manager UX parity with People manager
* Bulk apply location to selection

Tags:

* Tag descriptions support and portability (implemented)
* “Linked file (advanced)” in Tags tab (requested/added)

Crops:

* Re-examine New Crop menu structure (more aspect ratios)
* Headshot (Tight) / Headshot (Full) per-person tabs (planned)
* Grouping behavior in crop strip (planned)
* Move crop presets to portable JSON (planned)

Bulk operations:

* Apply location/tag to selection
* Batch operations (future)

---

## 14. Exclusions

This context does not include:

* dMPS slideshow playback features
* Card Parties / OCG content
* Church projects
* SVVSD/DTS work, ServiceNow, procurement, compliance
* Any unrelated app development work

---

## 15. Maintenance Notes

Keep this file under version control (suggested path: `Docs/dMPP/dMPP-AI-Context-v2.md` or similar).

Update after major architectural changes, especially:

* portable archive structure
* sidecar schema
* people/location/tag registry logic
* validation rules (date parsing/accepted formats)
* crop registry/headshot architecture

---
