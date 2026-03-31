# dMPP-Context-v15.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2026-03-07-CTX15  
**Supersedes:** dMPP-2026-02-15-CTX14  

---

## 0. What changed since CTX14 (Reality Delta + Intent Delta)

### 0.1 Reality (implemented)

#### People workflow: Manual vs Auto-Detect (“Face mode”)

- People assignment supports **two explicit modes**:
  - **Manual**: row-by-row people workflow (existing behavior preserved).
  - **Auto-Detect**: face boxes overlay + **numbered face slots** that map to people assignments.
- Mode selector is a **segmented control**: `Manual | Auto-Detect`.
- Auto-Detect is treated as a true mode: manual row workflow is hidden/disabled while in Auto-Detect.
- Auto-Detect includes:
  - Numbered face slots (wrapping layout) + active slot selection.
  - Auto-advance to next unassigned slot.
  - Ignore face workflow (ignore + restore chips).
  - “Clear ignored faces” re-selects an active slot and hint text reflects actual assignment state.
  - “Face tools” row: Ignore face / Clear slot.
  - One-off assignment (assign `"oneoff:<label>"` to active slot).
- Crop preview includes a temporary **Hide/Show Face Boxes** control while Auto-Detect is active (session-only for current photo).

#### Face-mode persistence model

Per-photo metadata includes optional face-slot fields:

- `peopleMethod` (string: `"manual"` or `"faces"`)
- `faceAssignments: [String:String]` where key is slot `"1"`, `"2"`, etc and values are:
  - `"id:<personID>"` or
  - `"oneoff:<label>"`
  - (legacy values tolerated; new saves should write prefixed forms)
- `ignoredFaceNumbers: [Int]`

Save behavior:

- When face assignments exist, the sidecar includes:
  - `faceAssignments` and `ignoredFaceNumbers`
  - a **derived `peopleV2`** list generated from face assignments so “who is in the photo” is always present in the JSON.

Dirty tracking:

- Dirty tracking includes face-mode fields so Save enables properly.

#### Face mode restore stability

- Mode restore and face re-detect run reliably when:
  - moving next/previous picture
  - restarting the app
- Programmatic restore is isolated from user-initiated mode switching (suppression flag prevents accidental wipes).

#### Settings

- Settings view is now `DMPPSettingsView` (renamed from historical crop-first naming).
- Default People mode preference exists in Settings → People:
  - `@AppStorage("dmpp.defaultPeopleMode")` with values `"manual"` or `"faces"`
  - Applies only for photos **with no existing `.dmpms.json` sidecar**.

#### Voice dictation (Description)

- Description field supports dictation:
  - mic button
  - keyboard shortcut
  - info popover
  - deterministic “clean up description” (non-AI)
- Dictation stops when Description loses focus.

---

### 0.2 Intent (planned / proposed)

- Consolidate/centralize UI refresh for Tags + Locations in the editor so changes in Settings update the editor without relaunch/reopen loops (see Punchlist).
- Continue tightening “stores as truth” behavior so editor checklists and pickers don’t drift from portable registries.

---

## 1. Purpose of dMagy Picture Prep (dMPP)

dMPP is a macOS Swift/SwiftUI application for preparing a personal photo archive to be:

- **Structured** (portable archive folder, registries, consistent IDs)
- **Searchable** (tags, people, locations, dates/ranges)
- **Display-ready** (virtual crops + export crops for downstream use)
- **Durable** (metadata lives with the archive, not trapped in one machine)

Primary goal: make photo curation repeatable, not heroic.

---

## 2. Relationship to dMPMS and dMPS

### 2.1 dMPP ↔ dMPMS

dMPP is the editor/curator for the dMagy Photo Metadata Standard (dMPMS):

- Reads/writes per-image sidecar metadata files
- Normalizes and validates metadata at save time
- Connects per-image metadata to archive-wide registries (People / Tags / Locations / Crops)

### 2.2 dMPP ↔ dMPS

dMPP prepares content for dMagy Picture Show (dMPS):

- dMPS consumes the curated archive (images + sidecars)
- dMPP ensures the archive is consistently structured so dMPS can remain “dumb but fast” (in a good way)

**Note:** dMPSv2 intent is to primarily consume *virtual crops* (see §4.4).

---

## 3. Core Workflow Model

### 3.1 Metadata-first editing

dMPP is primarily a **metadata editor** with strong rules:

- Per-image metadata is authoritative for “what’s in this photo”
- Archive registries provide canonical vocabularies and IDs
- Save-time normalization keeps the archive consistent over years of edits

### 3.2 Folder-based review (“archive browsing”)

Users browse a folder tree under the selected archive root:

- Optional include subfolders
- Review filtering:
  - All Pictures
  - Never Reviewed (no sidecar)
  - Flagged
- Per-photo editing occurs in a consistent editor shell

---

## 4. Technical Architecture (CTX15)

### 4.1 Application entry

- App owns the shared stores (single source of truth).
- Stores are injected using `environmentObject`.
- **Design rule:** no view should silently create its own store instance.

### 4.2 Archive Root Gate + configuration

- App launches into an **Archive Root Gate** until the user selects a valid archive root.
- Archive selection is persisted via a security-scoped bookmark.
- After selection, stores are configured to read/write under the chosen root.

### 4.3 Editor shell

- Shell view hosts navigation, preview, editing panels, and binds to stores.
- After gate success, stores assume a configured archive root.

### 4.4 Crop editing

- Crops exist in two forms:

  - **Virtual crops**: per-photo crop definitions stored in metadata (authoritative for intent).
  - **Export crops**: rendered image outputs written to the archive (authoritative for personal use outside of dMPS: sharing, printing, sending to family, etc.).

- **dMPSv2 intent:** dMPSv2 should primarily consume **virtual crops** (sidecar intent) and should not depend on exported crop files for its core pipeline.

### 4.5 Metadata editing

Per-photo metadata includes (typical scope):

- People-in-photo records (`peopleV2`)
- Tags (with canonical registries)
- Locations (canonical list + per-photo assignment)
- Date ranges (start/end) and derived age calculations

### 4.6 ViewModel

- ViewModels (where used) should be **thin coordinators**:
  - Assemble view state from stores
  - Provide intent-level actions (save, add tag, export crop)
  - Avoid duplicating normalization rules (those belong in stores / model layer)

---

## 5. Portable Archive (Implemented)

Portable data lives under the selected archive root in:

`<Archive Root>/dMagy Portable Archive Data/`

Typical subfolders:

- `People/`
- `Locations/`
- `Tags/`
- `Crops/`
- `_locks/` (if used)

What data lives where:

**Portable archive (shared, portable):**

- People registry (canonical people)
- Tags registry
- Locations registry
- Crop vocab / presets (if applicable)

**Per-image metadata (sidecars):**

- Per-photo authoritative assignments (`peopleV2`, tags, location, date range, crop intent, etc.)

---

## 6. People & Identity System (Updated)

### 6.1 People truth layers

- Canonical Person/Identities: stored in the portable archive People registry
- Per-photo record: stored per image, authoritative for that photo

### 6.2 Manual people-in-photo (existing)

- `peopleV2` is authoritative per image.
- Re-resolution should not lose user intent.

### 6.3 Auto-Detect (“Face mode”) people-in-photo (new)

Auto-Detect mode stores:

- `peopleMethod = "faces"`
- `faceAssignments` (slot → identity or one-off label)
- `ignoredFaceNumbers`

…and generates a **derived `peopleV2`** list on save.

**Rule:** `peopleV2` remains the primary “who is in the photo” list for downstream apps (including dMPS). Face slots add optional structure but are not required for consumers that only need the people list.

### 6.4 Face slot encoding rules (metadata)

- key: `"1"`, `"2"`, etc
- value formats:
  - `"id:<personID>"` preferred
  - `"oneoff:<label>"`
- legacy values tolerated, but new saves should write prefixed forms.

### 6.5 dMPMS schema guidance

Treat face-slot fields as an **optional dMPMS extension**:

- Safe to ignore if an app only understands `peopleV2`.
- Maintains forward compatibility while allowing richer workflows in dMPP.

---

## 7. Date & Age Handling (Implemented rule)

### 7.1 Canonical rule: everything is a range

All dates are treated as ranges:

- start (inclusive-ish)
- end (inclusive-ish)
- single-day: start=end

### 7.2 Range-aware age math

Age calculations must handle:

- exact dates
- fuzzy ranges (month/year only)
- multi-day spans

### 7.3 Single source of truth

Derived fields (like age) must be computed from the stored range and canonical person DOB range.

---

## 8. Tags (Implemented)

- Tags are stored in the portable archive Tags registry.
- Editor UI should present the canonical list consistently.

**Known current issue:** tags edits in Settings do not reliably refresh the editor tag checklist while a photo is open (see Punchlist).

---

## 9. Locations (Implemented)

- Locations follow the same principle as Tags:
  - portable Locations registry is canonical
  - per-photo assignment references canonical locations when possible

**Known current issue:** locations edits in Settings do not reliably refresh the editor location picker while a photo is open (see Punchlist).

---

## 10. Crops (Current + planned)

### 10.1 Current truth: per-photo virtual crops

Per-photo crops represent editing intent and are stored with the photo’s metadata.

### 10.2 Export crops

Export crops are for personal downstream use outside dMPS.

---

## 11. Save semantics & “dirty” tracking

- Dirty state tracks unsaved changes in the editor.
- Save triggers normalization, then writes sidecar updates atomically.
- Dirty tracking includes face-mode fields.

---

## 12. Snapshots

Snapshots exist to prevent “oops” events:

- Capture last-known-good metadata state
- Provide rollback paths during risky edits

---

## 13. Punchlist (Current priorities)

Work these one at a time:

1) **Locations added/deleted in Settings are not updating in the editor UI** (specifically the editor’s location picker for the active photo; portable JSON updates correctly).  -done
2) **Tags added/deleted in Settings are not updating in the editor UI** (specifically the editor’s tag checklist for the active photo; portable JSON updates correctly).    -done
3) Remove “Are you sure?” confirmation when deleting a crop (restore is easy).    -done
4) Ability to add a one-off headshot.    -done
5) Next picture moves focus/scrolls to Title.    -done
6) Ability to open an image from the browser in dMPP.  - still need to address

---

## 14. Known limitations and open decisions (Updated)

- UI refresh propagation between Settings registries and the active editor UI is currently imperfect for tags/locations.
- Face recognition (identity suggestion / matching) is not implemented; Auto-Detect is currently “face boxes + manual assignment,” not “who is this person.”

---

## 15. Roadmap (Updated)

### 15.1 Near-term (based on Punchlist)

1) Fix editor refresh for Locations after Settings changes    -done
2) Fix editor refresh for Tags after Settings changes    -done
3) Remove crop delete confirmation    -done
4) One-off headshot support    -done
5) Next picture focus/scroll behavior    -done
6) Open image from browser in editor  -pending
7) Date and location is not be added via picture metadata, add indicator for data source

### 15.2 Medium-term

- Facial recognition (investigation first, then implementation only with clear privacy/opt-in story)

---

## 16. Version tracking

**Build environment (current):**

- macOS: 26
- Xcode: 26.2 (17C52)

**Collaboration rules (operational):**

- Prefer whole-file paste-over for risky changes.
- Work in small, resumable steps.
- Use `// MARK:` anchors in files we touch.
- Add versioning points only for risky refactors.
