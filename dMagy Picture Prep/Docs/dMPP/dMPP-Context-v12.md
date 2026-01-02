
# dMPP-Context-v12.md

**dMagy Picture Prep — Application Context & Architecture Overview**
**Version:** dMPP-2026-01-01-CTX12
**Supersedes:** dMPP-2025-12-22-CTX11

---

## 0. What changed since CTX11 (Reality + Intent Delta)

CTX12 is the “portable family archive” pivot:

* **dMPMS target bumped to v1.3** (portable archive layout + shared dictionaries).
* **People / Tags / (optional) Crops move into the archive**, not Application Support / UserDefaults.
* **Per-photo people records (`peopleV2`) expanded** to carry richer snapshots (structured name snapshot, personID).
* **Age-at-photo consistency fixed**: UI age and saved `ageAtPhoto` now use the same **range-aware** math.
* **Loose date parsing API stabilized**: eliminate ambiguous `range(...)` calls by using explicit names like `parseRange(...)`.
* Workflow options from CTX11 remain, but are now framed as “archive browsing modes” (include subfolders, skip already-prepped).

Net result: you can copy a folder to another Mac and dMPS can filter by gender/birthday/tags without needing dMPP’s settings.

---

## 1. Purpose of dMagy Picture Prep (dMPP)

**dMPP** is a macOS utility for preparing personal, family, and archival photographs for long-term use and rich presentation.

Goals:

* Apply **structured, future-proof metadata** using **dMPMS v1.3**
* Manage **people + identity data** in a way that is **portable with the photo archive**
* Create and persist **virtual crops** for multiple display targets
* Support a deliberate, folder-based review workflow
* Store all edits **non-destructively** in `.dmpms.json` files

Where **dMPS shows pictures**, **dMPP prepares them**.

---

## 2. Relationship to dMPMS and dMPS

### 2.1 dMPP ↔ dMPMS

dMPP is the reference implementation of dMPMS.

**Current target: dMPMS v1.3**

Key v1.3 impacts:

* Per-photo sidecars remain `*.dmpms.json` alongside each image.
* The archive MAY contain a reserved folder:

  * `_dmpms/people.json` (canonical people + identities; includes gender, birth dates, etc.)
  * `_dmpms/tags.json` (tag dictionary; `tagIDs` used in sidecars)
  * `_dmpms/crops.json` (optional preset dictionary)
  * `_dmpms/archive.json` (optional archive metadata)

### 2.2 dMPP ↔ dMPS

* Communication occurs only via the **portable archive files**:

  * per-photo `.dmpms.json`
  * shared dictionaries inside `_dmpms/`
* No shared runtime, database, or dependency
* dMPP prepares; dMPS consumes

This keeps dMPS lightweight and makes the archive copyable.

---

## 3. Core Workflow Model

### 3.1 Metadata-first editing

* Images are never modified
* All edits live in `.dmpms.json`
* Deleting a `.dmpms.json` never affects the image

### 3.2 Folder-based review (now: “archive browsing”)

* User selects a folder via `NSOpenPanel`
* Supported formats: `jpg, jpeg, png, heic, tif, tiff, webp`
* Images are reviewed sequentially

Save behavior (still):

* Autosave on navigation (current behavior)
* Autosave on folder change
* Explicit Save / ⌘S (optionally disabled when nothing changed)

> UI still avoids saying “sidecar” out loud.

---

## 4. Technical Architecture (CTX12)

### 4.1 Application entry

#### `dMagy_Picture_PrepApp.swift`

* App entry point
* Defines:

  * Main editor window (`DMPPImageEditorView`)
  * Settings window(s) (crop/tag management may shrink as dictionaries move to archive)
  * People Manager window
* Injects shared environment objects (archive store, identity store, preferences)

---

### 4.2 Editor shell

#### `DMPPImageEditorView.swift`

Layout (unchanged shape):

* Top toolbar:

  * Folder picker
  * Emerging options near folder:

    * Include Subfolders
    * “Show only unprepped pictures” (skip images that already have `.dmpms.json`)
  * Planned: clickable full path (open in Finder)
* Split view:

  * Left: crop pane
  * Right: metadata pane
* Bottom bar:

  * Save
  * Previous/Next picture
  * Previous/Next crop
  * Info text + status (planned: New / Existing / Modified)

Owns:

* folder scanning → `imageURLs`
* `currentIndex`
* `.dmpms.json` URL computation
* image load/save orchestration
* per-image row context:

  * `activeRowIndex` remains owned by editor and re-synced on load

---

### 4.3 Crop editing

#### `DMPPCropEditorPane.swift` + `DMPPCropOverlayView.swift`

Still responsible for:

* crop selection UI
* overlay drag/resize
* normalized rect updates

CTX12 direction:

* **crop preset definitions** increasingly belong in `_dmpms/crops.json` (portable),
  while UI preferences become “editor behavior” rather than “data authority”.

---

### 4.4 Metadata editing

#### `DMPPMetadataFormPane.swift`

Per-photo fields:

* File (read-only)
* Title
* Description
* Date / Era:

  * `dateTaken` (soft validation)
  * derives `dateRange` when possible
  * triggers age recomputation
* Tags:

  * **now intended to be dictionary-backed** (`tagIDs` ↔ `_dmpms/tags.json`)
  * UI presents human labels but stores stable IDs

People section:

* still driven by `vm.metadata.peopleV2`
* summary + primary actions + advanced disclosure group

---

### 4.5 ViewModel

#### `DMPPImageEditorViewModel.swift`

Owns:

* `imageURL`
* `nsImage`
* `metadata`

Responsibilities (expanded emphasis in CTX12):

* date parsing + range derivation hooks
* crop creation and rect normalization
* throttled history logging (if retained)
* people reconciliation utilities (identity re-resolution, snapshot refresh)
* **age recomputation** (must match save-time math)

---

### 4.6 Archive stores (NEW emphasis)

CTX12 assumes a new “archive-aware” layer exists (or is being introduced) that knows:

* what folder is the active archive root
* where `_dmpms/people.json` and `_dmpms/tags.json` live
* how to load/save those dictionaries
* how to behave when dictionaries are missing (create, or degrade gracefully)

Practical effect:

* People Manager edits **archive people.json**, not a global app registry.
* Tags UI edits **archive tags.json**, not a global preferences list.

---

## 5. People & Identity System (CTX12)

### 5.1 Layers (unchanged conceptually)

1. **Person** (canonical attributes for filtering)
2. **Identity versions** (time-versioned structured name)
3. **Person-in-photo records** (`peopleV2`)

### 5.2 Canonical people live in the archive (v1.3)

* `_dmpms/people.json` is authoritative.
* Person-level fields used by dMPS filtering include:

  * `gender` (person-level)
  * `birthDate` / `deathDate` (for filtering and age)
  * `kind` (human/pet)
  * favorites, notes, aliases, etc.

Identity-level fields include:

* structured name parts (`givenName`, `middleName`, `surname?`)
* `idDate` + `idReason` to choose best identity for a photo date

**Surname is optional** (pets, single-name scenarios).

### 5.3 Person-in-photo records (`peopleV2`) are authoritative per image

`peopleV2` is the truth of “who is in this photo”, plus row/position ordering.

CTX12 expands what is stored per row:

* `personID` (stable person grouping ID)
* `identityID` (chosen identity for photo date)
* richer snapshots:

  * `shortNameSnapshot`
  * `displayNameSnapshot`
  * `nameSnapshot` (given/middle/surname/display/sort)
* `ageAtPhoto` snapshot (derived; must match UI math)

“One-off people” remain supported:

* `identityID: nil`, `isUnknown: true`
* exist only for this photo
* do not create an identity record

### 5.4 Save-time normalization (still required)

On save, tools MUST:

* remove rows referencing identities that no longer exist
* re-resolve identity based on photo date
* refresh snapshots (`shortNameSnapshot`, `displayNameSnapshot`, `nameSnapshot`, `personID`)
* compute `ageAtPhoto` using the **same range-aware logic as UI**

---

## 6. Date & Age Handling (CTX12)

### 6.1 Canonical rule: everything is a range

Even when the user enters an exact day, treat it as:

* `photoStart = photoEnd = that date`

When the user enters a loose date:

* parse to an inclusive `(photoStart, photoEnd)` range.

### 6.2 Range-aware age math (fixing CTX11 inconsistencies)

Birth dates can also be loose (month-only, year-only), so treat birth as a range too:

* `(birthStart, birthEnd)` from birth grammar.

Then:

* **Youngest** age = `photoStart - birthEnd` (earliest photo, latest birth)
* **Oldest** age = `photoEnd - birthStart` (latest photo, earliest birth)

`ageAtPhoto` string:

* same number → `"17"`
* different numbers → `"17–19"`
* missing inputs → `nil` / empty display

### 6.3 Implementation requirement (to prevent UI/JSON mismatch)

There must be exactly one “age text” implementation used by:

* UI display
* save-time normalization
* background recompute hooks

If there are multiple call sites, they must funnel through a single helper, e.g.
`AgeAtPhoto.ageText(photoStart:photoEnd:birthStart:birthEnd:)`.

### 6.4 Loose date parsing API naming

To avoid the Swift “Ambiguous use of 'range'” collisions:

* prefer explicit names like:

  * `LooseYMD.parse(...)`
  * `LooseYMD.parseRange(...)`
  * `LooseYMD.birthRange(...)`

Avoid having multiple `range(...)` overloads in different files/types.

---

## 7. Tags (CTX12)

### 7.1 Sidecars store `tagIDs`, not labels

* Sidecars store stable IDs (`tagIDs: [String]`)
* Labels and notes come from `_dmpms/tags.json`

### 7.2 Tag dictionary is portable

* `_dmpms/tags.json` travels with the archive
* Tags can gain richer fields (notes, synonyms, type, hidden) without changing sidecar shape

---

## 8. Crops (CTX12)

### 8.1 Do we need `_dmpms/crops.json`?

Recommended if:

* you want consistent preset naming across devices
* dMPS needs to interpret “which crop is which” without dMPP settings
* you want to ship an archive to family members and have predictable crop options

Not strictly required if:

* you only ever consume per-photo `virtualCrops` and don’t care about shared preset IDs/labels

CTX12 stance:

* **Per-photo `virtualCrops` remain the real data**
* `_dmpms/crops.json` is an optional shared “vocabulary” for crop presets

---

## 9. Save semantics & “dirty” tracking (still CTX11-valid)

* Baseline hash on load
* Save enabled only when materially changed
* Exclude derived-only fields from dirty tracking **if** they’re recomputed automatically (be consistent)

---

## 10. Snapshots (CTX12)

Snapshots remain a per-photo safety net for people tagging.

Guidance:

* Snapshot note remains optional
* Snapshot list should show full content (no artificial truncation)
* Reset People confirmation continues: Save snapshot or Skip, then clear

---

## 11. Workflow options (still emerging, now “archive browsing modes”)

### 11.1 Include subfolders

* folder scan includes nested images

### 11.2 Show only unprepped pictures

* skip images that already have a `.dmpms.json` present

### 11.3 Metadata status indicator (planned)

* New (no sidecar)
* Existing (sidecar present, no changes)
* Modified (dirty vs baseline)

---

## 12. Known limitations (CTX12)

Still true unless implemented:

* soft-only date validation (user intent wins)
* no batch operations
* no full metadata undo
* UI avoids “sidecar” terminology

New-ish in CTX12:

* archive dictionaries missing: dMPP must decide whether to create them or run “read-only degraded”

---

## 13. Roadmap (updated)

### High priority

* Fully implement **portable family archive** behavior:

  * `_dmpms/people.json` and `_dmpms/tags.json` as authority
  * migrate UI away from global preferences lists for tags/people
* Multiple headshots per photo, assign per person-in-photo
* Revisit crop presets + add common crops; consider optional `_dmpms/crops.json`
* Add notes field to Tags (in tags.json + UI)
* Clean up Settings UI (less “authority”, more “editor preferences”)

### Medium

* Review filters (flagged pictures, incomplete metadata)
* Voice input for title/description
* Code review + optimization

### Longer-term

* Visual people layout overlays
* Import/export tooling
* Keyboard-driven editor mode
* Shared Swift Package between dMPP and dMPS (models + parsing utilities)

---

## 14. Version tracking

```text
dMPP-2026-01-01-CTX12
```

If code and documentation diverge, fix the code.

---

**End of dMPP-Context-v12.md**
