# dMPP-Context-v17.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2026-05-15-CTX17  
**Supersedes:** dMPP-2026-04-24-CTX16  
**Status:** Post-1.0 launch-readiness / v2.0 planning context

---

## 0. What changed since CTX16

### 0.1 Reality / Implemented

#### dMPMS public release baseline

- dMPMS v1.0 is the first public version of the dMagy Photo Metadata Standard.
- dMPP writes:

```text
dmpmsVersion: "1.0"
```

- `privateNotes` was renamed to `curatorNotes` before public release.
- Public dMPMS documentation removes implementation-rationale sections and focuses on the sidecar standard.
- dMPMS sidecars remain human-readable.
- dMPMS is licensed under CC BY 4.0.
- Public / repo documentation includes:
  - `Docs/dMPMS/dMPMS-v1.0.md`
  - example sidecars
  - overview content for `dmagy.com/dmpms`

#### Launch-readiness work completed

The 1.0 launch-readiness checklist has been completed or cleared for submission:

1. Privacy Policy / App Store Privacy — Complete
2. Folder Access / First-Run Clarity — Complete
3. Sandbox / Entitlements Review — Complete
4. Failure-State Testing — Complete
5. dMPMS Publishing — Complete
6. Help / README Alignment — Complete
7. Sample Archive / Screenshots — Complete
8. App Review Notes — Complete
9. Final Data-Safety Pass — Complete
10. Release Build / Distribution Check — Upload complete / App Store submission flow in progress

#### Privacy / App Store privacy posture

- dMPP does not upload photos, metadata, face data, or settings.
- dMPP does not use analytics, advertising, tracking, user accounts, cloud sync, remote storage, or custom crash reporting.
- App Store privacy answer: **Data Not Collected**, assuming no future network/data collection behavior is added.
- Privacy policy now distinguishes between:
  - local app-created/user-created information
  - data transmitted to dMagy

#### Folder access / first-run clarity

First-run wording was adjusted toward non-technical users:

```text
Choose the main folder for the picture collection you plan to prepare. dMPP will save its notes, people, places, tags, and crop choices inside that folder so everything stays together.
```

Intent:

- Avoid leading with terms like archive, sidecar, metadata, and registry.
- Help users choose the correct parent folder instead of a narrow subfolder.
- Prepare users for dMPP creating local support files in the selected folder.

#### Sandbox / entitlements

Expected sandbox posture:

- App Sandbox: enabled
- Hardened Runtime: enabled
- User Selected Files: Read/Write
- Audio Input: enabled for optional speech-to-text description entry
- Microphone and Speech Recognition usage descriptions: present
- Network incoming/outgoing: disabled
- Camera, contacts, location, calendar, printing, USB, and unused capabilities: disabled
- No temporary sandbox exceptions expected

#### Failure-state testing

Failure-state testing completed for:

- Missing / deleted Picture Library Folder
- Renamed Picture Library Folder
- Picture Library Folder moved to Trash
- Deleted portable archive subfolders: Tags and Locations
- Invalid `.dmpms.json` sidecar
- Deleted image while app is open
- Locked sidecar / save failure
- Deleted entire `dMagy Portable Archive Data` folder

Results:

- No crashes found.
- Missing portable archive folders are recreated when dMPP has valid write access.
- Stale macOS folder access can prevent writes until the user refreshes folder access.
- Save failure is blocked with a clear user-facing message.
- Invalid sidecars now show a warning and are backed up before replacement.
- Deleted/missing images remain navigable, though the current message is generic.

Known minor polish:

- Missing/deleted image currently shows “No image or crop selected.” Later improvement: show a more specific moved/deleted picture message.

#### Invalid sidecar handling

When a `.dmpms.json` sidecar exists but cannot be decoded:

- dMPP does not crash.
- dMPP shows a user-facing warning.
- The original picture remains unchanged.
- If the user saves, dMPP backs up the unreadable sidecar before replacing it with valid JSON.
- User-facing wording uses “saved information” rather than “unreadable notes file.”

Example behavior:

```text
dMPP found saved information for this picture, but could not read it. Your original picture was not changed. If you save, dMPP will keep a backup of the unreadable file and create a new saved information file.
```

#### App Store metadata / product positioning

Current product positioning:

```text
Name: dMagy Picture Prep
Subtitle: More meaning, same pictures.
Promotional text: Prepare your photo collection locally with notes, people, places, tags, and crops—without changing your original pictures.
```

Category recommendation:

```text
Primary: Photo & Video
Secondary: Productivity
```

Pricing decision:

```text
dMPP: Free
dMPS: $2.99 / $3
```

Reasoning:

- dMPP should reduce adoption friction and encourage dMPMS use.
- dMPS has a clearer immediate paid utility value.

#### App Store upload issue resolved

During release upload, App Store Connect rejected an archive due to invalid `CFBundleDocumentTypes` configuration.

Resolution:

- The issue was not in `project.pbxproj`.
- The project file pointed to `dMagy-Picture-Prep-Info.plist`.
- Broken/unneeded Document Types were removed from the plist.
- Upload then succeeded.

For v1.0:

- dMPP does not need Finder document-opening behavior.
- Do not add Document Types unless a tested “Open With dMPP” workflow is intentionally implemented later.

---

## 1. Purpose of dMagy Picture Prep

**dMagy Picture Prep (dMPP)** is a macOS Swift / SwiftUI application for preparing a personal photo collection to be:

- **Structured** — portable archive folder, registries, consistent IDs
- **Searchable** — tags, people, locations, dates/ranges
- **Display-ready** — virtual crops and future downstream display behavior
- **Durable** — metadata lives with the collection, not trapped on one machine

Primary goal:

```text
Make photo curation repeatable, not heroic.
```

Product promise:

```text
More meaning, same pictures.
```

Core dMPMS promise:

```text
The original picture stays untouched.
The meaning travels beside it.
```

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

Sidecars use this naming convention:

```text
<photo filename>.dmpms.json
```

A dMPMS v1.0 sidecar requires only:

```text
dmpmsVersion
sourceFile
```

### 2.2 dMPP ↔ dMPS

dMPP prepares content for dMagy Picture Show (dMPS):

- dMPS can consume curated images + sidecars.
- dMPP ensures the archive is consistently structured so dMPS can remain simple and fast.
- dMPS v2 intent is to primarily consume **virtual crops** stored in sidecars, not depend on exported crop files for its core pipeline.

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
dMagy_Picture_PrepApp.swift
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

Portable data lives under the selected Picture Library Folder in:

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
- FaceIndex / learned face data where applicable
- Locks / metadata / indexes as needed

### 5.2 Per-image sidecars contain

- per-photo people assignments
- tags
- location
- date/date range
- crop intent
- GPS
- face assignments / ignored faces
- curator notes
- other photo-specific metadata

### 5.3 Picture Library Folder changes

Implemented / current:

- “Change or Refresh Picture Library Folder…” language exists.
- Refresh Access path exists for stale macOS / cloud-folder permissions.
- Warning exists before creating new portable archive data when the selected folder does not already contain it.
- Full copy/merge migration is deferred until there is a real use case.

Future:

- Better diagnostics when dMPP can see the path but cannot write inside it.
- Avoid misleading messages when the real issue is stale folder permission.
- Potential lightweight access repair UI.

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

```text
peopleV2 remains the “who is in the photo” list for downstream apps.
Face slots add richer dMPP workflow structure but should be safe for simpler consumers to ignore.
```

### 6.6 Face learning safety

- Face learning occurs on Save only.
- Reset learned samples for a person exists.
- Current wrong-match recovery is acceptable for now.
- Future possibility:
  - per-sample face-learning review
  - source photo review tooling
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
- Unknown tag handling and repair actions exist.
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
- Consider smarter initial headshot crop placement from detected face boxes.

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
- Going to the next picture saves automatically.

---

## 12. Snapshots and versioning points

Snapshots exist to prevent “oops” events:

- Capture last-known-good metadata state.
- Provide rollback paths during risky edits.
- Use versioning points only for risky refactors or code-moving work.

Versioning point rule:

```text
Use Git checkpoint / rollback guidance only for refactors or moving code around.
```

---

## 13. Version 2.0 Planning Backlog

### 13.1 Version 2.0 theme

```text
Bulk Work and Archive Health
```

Version 1.0 established the foundation: local sidecars, portable archive data, people, locations, tags, crops, face suggestions, help, and App Store readiness.

Version 2.0 should focus on making dMPP faster, safer, and more useful for working through real photo collections at scale.

### 13.2 High-priority v2.0 candidates

#### Bulk Operations

Goal: help users apply repeated information without editing every picture one at a time.

Possible work:

- Apply location to selected pictures.
- Apply tags to selected pictures.
- Apply people to selected pictures where appropriate.
- Batch mark pictures as Flagged or Do Not Display.
- Batch clear or replace a location/tag.
- Batch save/update sidecars safely.

Why it matters:

- This is the clearest productivity upgrade for large collections.
- It makes dMPP feel less like “one picture at a time forever.”

#### Archive Health / Diagnostics

Goal: give users a clear way to understand whether their picture collection and dMPP data are healthy.

Possible checks:

- Missing or unreadable `.dmpms.json` sidecars.
- Invalid sidecar JSON.
- Missing People / Locations / Tags references.
- Missing or unreadable `dMagy Portable Archive Data`.
- Permission problems with the selected Picture Library Folder.
- Registry files readable/writable:
  - People
  - Locations
  - Tags
  - Crops
  - FaceIndex
  - `_locks`
- Sidecars with unknown tags or missing people references.
- Pictures with missing dates, people, tags, or crops, depending on user-selected goals.

#### Folder Access Recovery Improvements

Goal: make stale macOS / cloud folder permission problems easier for normal users to recover from.

Possible work:

- Detect when dMPP can see the saved Picture Library Folder path but cannot write inside it.
- Show a clear “Refresh Picture Library Folder Access…” message.
- Offer a one-click path to reselect the same folder.
- Avoid misleading messages when the real problem is folder access.
- Add a lightweight access check for portable archive folders.

Suggested message:

```text
dMPP needs permission to save inside your Picture Library Folder. Choose the folder again to refresh access.
```

#### Location Manager UX Parity

Goal: bring Locations closer to the polish and clarity of People Settings.

Possible work:

- Improve Locations Settings layout.
- Make saved locations easier to review, edit, and reuse.
- Improve linked-file / advanced information if needed.
- Show clearer confidence when GPS-derived data matched a saved location.
- Consider adding GPS coordinates to saved Locations for better distance-based matching.

### 13.3 Medium-priority v2.0 candidates

#### Crop System 2.0

Possible work:

- Move crop presets fully to portable JSON.
- Improve crop preset editing.
- Add better reusable crop definitions.
- Revisit smarter initial headshot crop placement from detected face boxes.
- Improve crop/export/delete action layout if it still feels visually bolted on.
- Consider crop quality warnings, such as “this crop may be too small for display.”

#### Face Review and Learning Tools

Possible work:

- Per-sample face-learning review instead of only reset-all-for-person.
- Show source photo for learned samples.
- Add a clearer “wrong suggestion” recovery path.
- Continue tuning high-confidence mismatch thresholds after real-world testing.
- Consider better explanation for why a suggestion appeared.

#### Help System Improvements

Possible work:

- Add search to dMPP Help.
- Add “Open full Help topic…” links from section help popovers.
- Improve Markdown rendering for:
  - bold text
  - inline code
  - links
  - nested lists
- Add screenshots once the UI stabilizes.

#### Performance and Responsiveness

Possible work:

- Faster folder scanning.
- Thumbnail caching.
- Avoid blocking the main thread during large-folder operations.
- Improve perceived loading state.
- Consider background preloading for adjacent pictures.
- Continue to favor correctness and UI stability ahead of premature optimization.

### 13.4 Lower-priority / enabling work

#### Editor Decomposition / Maintainability

Goal: carefully reduce the size and complexity of `DMPPImageEditorView.swift` after launch.

Possible extractions:

- Title / Description / Curator Notes section.
- Tags section.
- Location section.
- People section.
- Crop header/actions.
- File/folder toolbar helpers.
- Save/navigation command handling.

Rules:

- Do not do broad refactors without a clear reason.
- Keep extractions small and reversible.
- Use versioning checkpoints before each extraction.
- Preserve `// MARK:` anchors.

#### Accessibility Review

Possible work:

- Test onboarding, Settings, Help, editor fields, crop controls, people assignment, and navigation with VoiceOver.
- Add accessibility labels to custom controls.
- Review Voice Control behavior.
- Review contrast and color-only status indicators.
- Review Dark Mode.
- Revisit App Store accessibility declarations only after verified support.

---

## 14. Watch List / Complete for Now

### Face Recognition / Matching Quality

- Suggestion thresholds feel acceptable after real-world batch testing.
- Confidence % display currently feels acceptable.
- Adding short names to face box overlays was investigated and intentionally declined for dMPP.
- Monitor for repeated false positives or user misunderstanding of confidence.

### Face Recognition / Workflow

- Reset-person workflow is acceptable for wrong-match recovery for now.
- Continue watching whether a stronger explicit “wrong match” workflow becomes necessary.

### UI / Layout

- Continue watching right-column spacing / scrollbar breathing room.
- Manual row behavior is acceptable for now.
- Suggested / Manual now feel closer to the same design system after UI polish.

### Data Integrity

- Missing-reference handling when sidecar IDs are no longer in the registry remains on the watch list.
- Watch for missing location references, crop references, and face sample references to deleted people.

---

## 15. Recently Completed / Version 1.0 Foundation

### Launch readiness

- Privacy policy updated for dMPP behavior.
- App Store Privacy answer aligned to Data Not Collected.
- Folder access / first-run clarity reviewed and improved.
- Sandbox / entitlements reviewed.
- Failure-state testing completed.
- dMPMS publishing completed.
- Help / README alignment completed.
- Sample archive / screenshots prepared.
- App Review Notes prepared.
- Final data-safety pass completed.
- Release upload succeeded after resolving App Store account and Document Types issues.

### dMPMS Standard / Publishing

- Formalized dMPMS v1.0 as the first public sidecar metadata standard.
- Separated the public sidecar standard from dMPP-specific implementation details.
- Documented required, optional, display-facing, curator-facing, and workflow/app-private fields.
- Renamed `privateNotes` to `curatorNotes` before public release.
- Confirmed `description` is display-facing and `curatorNotes` is curator-facing.
- Included examples for basic sidecars, people, dates/date ranges, GPS/location, tags, virtual crops, headshots, workflow fields, and curator notes.
- Chose `dmpmsVersion: "1.0"` for the first public release.
- Clarified migration expectations for older internal-draft sidecars.
- Licensed the specification under CC BY 4.0.

### People Settings

- Fixed Add Event flow so unsaved original person fields are committed before adding an identity event.
- Prevents new-person draft details from being lost when an event is added immediately.

### People UI / Suggested + Manual Polish

- Moved People mode help icon into the People GroupBox title row.
- Removed duplicated help icon spacing from Suggested and Manual.
- Tightened vertical spacing between Suggested instructions and Faces.
- Restyled Suggested face chips to align more closely with Manual pills.
- Changed Suggested face chips from rigid two-column layout to content-sized wrapping chips.
- Added Ignore Other Faces for remaining unassigned visible faces in Suggested mode.
- Added “No faces found” message when Suggested mode detects no faces.

### Face Recognition / Auto-Detect Safety

- Moved face learning to Save only.
- Added reset learned face samples for a person.
- Audited current face-learning data for contamination.
- Verified stale face suggestions do not leak between pictures.
- Required visible face chips to be assigned or ignored before Save / Previous / Next.
- Investigated whether bad accepted suggestions may have polluted the face index.

### Locations

- Fixed GPS-derived location loading so matching saved Locations also apply saved Location descriptions.
- Added near-address matching for cases where GPS resolves to a neighboring house number.
- Updated saved-location enrichment so saved Location can overwrite reverse-geocoded street address when a saved match is found.

### Image / Crop Performance

- Resolved crop drag and crop slider jerkiness by caching a decoded image in the editor view model.
- Continued batch-testing responsiveness across a variety of real photo sets.

### Crop UI

- Rearranged crop header so crop chips and New Crop sit on the same row.
- Moved crop actions to the upper right.
- Changed New Crop from native Menu button to button/popover.
- Refined New Crop popover row height and styling.
- Added Crop help/info popover.
- Temporarily hide face boxes while viewing/editing headshot crops.

### Help / Getting Started

- Added traditional in-app dMPP Help window.
- Bundled Markdown help topics in the app target.
- Added Help > dMPP Help menu item.
- Added topic sidebar and lightweight Markdown rendering.
- Moved Getting Started into its own view file.
- Simplified Getting Started into a setup-first guide.
- Kept Getting Started available from Help > Getting Started.

### Data Integrity

- Added unknown tag repair actions for tags saved in a sidecar but missing from Settings.
- Added People missing-reference warning.
- Automatically preserves orphaned People reference details in curator notes so they are not lost on save/navigation.
- Invalid sidecars now warn users and preserve a backup before replacement.

---

## 16. Known Limitations and Open Decisions

- Missing/deleted image message remains generic.
- Source indicators for date/location need implementation.
- Open image from Finder / browser remains pending.
- Full diagnostics panel remains future work.
- Missing-reference handling still needs broader user-facing strategy.
- Face recognition review tooling may eventually need per-sample visibility.
- Separate Person core from Identity versions remains a future architecture refactor.
- App Store accessibility support should not be claimed until common tasks are tested with the relevant accessibility feature.

---

## 17. Build Environment

Current known environment:

```text
macOS: 26
Xcode: 26.2 (17C52)
```

Build / release notes:

- Version 1.0.
- Build 1 uploaded successfully unless a later build number was incremented.
- If uploading another archive for version 1.0, increment the build number.

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
- For v2.0 work, prefer one backlog item at a time.

---

## 19. Context File Maintenance

Recommended active-doc strategy:

- Keep this file as the current active AI context.
- It is okay to remove older context files from the active project view after CTX17 is committed.
- Do not permanently lose history if it is useful; Git history is enough for most prior context versions.
- If retaining older versions in the repo, move them to an archive folder rather than keeping all old versions in the active context area.

Practical recommendation:

```text
Keep: dMPP-Context-v17.md as active context
Optional archive: dMPP-Context-v16.md
Remove from active working set: older CTX files that are already superseded and available through Git history
```
