# dMPP Backlog

**dMagy Picture Prep — Living Backlog & Planning Notes**  
**Last updated:** 2026-05-15  
**Current release posture:** Version 1.0 submitted / launch-readiness complete  
**Current planning theme:** Version 2.0 — Bulk Work and Archive Health

---

## Purpose

This backlog is Dan’s living idea and planning document for dMagy Picture Prep.

Use this file to capture:
- near-term work
- version 2.0 candidates
- deferred ideas
- watch-list items
- recently completed work
- ideas that should not be lost, even if they are not ready yet

This document is allowed to be more fluid than the main context file.

For current architecture, implementation reality, and durable project context, use:

```text
Docs/dMPP/dMPP-Context-v17.md
```

For shared working rules, use:

```text
Docs/dMagy Project Collaboration Guide.md
```

---

## Backlog Rules

- Keep ideas here even if they are not ready to implement.
- Move items between sections as they become clearer.
- Do not treat every idea as a commitment.
- When an item becomes an implementation task, clarify:
  - goal
  - expected user value
  - likely files affected
  - risk level
  - test plan
- When an item becomes obsolete, move it to **Parking Lot / Deferred** or remove it after a commit.

---

# Now / Next

These are the most likely next areas to consider after the 1.0 launch settles.

## 1. Post-Launch Observation

Watch for real-user friction around:
- choosing the correct Picture Library Folder
- understanding `.dmpms.json` sidecars
- understanding `dMagy Portable Archive Data`
- folder permission refresh
- face suggestions and wrong-match recovery
- save / dirty state clarity
- large-folder performance

Definition of done:
- Collect enough real usage or personal batch-testing notes to identify the first meaningful 1.1 / 2.0 target.

---

## 2. Folder Access Recovery Messaging

Improve messaging when macOS, cloud storage, or folder movement causes stale access.

Known scenario:
- dMPP can still show the selected Picture Library Folder path.
- Writes to People / Locations / Tags / Crops fail with “Operation not permitted.”
- Refreshing access by selecting the same folder again resolves the issue.

Possible user-facing message:

```text
dMPP needs permission to save inside your Picture Library Folder. Choose the folder again to refresh access.
```

Possible work:
- Detect read/write failure inside the selected Picture Library Folder.
- Offer “Refresh Picture Library Folder Access…” from the error state.
- Avoid misleading messages such as “Settings are currently being edited” when the real issue is folder access.
- Add lightweight checks for portable archive folders.

Priority: High

---

## 3. Missing / Deleted Image Message Polish

Current behavior:
- If a selected image is deleted outside dMPP, the app does not crash.
- Navigation continues.
- The app currently shows a generic “No image or crop selected” message.

Possible improvement:

```text
This picture is no longer available. It may have been moved or deleted. Choose another picture or refresh the folder.
```

Priority: Low / Medium

---

# Version 2.0 Candidates

## Version 2.0 Theme

**Bulk Work and Archive Health**

Version 1.0 establishes the foundation:
- local sidecars
- portable archive data
- people
- locations
- tags
- crops
- face suggestions
- help
- App Store readiness

Version 2.0 should make dMPP more useful for real photo collections at scale.

---

## 1. Bulk Operations

Goal: Help users apply repeated information without editing every picture one at a time.

Possible work:
- Apply location to selected pictures.
- Apply tags to selected pictures.
- Apply people to selected pictures where appropriate.
- Batch mark pictures as `Flagged`.
- Batch mark pictures as `Do Not Display`.
- Batch clear a location.
- Batch replace a location.
- Batch add or remove tags.
- Batch save/update sidecars safely.

Why it matters:
- Large photo collections often have repeated context.
- This is the clearest productivity upgrade after 1.0.
- It reduces the feeling of “one picture at a time forever.”

Definition of done:
- User can select multiple pictures and apply at least one safe, reversible metadata change.
- dMPP writes valid dMPMS sidecars for all affected pictures.
- Errors are reported clearly without silently skipping files.

Priority: High

---

## 2. Archive Health / Diagnostics

Goal: Give users a clear way to understand whether their picture collection and dMPP data are healthy.

Possible checks:
- Missing or unreadable `.dmpms.json` sidecars.
- Invalid sidecar JSON.
- Sidecars that use older internal dMPMS draft versions.
- Missing People references.
- Missing Location references.
- Unknown Tags.
- Missing or unreadable `dMagy Portable Archive Data`.
- Registry files readable/writable:
  - People
  - Locations
  - Tags
  - Crops
  - FaceIndex
  - `_locks`
- Permission problems with the selected Picture Library Folder.
- Pictures missing dates, people, tags, locations, or crops, depending on user-selected goals.

Possible UI:
- Settings > Archive Health
- Help menu item: “Check Archive Health…”
- Summary badges:
  - Good
  - Needs attention
  - Could not check

Why it matters:
- Builds trust.
- Helps users recover when files are moved, synced, deleted, or hand-edited.
- Makes dMPP feel safer for long-term archives.

Definition of done:
- User can run a health check.
- Results are plain-English and actionable.
- Original pictures are never modified by a health check.

Priority: High

---

## 3. Folder Access Recovery Improvements

Goal: Make stale macOS / cloud-folder permission issues easy for normal users to recover from.

Possible work:
- Detect when dMPP can see the saved Picture Library Folder path but cannot write inside it.
- Show a clear refresh-access message.
- Let the user reselect the same Picture Library Folder.
- Re-run portable archive bootstrap after access is refreshed.
- Add a small “access OK / needs refresh” indicator in Settings > General.

Priority: High

---

## 4. Location Manager UX Parity

Goal: Bring Locations closer to the polish and clarity of People Settings.

Possible work:
- Improve Locations Settings layout.
- Make saved locations easier to review, edit, and reuse.
- Add or polish “Linked file (advanced)” behavior if needed.
- Improve confidence handling when GPS-derived data matches a saved location.
- Consider subtle UI note when a saved Location was applied from a nearby GPS result.
- Consider adding GPS coordinates to saved Locations for stronger distance-based matching.
- Add bulk apply location to selected pictures.

Priority: High / Medium

---

## 5. Crop System 2.0

Goal: Make crops more powerful, portable, and easier to manage.

Possible work:
- Move crop presets fully to portable JSON.
- Improve crop preset editing.
- Re-examine New Crop menu structure.
- Add more aspect ratio presets.
- Improve crop/export/delete action layout if it still feels visually bolted on.
- Consider crop quality warnings, such as “this crop may be too small for display.”
- Revisit smarter initial headshot crop placement from detected face boxes.

Priority: Medium

---

## 6. Headshot Crop Improvements

Current status:
- One-off headshots exist.
- Face boxes are temporarily hidden while viewing/editing headshot crops.
- Smarter initial placement from detected face boxes was deferred.

Future intended model:
- `crop.kind = .headshot`
- `crop.variant = tight | full`
- `crop.personID = required`
- `crop.displayLabel = "<ShortName> — Headshot (Tight)"`

Rules / decisions:
- No headshot without a person.
- Person link is not editable.
- If a person is deleted, UI should show headshot crops as missing person while preserving sidecar personID.
- Only one headshot per person per type.
- No automatic headshot defaults.
- Headshots should appear grouped by variant and person.

Priority: Medium

---

## 7. Face Review and Learning Tools

Goal: Make face suggestions easier to inspect, repair, and trust over time.

Possible work:
- Per-sample face-learning review instead of only reset-all-for-person.
- Show the source photo for learned samples.
- Add a clearer “wrong suggestion” recovery path.
- Continue tuning high-confidence mismatch thresholds after more real-world testing.
- Consider better explainability for why a suggestion appeared.
- Consider a way to explicitly reject a wrong match if current workflows prove insufficient.

Current status:
- Reset-person workflow is acceptable for now.
- Inline warnings help users recover from deleted people and high-confidence mismatches.
- Confidence percentage display currently feels acceptable.
- Suggestion thresholds feel acceptable after real-world batch testing.

Priority: Medium

---

## 8. Help System Improvements

Goal: Make in-app Help easier to search and connect to the current screen.

Possible work:
- Add search to dMPP Help.
- Add “Open full Help topic…” links from section help popovers.
- Improve Markdown rendering for:
  - bold text
  - inline code
  - links
  - nested lists
- Consider screenshots once the UI stabilizes.

Priority: Medium

---

## 9. Performance and Responsiveness

Goal: Make large folders feel faster and smoother.

Possible work:
- Faster folder scanning.
- Thumbnail caching.
- Avoid blocking the main thread during large-folder operations.
- Improve perceived loading state.
- Consider background preloading for adjacent pictures.
- Continue favoring correctness and UI stability over premature optimization.

Priority: Medium

---

## 10. Editor Decomposition / Maintainability

Goal: Carefully reduce the size and complexity of `DMPPImageEditorView.swift` after launch.

Current decision:
- Large file size is a maintainability concern, not a 1.0 blocker.
- Do not refactor only because the file is long.
- Refactor when the size creates real editing risk, repeated confusion, or blocks feature work.

Possible extraction candidates:
- Title / Description / Curator Notes section.
- Tags section.
- Location section.
- People section.
- Crop header/actions.
- File/folder toolbar helpers.
- Save/navigation command handling.

Rules:
- Move one responsibility at a time.
- Preserve behavior first.
- Use `// MARK:` anchors before, during, and after extraction.
- Use a Git checkpoint before moving code.
- Test after each extraction.
- Avoid broad refactors without a clear rollback point.

Priority: Medium / Low

---

## 11. Accessibility Review

Goal: Improve support for users relying on macOS accessibility features.

Possible work:
- Test onboarding with VoiceOver.
- Test folder selection with VoiceOver.
- Test Settings and Help with VoiceOver.
- Test metadata editing with VoiceOver.
- Test people assignment and crop controls with VoiceOver.
- Add accessibility labels to custom controls.
- Review Voice Control behavior.
- Review contrast and color-only status indicators.
- Review Dark Mode.
- Revisit App Store accessibility declarations only after verified support.

Priority: Medium / Low

---

# Later / Maybe

## Open Image from Finder / Browser

Idea:
- Allow a user to open an image directly in dMPP from Finder or another app.

Notes:
- This may require a properly configured document type or file-opening flow.
- Do not add incomplete `CFBundleDocumentTypes`; App Store upload rejected an incomplete placeholder during 1.0 prep.
- Only revisit when the feature is intentionally designed and tested.

Priority: Later

---

## Metadata Source Indicators

Idea:
- Show whether date or location came from:
  - image metadata
  - sidecar data
  - user edits
  - saved registry matching

Why:
- Helps users trust dMPP’s suggestions.
- Especially useful for GPS-derived location corrections.

Priority: Later / Medium

---

## Person Core / Identity Versions Refactor

Idea:
- Separate Person core from Identity versions.

Notes:
- This is an architecture refactor.
- Only do this with a clear proposal, rollback plan, and user-visible reason.

Priority: Later

---

## Unknown → Identified Person Conversion

Idea:
- Improve workflow for turning unknown placeholders into known people.

Priority: Later / Medium

---

## Archive Migration / Merge

Idea:
- Provide guided options when a user changes Picture Library Folder and the new folder does not already contain portable archive data.

Possible options:
- create new portable data
- copy from previous root
- cancel root switch
- future merge behavior with clear confirmation

Priority: Later unless real users hit this frequently

---

# Watch List

## Face Matching Quality

Watch for:
- repeated false positives
- users misunderstanding confidence
- wrong suggestions that survive reset-person workflow
- need for explicit “wrong match” feedback
- need for per-sample review

Current status:
- Acceptable for 1.0.

---

## Data Integrity

Watch for:
- missing location references
- broken crop references
- learned face samples pointing to deleted people
- invalid sidecars
- older internal draft sidecars
- unresolved IDs in sidecars

Current status:
- Unknown tags and missing people references have basic handling.
- Invalid sidecars warn users and are backed up before replacement.

---

## UI / Layout

Watch for:
- right-column spacing / scrollbar breathing room
- crowded action areas
- users missing important controls
- crop/export/delete actions feeling like an afterthought
- places where progressive disclosure would reduce clutter

Current status:
- Suggested and Manual people modes feel closer to one design system.
- Manual row behavior is acceptable for now.

---

## Save / Dirty State

Watch for:
- users not knowing whether changes are saved
- automatic save-on-next behavior causing uncertainty
- unclear failure state when save is blocked

Potential improvement:
- clearer save / dirty status indicator

---

## Privacy / App Store Promises

Watch for:
- any future feature that adds network access
- any analytics, telemetry, cloud sync, or account behavior
- any change that affects App Store privacy answers
- any change that affects the privacy policy

Current status:
- dMPP 1.0 is local-first and does not collect app data.

---

# Completed Recently / Version 1.0 Foundation

## Launch Readiness

- Privacy policy updated to cover dMPP, local sidecars, portable archive data, face processing, and user-selected folders.
- App Store privacy answer prepared as **Data Not Collected**.
- Folder access / first-run clarity reviewed.
- Sandbox entitlements reviewed.
- Failure-state testing completed.
- App Review Notes prepared.
- Support page drafted.
- dMagy Apps page drafted.
- dMPP product page drafted.
- App Store upload succeeded after resolving:
  - Apple agreement / contract-state issue
  - invalid `CFBundleDocumentTypes` issue

---

## dMPMS Standard / Publishing

- Formalized dMPMS v1.0 as the first public sidecar metadata standard.
- Separated public sidecar standard from dMPP-specific implementation details.
- Documented required, optional, display-facing, curator-facing, and workflow/app-private fields.
- Renamed `privateNotes` to `curatorNotes`.
- Confirmed `description` is display-facing and `curatorNotes` is curator-facing.
- Included examples for:
  - basic sidecars
  - people
  - dates/date ranges
  - GPS/location
  - tags
  - virtual crops
  - headshots
  - workflow fields
  - curator notes
- Chose `dmpmsVersion: "1.0"` for the first public release.
- Clarified migration expectations for older internal-draft sidecars.
- Licensed the specification under CC BY 4.0.

---

## Failure-State Testing

Tested:
- missing / deleted Picture Library Folder
- renamed Picture Library Folder
- Picture Library Folder moved to Trash
- deleted portable archive subfolders:
  - Tags
  - Locations
- invalid `.dmpms.json` sidecar
- deleted image while app is open
- locked sidecar / save failure
- deleted entire `dMagy Portable Archive Data` folder

Results:
- No crashes found.
- Missing folders and deleted portable archive data were repaired correctly when folder access was valid.
- Save failure was blocked with a clear message.
- Invalid sidecars now show a warning and are backed up before replacement.
- Deleted/missing images remain navigable, though the message is generic.

---

## Portable Archive / UX

- Safe Picture Library Folder change flow completed.
- Portable archive folder naming fixed as `dMagy Portable Archive Data`.
- “Change or Refresh Picture Library Folder…” language added.
- Easy shortcut removed from File menu.
- “What are you trying to do?” choice added before changing an existing root.
- Refresh Access path added for stale macOS / cloud-folder permissions.
- Warning added before creating new portable archive data when the selected folder does not already contain it.
- Full copy/merge migration deferred until there is a real use case.

---

## Data Integrity

- Unknown tag repair actions added for tags saved in a sidecar but missing from Settings.
- `privateNotes` renamed to `curatorNotes`.
- Missing People reference warning added.
- Orphaned People reference details preserved in curator notes so they are not lost on save/navigation.
- Curator Notes minimized / collapsed under Description.
- Invalid sidecars warn users and are backed up before replacement.

---

## Face Recognition / Matching Quality

- Cleanup added for learned face suggestions pointing to deleted People records.
- Deleted-person suggestions warn the user and offer to remove learned samples for that deleted person.
- Inline warning added when a high-confidence Suggested match differs from the person the user assigns.
- Warning helps users recover from mis-clicks by pointing toward clearing learned samples for the suggested person.

---

## Face Recognition / Workflow

- Face learning moved to Save only.
- Permanent action added to reset learned face samples for a person.
- Current face-learning data audited for contamination from accidental assignments.
- Stale face suggestions verified not to leak between pictures.
- All visible face chips must be assigned or ignored before Save / Previous / Next.
- “No faces found” message added when Suggested mode detects no faces.
- “Ignore Other Faces” added for remaining unassigned visible faces in Suggested mode.

---

## People Settings

- Add Event flow fixed so unsaved original person fields are committed before adding an identity event.
- Prevents new-person draft details from being lost when an event is added immediately.
- Added `fatherID`, `motherID`, and `gender` as shared person-level fields.
- Stable tie-break sorting added for duplicate short names using birth date, then full name, then person ID.

---

## People UI / Suggested + Manual Polish

- People mode help icon moved into the People GroupBox title row.
- Duplicated help icon spacing removed from Suggested and Manual modes.
- Vertical spacing tightened between Suggested instructions and Faces section.
- Suggested face chips restyled to align more closely with Manual pills.
- Suggested face chips changed from rigid two-column layout to content-sized wrapping chips.
- Birth-date differentiators removed from Suggested / Auto-Detect chips.
- Startup review mode/navigation state reset so relaunch always starts in All Pictures.
- Suggested / Manual modes now feel closer to the same design system.

---

## Locations

- GPS-derived location loading fixed so matching saved Locations also apply the saved Location description.
- Near-address matching added for cases where GPS resolves to a neighboring house number.
- Saved-location enrichment updated so saved Location can overwrite reverse-geocoded street address.
- Location section layout polished.
- Unclear location button behavior renamed.
- Location help/info popover added.
- Clearer GPS / saved-location / reset / clear guidance added.

---

## Tags

- Hover help added from tag descriptions.
- Unknown-tag handling and repair actions improved.
- Tag descriptions and portability implemented.
- Reserved tags enforced:
  - `Do Not Display`
  - `Flagged`

---

## Crops

- Crop drag and crop slider jerkiness resolved by caching a decoded image in the editor view model.
- Crop header rearranged so crop chips and New Crop sit on the same row.
- Crop actions moved to the upper right.
- New Crop changed from native Menu button to button/popover.
- New Crop popover row height and styling refined.
- Crop help/info popover added.
- “Are you sure?” confirmation removed when deleting a crop.
- One-off headshots added.
- Face boxes temporarily hidden while viewing/editing headshot crops.

---

## Title / Description / Curator Notes

- Description tools moved beside the Description label.
- Description tool help added.
- Speech-to-text description support present.
- Curator Notes added as curator-facing notes not intended for display.
- Curator Notes collapsed when empty and auto-expanded when populated.
- Next picture moves focus / scrolls to Title.

---

## Help / Getting Started

- Traditional in-app dMPP Help window added.
- Bundled Markdown help topics in the app target.
- Help > dMPP Help menu item added.
- Topic sidebar and lightweight Markdown rendering added.
- Help > Getting Started kept as a separate setup-focused guide.
- Getting Started moved into its own `GettingStartedChecklistView.swift` file.
- Getting Started simplified into a setup-first guide focused on:
  - Picture Library Folder concept
  - Apple Photos export note
  - People setup
  - Locations setup
  - basic review workflow
- Tags removed from required starter checklist because default tags already exist.
- “Show automatically until setup is complete” changed to “Show at startup.”
- Settings-style icons added to People and Location Settings buttons.

---

# Parking Lot / Deferred

These are intentionally not active, but may be revisited later.

## Full Portable Archive Merge

Deferred until there is a real use case.

Possible future:
- guided merge of portable archive data between roots
- conflict resolution
- registry reconciliation

---

## Broad Editor Refactor

Deferred until after launch and only if there is clear editing friction.

Rule:
- refactor one responsibility at a time
- checkpoint before moving code
- test after each extraction

---

## Stronger Face Explainability

Deferred unless users show confusion or wrong-match patterns increase.

---

## Face Box Name Labels

Investigated and intentionally declined for dMPP.

Rationale:
- dMPP is the prep app, not the display app.
- Overlay name labels could add clutter during review.

---

## App Store Accessibility Declarations

Deferred until accessibility support is verified against common tasks.

Current App Store posture:
- Do not claim support for accessibility features unless onboarding, settings, help, and core editing workflows have been tested.

---

## Notes for Future Dan

If returning after a long break:

1. Start with `dMPP-Context-v17.md`.
2. Review this backlog for current ideas and watch items.
3. Check recent Git commits after the 1.0 launch.
4. Do not start with a broad refactor.
5. Pick one user-visible improvement and work in a small, reversible step.
