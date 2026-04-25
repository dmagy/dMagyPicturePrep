# dMPP-Context-v16.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2026-04-24-CTX16  
**Supersedes:** dMPP-2026-03-07-CTX15  

---

## 0. What changed since CTX15

### 0.1 Reality / Implemented

#### People workflow: Manual vs Suggested

People assignment now supports two explicit modes:

- **Manual**
  - Row-by-row people workflow.
  - Best when face detection misses people, the photo is complex, or non-human subjects such as pets need to be identified.

- **Suggested**
  - Face detection + numbered face slots.
  - Recognition suggestions with confidence percentage.
  - Accept / ignore / clear / one-off assignment workflows.
  - “Ignore Other Faces” for remaining unassigned visible faces.
  - Required assignment-or-ignore workflow before Save / Previous / Next.
  - Suggested face chips now use softer pill styling and wrap by content size.
  - People mode help lives in the People GroupBox title row.

#### Face recognition safety

- Face learning happens on **Save only**.
- Accepted suggestions can contribute to learned samples only after save.
- Stale suggestions have been checked and should not leak between photos.
- A permanent action exists to reset learned face samples for a person.
- Current confidence threshold and percentage display feel acceptable after real-world testing; monitor instead of actively tuning.

#### People startup / review state

- Startup review mode/navigation state now resets so relaunch starts in **All Pictures**.

#### Crop performance and crop UI

- Crop drag / slider jerkiness was fixed by caching a decoded image in the editor view model.
- Crop header was rearranged:
  - crop chips and New Crop are on the same row
  - crop actions moved to the upper right
- New Crop is now a button/popover instead of a native Menu button.
- New Crop popover row height and styling were refined.

#### Locations / GPS

- GPS-derived locations now enrich from saved Locations during initial load, not only after “Reset to GPS.”
- If reverse geocoding returns a nearby / slightly different street address, saved Locations may still match by:
  - same street name
  - same city
  - same state
  - same country
  - nearby house number
- When a saved Location match is found, the saved Location can overwrite the reverse-geocoded address so archive metadata stays consistent.

#### Tags / Locations refresh

- Settings updates for Tags and Locations have been addressed enough to move prior CTX15 punchlist items out of active priority.

#### Voice dictation

Description field supports dictation features from CTX15, if still present in current code:

- mic button
- keyboard shortcut
- info popover
- deterministic non-AI “clean up description”
- dictation stops when Description loses focus

---

### 0.2 Intent / Planned

- Continue tightening “stores as truth” behavior so editor checklists and pickers do not drift from portable registries.
- Add clearer indicators showing whether date/location came from:
  - image metadata
  - sidecar data
  - user edits
  - saved registry matching
- Add ability to open an image directly from Finder / browser into dMPP.
- Handle Picture Library Folder changes safely so portable archive data does not appear lost when the root moves.

---

## 1. Purpose of dMagy Picture Prep

dMagy Picture Prep (dMPP) is a macOS Swift / SwiftUI application for preparing a personal photo archive to be:

- **Structured** — portable archive folder, registries, consistent IDs
- **Searchable** — tags, people, locations, dates/ranges
- **Display-ready** — virtual crops and future downstream display behavior
- **Durable** — metadata lives with the archive, not trapped on one machine

Primary goal: make photo curation repeatable, not heroic.

dMPP focuses on **curation + metadata authoring**, not slideshow playback.

---

## 2. Relationship to dMPMS and dMPS

### 2.1 dMPP ↔ dMPMS

dMPP is the editor / curator for the dMagy Photo Metadata Standard (dMPMS):

- Reads/writes per-image sidecar metadata files.
- Normalizes and validates metadata at save time.
- Connects per-image metadata to archive-wide registries:
  - People
  - Tags
  - Locations
  - Crops

Sidecars remain:

```text
<photo filename>.dmpms.json
```

### 2.2 dMPP ↔ dMPS

dMPP prepares content for dMagy Picture Show (dMPS):

- dMPS consumes curated images + sidecars.
- dMPP ensures the archive is consistently structured so dMPS can remain simple and fast.
- dMPSv2 intent is to primarily consume **virtual crops** stored in sidecars, not depend on exported crop files for its core pipeline.

---

## 3. Core Workflow Model

### 3.1 Metadata-first editing

dMPP is primarily a metadata editor with strong rules:

- Per-image metadata is authoritative for what is in each photo.
- Archive registries provide canonical vocabularies and IDs.
- Save-time normalization keeps the archive consistent over years of edits.

### 3.2 Folder-based review

Users browse a folder tree under the selected Picture Library Folder / archive root:

- Optional include subfolders.
- Review filtering:
  - All Pictures
  - Never Reviewed
  - Flagged
- Per-photo editing occurs in a consistent editor shell.

### 3.3 Current editor layout

- Image / crop preview remains on the left.
- Metadata remains on the right.
- The app layout should not be flipped unless there is a strong reason later.

---

## 4. Technical Architecture

### 4.1 Application entry

- App owns shared stores.
- Stores are injected using `environmentObject`.
- Design rule: no view should silently create its own store instance.

Primary app file:

```text
DMagy_Picture_PrepApp.swift
```

### 4.2 Archive Root Gate + configuration

- App launches into an Archive Root Gate until the user selects a valid Picture Library Folder.
- Archive selection is persisted via a security-scoped bookmark.
- After selection, stores are configured to read/write under the chosen root.
- Local development should happen from a local folder, not from a Dropbox-synced working copy.

### 4.3 Editor shell

Primary editor file:

```text
DMPPImageEditorView.swift
```

Responsibilities include:

- folder selection / scan
- photo list / active photo
- crop preview
- metadata editing panels
- save / dirty state
- coordination with stores and sidecar metadata

### 4.4 ViewModel

ViewModels should be thin coordinators:

- Assemble view state from stores.
- Provide intent-level actions such as save, add tag, export crop.
- Avoid duplicating normalization rules that belong in stores / model layer.

---

## 5. Portable Archive

Portable data lives under the selected archive root in:

```text
<Picture Library Folder>/
  dMagy Portable Archive Data/
```

Typical subfolders:

```text
People/
Locations/
Tags/
Crops/
_locks/
_meta/
_indexes/
```

### 5.1 Portable archive contains

- People registry
- Tags registry
- Locations registry
- Crop presets / vocab where applicable
- Locks / metadata / indexes as needed

### 5.2 Per-image sidecars contain

- per-photo people assignments
- tags
- location
- date/date range
- crop intent
- GPS
- face assignments / ignored faces
- other photo-specific metadata

### 5.3 Picture Library Folder changes

Backlog priority:

Handle Picture Library Folder changes safely:

- Keep portable archive folder naming fixed as:

```text
dMagy Portable Archive Data
```

- Detect whether a newly selected root already contains portable archive data.
- If missing, avoid silently creating an empty “new archive” experience that makes People / Locations / Tags / Crops appear lost.
- Consider options:
  - create new portable data
  - copy from previous root
  - cancel root switch
- Long-term: consider migration or merge behavior only with clear user confirmation.

---

## 6. People & Identity System

### 6.1 People truth layers

- Canonical people / identities live in the portable People registry.
- Per-photo people records live in the sidecar.
- `peopleV2` remains the primary downstream source of truth for who is in the photo.

### 6.2 Manual people-in-photo

- `peopleV2` is authoritative per image.
- Manual workflow uses row-based assignment.
- Manual row behavior is currently acceptable even if an extra blank row is saved at the end.
- Toggling to Suggested and back can be used to clear current Manual row state and start over.

### 6.3 Suggested people-in-photo

Suggested mode combines:

- detected face boxes
- numbered face slots
- recognition suggestions
- confidence percentages
- active slot selection
- accept suggestion
- ignore face
- ignore other faces
- clear assignment
- one-off person assignment
- save-only face learning

### 6.4 Face slot metadata

Per-photo metadata may include:

```text
peopleMethod
faceAssignments
ignoredFaceNumbers
```

`peopleMethod` values:

```text
manual
faces
```

`faceAssignments` format:

```text
"1": "id:<personID>"
"2": "oneoff:<label>"
```

Rules:

- Keys are slot numbers as strings.
- Preferred values:
  - `id:<personID>`
  - `oneoff:<label>`
- Legacy values may be tolerated.
- New saves should write prefixed values.
- `ignoredFaceNumbers` stores visible face slots intentionally ignored.

### 6.5 Derived peopleV2 rule

When face assignments exist, save writes:

- `faceAssignments`
- `ignoredFaceNumbers`
- derived `peopleV2`

Rule:

`peopleV2` remains the “who is in the photo” list for downstream apps. Face slots add richer dMPP workflow structure but should be safe for simpler consumers to ignore.

### 6.6 Face learning safety

- Face learning occurs on Save only.
- Reset learned samples for a person exists.
- Current wrong-match recovery is acceptable for now.
- Future possibility:
  - per-sample face-learning review
  - better source photo review tooling
  - explicit “wrong match” workflow if reset-only proves insufficient

---

## 7. Date & Age Handling

### 7.1 Canonical rule: dates are ranges

All dates are treated as ranges:

- start
- end
- single-day: start = end

Supported user-entered formats include:

```text
YYYY-MM-DD
YYYY-MM
YYYY
YYYYs
YYYY-YYYY
YYYY-MM to YYYY-MM
```

Ranges using `" to "` can also be composed from supported forms.

### 7.2 Strict numeric validation

Date validation must reject normalized invalid dates.

Example:

```text
1985-75
```

must not silently become a later valid date.

### 7.3 Warning rule

Only show a red warning when user input:

- looks like a supported numeric date format
- and is invalid

Do not show red warnings for other free-text date/era entries.

### 7.4 Age calculations

Age display must refresh on:

- row selection changes
- date/dateRange edits
- people edits
- metadata sourceFile change where applicable

Derived age should be computed from:

- stored photo date range
- canonical person DOB range

---

## 8. Locations

### 8.1 Truth model

Locations follow the same general principle as Tags:

- Portable Locations registry is canonical.
- Per-photo location assignment lives in sidecar metadata.
- Editor should encourage reuse of saved locations.

### 8.2 Current GPS behavior

When a picture has GPS:

- dMPP may reverse-geocode address fields.
- Initial GPS fill should behave like “Reset to GPS.”
- If the reverse-geocoded result matches a saved Location, dMPP applies saved:
  - shortName
  - description
  - streetAddress
  - city
  - state
  - country

### 8.3 Near-address correction

If reverse geocoding returns a nearby but slightly wrong address, dMPP can match a saved Location when:

- street name matches
- city matches
- state matches
- country matches
- house number differs only slightly

Current example:

```text
GPS resolves: 1030 High Meadow Ct
Saved location: 1026 High Meadow Ct
```

Saved Location should win for archive consistency.

### 8.4 Future location improvements

- Consider subtle UI note when a saved Location was applied from a nearby GPS result.
- Consider adding GPS coordinates to saved Locations for stronger distance-based matching.
- Location manager UX should eventually reach parity with People manager.
- Bulk apply location to selected photos remains planned.

---

## 9. Tags

### 9.1 Truth model

- Tags are stored in portable JSON under the portable archive.
- Editor UI should present canonical tags consistently.
- Reserved tags exist and cannot be renamed/deleted, though descriptions may be editable.

Known reserved tags:

```text
Do Not Display
Flagged
```

### 9.2 Current status

- Tag descriptions and portability are implemented.
- Continue refining only as needed.
- Tags “Linked file (advanced)” should remain aligned with People / General behavior.

### 9.3 Future tag improvements

- Apply tags to selection.
- Batch tag operations more broadly.

---

## 10. Crops

### 10.1 Current truth: virtual crops

Per-photo virtual crops represent editing intent and are stored in sidecar metadata.

### 10.2 Export crops

Export crops are for personal downstream use outside dMPS:

- sharing
- printing
- sending to family
- other direct use

### 10.3 Current UI status

- Crop header polish has been done.
- New Crop popover styling has been refined.
- Crop drag / slider performance has been improved via decoded image caching.

### 10.4 Planned crop improvements

- Re-examine New Crop menu structure.
- Headshot (Tight) / Headshot (Full) per-person tabs.
- Grouping behavior in crop strip.
- Move crop presets fully to portable JSON.

### 10.5 Planned headshot model

Future intended model:

```text
crop.kind = .headshot
crop.variant = tight | full
crop.personID = required
crop.displayLabel = "<ShortName> — Headshot (Tight)"
```

Rules / decisions:

- No headshot without a person.
- Person link is not editable.
- If a person is deleted, UI should show headshot crops as missing person while preserving sidecar personID.
- Only one headshot per person per type.
- No automatic headshot defaults; headshots only appear when added.
- Headshots should be grouped by variant and person.

---

## 11. Save semantics & dirty tracking

- Dirty state tracks unsaved editor changes.
- Save triggers normalization, then writes sidecar updates atomically.
- Dirty tracking includes face-mode fields.
- Save / Previous / Next should respect required face assignment/ignore state in Suggested mode.
- Clearer save / dirty indicators remain a high-priority UX item.

---

## 12. Snapshots

Snapshots exist to prevent “oops” events:

- Capture last-known-good metadata state.
- Provide rollback paths during risky edits.
- Use versioning points only for risky refactors or code-moving work.

---

## 13. Backlog / Current Priorities

Work one item at a time.

### 13.1 High Priority

#### Portable Archive / UX

- Handle Picture Library Folder changes safely.
- First-run instruction window / help.
- Review `_Read_Me_` and add examples.
- Validation / health indicators:
  - missing dates
  - missing crop
  - missing people / unreviewed people
  - unresolved or missing references
- Clearer save / dirty status indicators.

#### Performance

- Faster folder scanning.
- Thumbnail caching.
- Continue to favor correctness and UI stability over premature optimization.

#### Locations

- Location manager UX parity with People manager.
- Improve GPS-derived location confidence and correction.
- Bulk apply location to selection.

#### Tags

- Continue refining tag descriptions / portability as needed.
- Keep Tags linked-file behavior aligned with People / General.

#### Editor / File Opening

- Ability to open an image directly from Finder / browser into dMPP.

#### Metadata Source Indicators

- Add indicators showing whether date and location came from:
  - image metadata
  - sidecar data
  - user edits
  - saved registry matching

---

## 14. Watch List / Complete for Now

### Face Recognition / Matching Quality

- Suggestion thresholds feel acceptable after real-world batch testing.
- Confidence % display currently feels acceptable.
- Adding short names to face box overlays was investigated and intentionally declined for dMPP.

### Face Recognition / Workflow

- Reset-person workflow is acceptable for wrong-match recovery for now.
- Continue watching whether a stronger explicit “wrong match” workflow becomes necessary.

### UI / Layout

- Continue watching right-column spacing / scrollbar breathing room.
- Manual row behavior is acceptable for now.
- Suggested / Manual now feel closer to the same design system after UI polish.

### Data Integrity

- Missing-reference handling when sidecar IDs are no longer in the registry remains on the watch list.

---

## 15. Recently Completed

### Locations

- Fixed GPS-derived location loading so matching saved Locations also apply saved Location descriptions.
- Added near-address matching for cases where GPS resolves to a neighboring house number.
- Updated saved-location enrichment so saved Location can overwrite reverse-geocoded street address when a saved match is found.

### People UI / Suggested + Manual Polish

- Moved People mode help icon into the People GroupBox title row.
- Removed duplicated help icon spacing from Suggested and Manual.
- Tightened vertical spacing between Suggested instructions and Faces.
- Restyled Suggested face chips to align more closely with Manual pills.
- Changed Suggested face chips from rigid two-column layout to content-sized wrapping chips.

### Face Recognition / Auto-Detect Safety

- Moved face learning to Save only.
- Added reset learned face samples for a person.
- Audited current face-learning data for contamination.
- Verified stale face suggestions do not leak between pictures.
- Required visible face chips to be assigned or ignored before Save / Previous / Next.
- Investigated whether bad accepted suggestions may have polluted the face index.

### Image / Crop Performance

- Resolved crop drag and crop slider jerkiness by caching a decoded image in the editor view model.
- Continued batch-testing responsiveness across a variety of real photo sets.

### Crop UI

- Rearranged crop header so crop chips and New Crop sit on the same row.
- Moved crop actions to the upper right.
- Changed New Crop from native Menu button to button/popover.
- Refined New Crop popover row height and styling.

### People UI / Checklist

- Added Ignore Other Faces for remaining unassigned visible faces in Suggested mode.
- Added `fatherID`, `motherID`, and `gender` as shared person-level fields.
- Fixed date-derived-state sync so photo metadata properly filters the people checklist.
- Added stable tie-break sorting for duplicate short names in the People checklist using birth date, then full name, then person ID.
- Removed birth-date differentiators from Suggested / Auto-Detect chips.
- Reset startup review mode/navigation state so relaunch always starts in All Pictures.

### Prior CTX15 Punchlist Items

- Locations added/deleted in Settings now update editor UI sufficiently to move from active punchlist.
- Tags added/deleted in Settings now update editor UI sufficiently to move from active punchlist.
- Removed “Are you sure?” confirmation when deleting a crop.
- Added ability to create one-off headshots.
- Next picture moves focus / scrolls to Title.

---

## 16. Known Limitations and Open Decisions

- Picture Library Folder root switching needs safer UX.
- First-run help / instruction experience still needs design.
- Source indicators for date/location need implementation.
- Open image from Finder / browser remains pending.
- Missing-reference handling still needs a user-facing strategy.
- Face recognition review tooling may eventually need per-sample visibility.
- Separate Person core from Identity versions remains a future architecture refactor.

---

## 17. Build Environment

Current known environment:

```text
macOS: 26
Xcode: 26.2 (17C52)
```

---

## 18. Collaboration Rules

Operational rules for Dan + ChatGPT:

- Assume Dan is a designer learning to code, not a deep Swift expert.
- Prefer full-file paste-over when practical.
- Avoid splice edits unless unavoidable.
- Always provide exact paste targets.
- Use numbered checklists for code changes.
- Use `// MARK:` headers consistently.
- Add plain-English file headers gradually when files are touched.
- Start multi-file work with:
  1. Goal
  2. Approach
  3. N files affected
  4. Risks
  5. Rollback plan
- Add Git/versioning points only for risky refactors or code-moving work.
- Keep changes small and resumable.
