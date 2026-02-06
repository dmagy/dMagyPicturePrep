
# dMPP-Context-v13.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2026-02-04-CTX13  
**Supersedes:** dMPP-2026-01-01-CTX12  

---

## 0. What changed since CTX12 (Reality Delta + Intent Delta)

### 0.1 Reality (implemented)

* **Portable Archive implemented as a real folder structure** under the selected Picture Library Folder:
  * `<Archive Root>/dMagy Portable Archive Data/`
  * Subfolders include: `People`, `Locations`, `Tags`, `Crops`, `_locks`, `_meta`, `_indexes`
  * README + `_Read_Me_.pdf` are bundled and copied on first bootstrap
* **Registry “ownership model” shifted toward App-owned stores**, configured per archive root (no singleton assumptions):
  * Identity store configured for archive root and used across windows via injection
  * Tags migrated to a **record model**: name + description + reserved flags (portable JSON)
  * Locations can be persisted to portable JSON (with prefs sync in transitional phase)
* **Tags became human-friendly**:
  * Tag descriptions are now user-editable (multiline)
  * Reserved tags enforced: `Do Not Display`, `Flagged`
  * Default starter tags included for new users: `Halloween`, `NSFW`
  * Linked file UI added to Tags tab (“Linked file (advanced)”)
* **Settings UI improved**:
  * “General” tab shows active Picture Library Folder + where portable registry data lives
  * “Fingerprint chip” + Copy buttons style introduced (path helpers)
* **People Manager** now behaves correctly as archive-aware:
  * People/Identity data reads/writes against portable archive configuration
  * Linked file panel in People uses disclosure (“Linked file (advanced)”)

### 0.2 Intent (planned / proposed)

* **Headshot-per-person crops** (multiple headshots per photo tied to a person) is now planned.
* **New Crop menu redesign** planned (more common aspect ratios + headshot variants + grouping).
* **Crops portability** planned (move crop preset vocabulary into portable archive, keep per-photo crops authoritative).
* **Registry mismatch tools** planned (help users reconcile sidecars from someone else’s dMPP).

---

## 1. Purpose of dMagy Picture Prep (dMPP)

**dMPP** is a macOS utility for preparing personal, family, and archival photographs for long-term use and rich presentation.

Goals:

* Apply **structured, future-proof metadata** using **dMPMS**
* Manage **people + identity data** in a way that is **portable with the photo archive**
* Create and persist **virtual crops** for multiple display targets
* Support a deliberate, folder-based review workflow
* Store all edits **non-destructively** in `.dmpms.json` files

Where **dMPS shows pictures**, **dMPP prepares them**.

---

## 2. Relationship to dMPMS and dMPS

### 2.1 dMPP ↔ dMPMS

dMPP is the reference implementation (or at least the “most opinionated working example”) of dMPMS.

**Current direction:** portability-first.

Key portability impacts:

* Per-photo sidecars remain `*.dmpms.json` alongside each image.
* The archive contains a portable registry folder (implemented):

  * `dMagy Portable Archive Data/People/…`
  * `dMagy Portable Archive Data/Tags/tags.json`
  * `dMagy Portable Archive Data/Locations/locations.json`
  * `dMagy Portable Archive Data/Crops/…` (folder exists; vocabulary portability is planned)
  * `dMagy Portable Archive Data/_locks/…`
  * `dMagy Portable Archive Data/_meta/schemaVersion.json`
  * `dMagy Portable Archive Data/_indexes/…`

> NOTE: CTX12 referenced an `_dmpms/` folder as a possible spec target.  
> CTX13 reflects the implemented “dMagy Portable Archive Data” structure.  
> If `_dmpms/` remains a spec goal, document it as **future compatibility** rather than current behavior.

### 2.2 dMPP ↔ dMPS

* Communication occurs via **portable archive files**:
  * per-photo `.dmpms.json`
  * shared registries under `dMagy Portable Archive Data/`
* No shared runtime, database, or dependency.
* dMPP prepares; dMPS consumes.

This keeps dMPS lightweight and makes the archive copyable.

---

## 3. Core Workflow Model

### 3.1 Metadata-first editing

* Images are never modified.
* All edits live in `.dmpms.json`.
* Deleting a `.dmpms.json` never affects the image.

### 3.2 Folder-based review (“archive browsing”)

* User selects a folder via `NSOpenPanel`.
* Supported formats: `jpg, jpeg, png, heic, tif, tiff, webp`
* Images are reviewed sequentially.

Save behavior:

* Autosave on navigation (current behavior)
* Autosave on folder change
* Explicit Save / ⌘S (when enabled)

> UI avoids saying “sidecar” out loud.

---

## 4. Technical Architecture (CTX13)

### 4.1 Application entry

#### `dMagy_Picture_PrepApp.swift`

* App entry point
* Defines:
  * Main editor window (`DMPPImageEditorView`)
  * Settings window(s)
  * People Manager window
* Injects shared environment objects (archive store, identity store, tag store, location store, preferences, etc.)

**Pattern:** stores are App-owned and configured per archive root.

---

### 4.2 Archive Root Gate + configuration

#### `DMPPArchiveRootGateView` (pattern)

* Ensures a Picture Library Folder is chosen.
* Configures stores when the archive root changes:
  * `identityStore.configureForArchiveRoot(root)`
  * `tagStore.configureForArchiveRoot(root, fallbackTags: …)`
  * `locationStore.configureForArchiveRoot(root, fallbackLocations: …)` (if enabled)

Key rule:  
**Configure the injected store instance**, not a singleton, to avoid multiple store copies.

---

### 4.3 Editor shell

#### `DMPPImageEditorView.swift`

Layout:

* Top toolbar:
  * Folder picker
  * Include subfolders
  * “Show only unprepped pictures” (skip images that already have `.dmpms.json`)
* Split view:
  * Left: crop pane
  * Right: metadata pane
* Bottom bar:
  * Save
  * Previous/Next picture
  * Previous/Next crop
  * Status/info text (New / Existing / Modified) — planned refinement

Owns:

* folder scanning → `imageURLs`
* `currentIndex`
* `.dmpms.json` URL computation
* image load/save orchestration
* per-image row context:
  * `activeRowIndex` remains owned by editor and re-synced on load

---

### 4.4 Crop editing

#### `DMPPCropEditorPane.swift` + `DMPPCropOverlayView.swift`

Still responsible for:

* crop selection UI
* overlay drag/resize
* normalized rect updates

Direction:

* Per-photo `virtualCrops` remain authoritative.
* Shared preset vocabulary moving toward portable registry (`Crops/`) is planned.

---

### 4.5 Metadata editing

#### `DMPPMetadataFormPane.swift`

Per-photo fields:

* File (read-only)
* Title
* Description
* Date / Era
* Tags:
  * UI driven by tags registry (portable JSON)
  * Still feeds `prefs.availableTags` during transitional period so existing editor logic stays stable
* People:
  * driven by `vm.metadata.peopleV2`
  * supports snapshots and advanced panel
  * must remain stable under identity store refresh

---

### 4.6 ViewModel

#### `DMPPImageEditorViewModel.swift`

Owns:

* `imageURL`
* `nsImage`
* `metadata`

Responsibilities:

* date parsing + range derivation hooks
* crop creation and rect normalization
* people reconciliation utilities (identity re-resolution, snapshot refresh)
* age recomputation (must match save-time math)

---

## 5. Portable Archive (Implemented)

### 5.1 Folder name + required subfolders

Portable folder lives under the selected Picture Library Folder:

`<Archive Root>/dMagy Portable Archive Data/`

Bootstrap ensures required subfolders exist:

* `People/`
* `Locations/`
* `Tags/`
* `Crops/`
* `_locks/` (relative-path soft locks live here; warning-only)
* `_meta/` (schema version, etc.)
* `_indexes/` (cache/rebuildable)

Bundled resources copied if missing:

* `README.md` (not overwritten)
* `_Read_Me_.pdf` (not overwritten)

Schema metadata file ensured:

* `_meta/schemaVersion.json`

---

### 5.2 What data lives where (current)

**People**
* Stored under `People/…` (exact file breakdown depends on IdentityStore implementation)
* Edited via People Manager window and referenced by image sidecars via IDs

**Tags**
* `Tags/tags.json` contains tag records:
  * `id`, `name`, `description`, `isReserved`
* Backward compatible reads:
  1) `["Tag1","Tag2"]`
  2) `{ "tags": ["Tag1","Tag2"] }`
  3) current: `{ "tags": [ {record…} ], "updatedAtUTC": "…" }`

**Locations**
* `Locations/locations.json` stores locations list (portable)
* Backward compatible reads supported for plain arrays when needed

**Crops**
* Folder exists: `Crops/`
* Shared preset vocabulary planned; per-photo crops remain in sidecars

**Locks**
* `_locks/` contains lock records used to warn about concurrent editing (soft locks)

**Indexes**
* `_indexes/` used for derived caches; should be rebuildable

---

### 5.3 “Linked file (advanced)” UX

Purpose: show users *where the truth lives* without making every user learn file systems.

Pattern:

* A **DisclosureGroup** labeled “Linked file (advanced)”
* Shows:
  * fingerprint chip (short stable identifier derived from path)
  * file name and full path
  * Copy buttons (file name, full path)
  * Show in Finder button

Applied (so far):

* General settings tab (portable archive folder path)
* People tab (per-person record file)
* Tags tab (tags.json path)
* Locations tab already has an advanced linked file panel (per your note)

---

## 6. People & Identity System (Implemented direction)

### 6.1 Layers (conceptual)

1. **Person** (canonical attributes for filtering)
2. **Identity versions** (time-versioned structured name)
3. **Person-in-photo records** (`peopleV2`)

### 6.2 Canonical people live in the portable archive

* Portable people registry is authoritative.
* Person-level fields used for filtering:
  * gender
  * birth/death dates (or ranges)
  * kind (human/pet)
  * favorites, notes, aliases, etc.

Identity-level fields include:

* structured name parts (`givenName`, `middleName?`, `surname?`)
* `idDate` + `idReason` to choose best identity for a photo date

### 6.3 Person-in-photo records (`peopleV2`) are authoritative per image

`peopleV2` is the truth of “who is in this photo”, plus row/position ordering.

Stored per row (typical):

* `personID` (stable person grouping ID)
* `identityID` (chosen identity for photo date)
* snapshots:
  * `shortNameSnapshot`
  * `displayNameSnapshot`
  * `nameSnapshot` (given/middle/surname/display/sort)
* `ageAtPhoto` snapshot (derived; must match UI math)

“One-off people” supported:

* `identityID: nil`, `isUnknown: true`
* exist only for this photo
* do not create an identity record

### 6.4 Save-time normalization (still required)

On save:

* remove rows referencing identities that no longer exist
* re-resolve identity based on photo date
* refresh snapshots (`shortNameSnapshot`, `displayNameSnapshot`, `nameSnapshot`, `personID`)
* compute `ageAtPhoto` using the same range-aware logic as UI

---

## 7. Date & Age Handling (Implemented rule)

### 7.1 Canonical rule: everything is a range

Even when the user enters an exact day:

* `photoStart = photoEnd = that date`

Loose date:

* parse to an inclusive `(photoStart, photoEnd)` range

### 7.2 Range-aware age math

Birth can be loose too → treat birth as a range:

* `(birthStart, birthEnd)`

Then:

* **Youngest** age = `photoStart - birthEnd`
* **Oldest** age = `photoEnd - birthStart`

`ageAtPhoto` string:

* same number → `"17"`
* different numbers → `"17–19"`
* missing inputs → `nil` / empty display

### 7.3 Single source of truth requirement

There must be exactly one “age text” implementation used by:

* UI display
* save-time normalization
* background recompute hooks

Avoid divergent call sites.

### 7.4 Loose date parsing API naming

To avoid Swift “Ambiguous use of 'range'” collisions:

* prefer explicit names like:
  * `LooseYMD.parse(...)`
  * `LooseYMD.parseRange(...)`
  * `LooseYMD.birthRange(...)`

Avoid having multiple `range(...)` overloads across types.

---

## 8. Tags (Implemented)

### 8.1 Portable tags registry

Portable file:

* `<Archive Root>/dMagy Portable Archive Data/Tags/tags.json`

Current schema:

```json
{
  "tags": [
    { "id": "...", "name": "Do Not Display", "description": "...", "isReserved": true }
  ],
  "updatedAtUTC": "..."
}
````

### 8.2 Reserved tags

Reserved tags always exist and cannot be renamed/deleted via UI:

* `Do Not Display`
* `Flagged`

### 8.3 Default starter tags

For brand-new archives / empty tags.json, include:

* `Halloween`
* `NSFW`

Descriptions can be seeded via a default dictionary (store-owned) for known tags.

### 8.4 Transitional behavior: prefs sync

The editor still largely consumes:

* `prefs.availableTags: [String]`

So Settings can:

1. Load portable tags into TagStore
2. Sync `prefs.availableTags = tagStore.tags` (names)
3. Persist edits by writing TagStore then updating prefs names

This keeps existing editor checkbox logic stable while tags registry evolves.

---

## 9. Locations (Implemented direction; transitional)

Portable file:

* `<Archive Root>/dMagy Portable Archive Data/Locations/locations.json`

Schema (current):

```json
{
  "locations": [ ... ],
  "updatedAtUTC": "..."
}
```

Notes:

* Settings UI can keep using `prefs.userLocations` while the store persists portable truth.
* Sync pattern mirrors tags:

  * configure store for root
  * seed from prefs if portable is empty
  * update prefs from portable
  * persist prefs edits back to portable

---

## 10. Crops (Current + planned)

### 10.1 Current truth: per-photo virtual crops

* Per-photo `virtualCrops` remain the real data stored in `.dmpms.json`.

### 10.2 Planned: portable preset vocabulary (Crops folder)

Recommended if:

* consistent preset naming across machines is important
* dMPS needs to interpret “which crop is which” without dMPP settings
* you ship an archive to family and want predictable crop options

Not strictly required if:

* you only consume per-photo crops and don’t care about shared preset IDs/labels

---

## 11. Save semantics & “dirty” tracking (restored detail)

* Baseline hash on load
* Save enabled only when materially changed
* Exclude derived-only fields from dirty tracking **if** they’re recomputed automatically (be consistent)
* Autosave triggers:

  * navigation between images
  * folder change
  * optional save checkpoint actions

> If code and document diverge, fix the code. If you must lie, lie only in “planned”.

---

## 12. Snapshots (restored detail)

Snapshots remain a per-photo safety net for people tagging.

Guidance:

* Snapshot note remains optional
* Snapshot list should show full content (no artificial truncation)
* Reset People confirmation continues: Save snapshot or Skip, then clear

---

## 13. Workflow options (restored + updated)

### 13.1 Include subfolders

* folder scan includes nested images

### 13.2 Show only unprepped pictures

* skip images that already have a `.dmpms.json` present

### 13.3 Metadata status indicator (planned)

* New (no sidecar)
* Existing (sidecar present, no changes)
* Modified (dirty vs baseline)

---

## 14. Known limitations (restored + updated)

Still true unless implemented:

* soft-only date validation (user intent wins)
* no batch operations
* no full metadata undo
* UI avoids “sidecar” terminology

Portable archive realities:

* registries missing:

  * dMPP bootstraps required folder structure (implemented)
  * data may still be incomplete until user edits registries
* cross-machine edits:

  * soft locks are warning-only; resolution UX can improve
* receiving sidecars from others:

  * registry mismatch tools are planned (Phase 4)

---

## 15. Roadmap (Updated — restored CTX12 backlog + CTX13 phases)

### Phase 0 — Documentation synchronization (now)

* Update:

  * `dMPP-AI-Context.md`
  * `dMPP-Context-v13.md`
* Ensure docs reflect implemented:

  * portable archive paths + subfolders
  * store configuration patterns
  * Tags/Locations JSON persistence + prefs sync

---

### Phase 1 — Headshot-per-person crops (planned / proposed)

**Goal:** allow multiple headshot crops per image, each tied to a person.

**Decisions locked in:**

1. Crop model fields:

   * `crop.kind = .headshot`
   * `crop.variant = tight | full`
   * `crop.personID = …` (required)
   * `crop.displayLabel = "<ShortName> — Headshot (Tight/Full)"`

2. Person link rules:

   * Person link is **not editable** after creation.
   * If a person is deleted from People registry, crop remains; UI shows “missing person” using sidecar snapshot name.

3. Grouping:

   * Headshots group into a dropdown tab on the crop bar when present.

4. Uniqueness:

   * Only one headshot per person per variant per image
     (e.g., Everett may have Tight + Full, but not two Tight)

5. Defaults:

   * **Option A:** No headshot defaults; headshot crops only exist when added.

**Open implementation decisions:**

* Person picker source:

  * Prefer seeding from “checked people” in the People section for the image.
  * Determine whether this requires save-first or can use immediate persistence.
* Reduce clicks when adding multiple headshots:

  * If a Tight headshot exists for this photo, default subsequent headshot adds to Tight (until user changes variant).
* “Add new person…” behavior:

  * open People Manager directly OR open picker → People Manager

---

### Phase 2 — New Crop menu redesign + grouping behavior (planned)

Proposed New Crop structure:

* Freeform
* Headshot

  * Full
  * Tight
* Landscape

  * 3:2 (4x6, 8x12…)
  * 4:3 (18x24…)
  * 5:4 (4x5, 8x10…)
  * 7:5 (5x7…)
  * 14:11 (11x14…)
  * 16:9
* Original (full image)
* Portrait

  * 2:3 (4x6, 8x12…)
  * 3:4 (18x24…)
  * 4:5 (4x5, 8x10…)
  * 5:7 (5x7…)
  * 11:14 (11x14…)
  * 9:16
* Square
* ---
* Manage Custom Presets…

Crop bar grouping behavior:

* When headshots exist, show a Headshot group:

  * `Headshot (Full)` or `Headshot (Tight)` as group label
  * submenu lists people short names under that variant
  * include `Add new person…`

---

### Phase 3 — Crops registry portability (planned)

* Move preset vocabulary under `dMagy Portable Archive Data/Crops/` (define schema)
* Ensure New Crop menu aligns with portable presets
* Keep per-photo `virtualCrops` as authoritative; registry is shared vocabulary

---

### Phase 4 — Registry mismatch tools (planned)

* Tools to reconcile incoming sidecars with local registries:

  * missing people mapping
  * missing tags mapping
  * missing locations mapping
* UI for “this came from another family member’s dMPP”
* Principle: don’t silently drop sidecar data; show missing state + offer repair.

---

### High priority (restored from CTX12)

* Fully implement **portable family archive** behavior:

  * People / Tags / Locations as portable authority
  * migrate UI away from global preferences lists for registry-backed data
* Multiple headshots per photo, assign per person-in-photo
* Revisit crop presets + add common crops; consider portable crops registry
* Tags descriptions + UX polish (done core; improve flow)
* Clean up Settings UI:

  * less “authority”, more “editor preferences”
  * keep “Linked file (advanced)” consistent and optional

---

### Medium (restored from CTX12)

* Add Flagged to archive browsing modes (filter buttons)

  * other filtering options
* Review filters (flagged pictures, incomplete metadata)
* Address window sizing issues on launch (primary + Settings)
* Voice input for title/description
* Build first-run instruction window and help
* Review `_Read_Me_` and add examples
* Code review + optimization

---

### Longer-term (restored from CTX12)

* Investigate facial recognition (possible to use Photos engine?)
* Investigate integration/image acquisition from Photos
* Visual people layout overlays
* Import/export tooling (ancestry.com, etc.)
* Keyboard-driven editor mode
* Shared Swift Package between dMPP and dMPS (models + parsing utilities)

---

## 16. Version tracking

```text
dMPP-2026-02-04-CTX13
```

If code and documentation diverge, fix the code.

---

**End of dMPP-Context-v13.md**

