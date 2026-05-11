# dMPP Backlog

_Last updated: 2026-05-06_

---

## Next / High Priority







---

## Product / Design Decisions Needed


### Documentation / Standards
- Review `_Read_Me_` and align it with the future published dMPMS standard.
- Add practical examples that explain what sidecars are and why they exist.




### dMPMS Standard / Publishing
- Review and formalize the dMPMS sidecar metadata standard before public release.
- Decide what belongs in the published standard versus app-specific implementation details.
- Document required, optional, and app-private fields.
- Clarify display-facing fields versus curator/private fields.
  - Example: `description` is display-facing.
  - Example: `privateNotes` is curator-facing and not intended for display.
- Include examples of real `.dmpms.json` sidecars:
  - basic photo
  - photo with people
  - photo with dates / date ranges
  - photo with GPS / saved location
  - photo with virtual crops
  - photo with Private Notes
- Decide versioning rules for `dmpmsVersion`.
- Decide migration expectations for older sidecars.
- Publish the standard when dMPP / dMPS are ready for outside users.

### Shipping Readiness / Refactor Question
- Decide whether dMPP can ship with `DMPPImageEditorView.swift` at its current size.
  - Current concern: approximately 6300+ lines.
  - Question: is this a shipping risk or primarily a maintainability concern?
- Recommendation: do not start a broad refactor unless current behavior is stable and committed.
- If refactoring, plan gradual extraction only:
  - Title / Description / Private Notes section
  - Tags section
  - Location section
  - People section
  - Crop header/actions
- Use versioning checkpoints before each extraction.

---

## Near-Term Backlog



### Locations
- Location manager UX parity with People manager.
- Improve GPS-derived location confidence and correction:
  - Prefer saved Locations when reverse geocoding returns a nearby / slightly different street address.
  - Consider a subtle UI note when a saved Location was applied from a nearby GPS result.
  - Consider adding GPS coordinates to saved Locations later for stronger distance-based matching.

### Tags
- Continue refining tag descriptions / portability as needed.
- Keep the Tags “Linked file (advanced)” area aligned with People / General behavior.

### Private Notes
- Continue monitoring whether collapsed/minimized Private Notes feels right.
- Consider whether Private Notes needs:
  - clearer help text
  - visual indicator when populated
  - “flagged picture” integration later

### Save / Access Recovery
- Save button brightness currently indicates dirty/clean state.
- Next Picture is disabled with guidance when Suggested faces still need assignment/ignore decisions.
- Revisit only if users miss save failures or need stronger folder-access recovery messaging.
- Future possible improvement:
  - visible “Save failed” / “Refresh Access” message when sidecar or portable archive writes fail.

---

## Planned / Future

### Crops
- Re-examine New Crop menu structure.
- Headshot (Tight) / Headshot (Full) per-person tabs.
- Grouping behavior in crop strip.
- Move crop presets fully to portable JSON.

### Bulk Operations
- Apply location to selection.
- Apply tags to selection.
- Batch operations more broadly.

### Face Recognition / Later Improvements
- Per-sample face-learning review instead of only reset-all-for-person.
- Better review tooling for learned face samples, possibly including source photo.
- Explore stronger explainability for suggestions if needed.
- Consider a better way to explicitly reject a wrong match if current reset/warning workflows prove insufficient.
- Tune high-confidence mismatch threshold after more real-world testing.
  - Current starting point: `similarity >= 0.985`, displayed as 99%.

### Architecture / Future Refactor
- Separate Person core from Identity versions.
- Gradually extract sections from `DMPPImageEditorView.swift` only after behavior is stable.
- Avoid broad refactors without a clear rollback point.

---

## Watch List / Complete for Now

### Face Recognition / Matching Quality
- Suggestion thresholds feel acceptable after real-world batch testing; revisit only if a clear pattern appears.
- Confidence % display currently feels acceptable; monitor rather than actively tune.
- Adding short names to face box overlays was investigated and intentionally declined for dMPP.
  - Rationale: dMPP is the prep app, not the display app.

### Face Recognition / Workflow
- The current reset-person workflow is acceptable for wrong-match recovery.
- Inline warnings now help users recover from:
  - deleted people still being suggested
  - high-confidence suggestion mismatch after a different assignment
- Continue watching whether stronger explicit “wrong match” tooling is actually needed.

### UI / Layout
- Continue watching right-column spacing / scrollbar breathing room during UI polish.
- Manual row behavior is currently acceptable even if an extra blank row is saved at the end.
- Toggling to Suggested and back can be used to clear the current Manual row state and start over.
- Suggested / Manual now feel closer to the same design system after UI polish.

### Data Integrity
- Unknown Tags and missing People references now have basic handling.
- Continue watching for other unresolved-reference cases beyond:
  - Tags
  - People
  - learned face samples

### Archive Access / Permissions
- Improve folder-access recovery messaging when macOS / Dropbox / cloud storage permissions expire.
  - If dMPP can see the saved Picture Library Folder path but cannot read/write portable archive files, show a clear “Refresh Picture Library Folder Access…” message.
  - Avoid misleading messages such as “Settings are currently being edited” when the real issue is folder access.
  - Let the user reselect the same Picture Library Folder to refresh macOS permission.
- Defer full diagnostics panel unless access issues become frequent.
  - Possible future diagnostic checks: People, Locations, Tags, Crops, FaceIndex, and `_locks` readable/writable.

### Performance
- Faster folder scanning.
- Thumbnail caching.
- Continue to favor correctness and UI stability over premature optimization.
---

## Recently Completed

### Portable Archive / UX
- Completed safe Picture Library Folder change flow:
  - Kept portable archive folder naming fixed as `dMagy Portable Archive Data`.
  - Added “Change or Refresh Picture Library Folder…” language.
  - Removed the easy shortcut from the File menu.
  - Added a “What are you trying to do?” choice before changing an existing root.
  - Added Refresh Access path for stale macOS / cloud-folder permissions.
  - Added warning before creating new portable archive data when the selected folder does not already contain it.
  - Deferred full copy/merge migration until there is a real use case.

### Data Integrity
- Added unknown tag repair actions for tags saved in a sidecar but missing from Settings.
- Added Private Notes for curator-only notes and repair clues.
- Added People missing-reference warning.
- Automatically preserves orphaned People reference details in Private Notes so they are not lost on save/navigation.
- Minimized / collapsed Private Notes under Description.

### Face Recognition / Matching Quality
- Added cleanup for learned face suggestions that point to deleted People records.
- When a deleted person is still being suggested, dMPP warns the user and offers to remove learned samples for that deleted person.
- Added inline warning when a high-confidence Suggested match differs from the person the user assigns.
- Warning helps users recover from mis-clicks by pointing them toward clearing learned samples for the suggested person.

### Locations
- Fixed GPS-derived location loading so matching saved Locations also apply the saved Location description.
- Added near-address matching so GPS results like a neighboring house number can still match a saved Location on the same street / city / state / country.
- Updated GPS saved-location enrichment so the saved Location can overwrite the reverse-geocoded street address when a saved match is found.

### People UI / Suggested + Manual Polish
- Moved the People mode help icon into the People GroupBox title row.
- Removed duplicated help icon spacing from Suggested and Manual modes.
- Tightened vertical spacing between Suggested instructions and the Faces section.
- Restyled Suggested face chips to align more closely with Manual pills.
- Changed Suggested face chips from rigid two-column layout to content-sized wrapping chips.

### Face Recognition / Auto-Detect Safety
- Moved face learning to Save only.
- Added a permanent action to reset learned face samples for a person.
- Audited current face-learning data for contamination from accidental assignments.
- Verified stale face suggestions do not leak between pictures.
- Required all visible face chips to be assigned or ignored before Save / Previous / Next.
- Investigated whether bad accepted suggestions may have already polluted the face index.

### Image / Crop Performance
- Resolved crop drag and crop slider jerkiness by caching a decoded image in the editor view model.
- Continued batch-testing responsiveness across a variety of real photo sets.

### Crop UI
- Rearranged crop header so crop chips and New Crop sit on the same row.
- Moved crop actions to the upper right.
- Changed New Crop from a native Menu button to a button / popover.
- Refined New Crop popover row height and styling.
- Added Crop help/info popover.

### Title / Description / Private Notes UI
- Moved description tools beside the Description label.
- Added Description tool help.
- Added Private Notes as curator-facing notes not intended for display.
- Collapsed Private Notes when empty and auto-expanded when populated.

### Location UI
- Polished Location section layout.
- Renamed unclear location button behavior.
- Added Location help/info popover.
- Added clearer GPS / saved-location / reset / clear guidance.

### Date UI
- Added Date Taken or Era help/info popover.

### Tags UI
- Added hover help from tag descriptions.
- Added clearer unknown-tag handling and repair actions.

### People UI / Checklist
- Added Ignore Other Faces for remaining unassigned visible faces in Suggested mode.
- Added `fatherID`, `motherID`, and `gender` as shared person-level fields.
- Fixed date-derived-state sync so photo metadata properly filters the people checklist.
- Added stable tie-break sorting for duplicate short names in the People checklist using birth date, then full name, then person ID.
- Removed birth-date differentiators from Suggested / Auto-Detect chips.
- Reset startup review mode/navigation state so relaunch always starts in All Pictures.
- Added “No faces found” message when Suggested mode detects no faces.

### Prior CTX15 Punchlist Items
- Locations added/deleted in Settings now update editor UI sufficiently to move from active punchlist.
- Tags added/deleted in Settings now update editor UI sufficiently to move from active punchlist.
- Removed “Are you sure?” confirmation when deleting a crop.
- Added ability to create one-off headshots.
- Next picture moves focus / scrolls to Title.


### Editor UX / Visible Polish
- Rework Export / Delete command box.
  - Current UI feels like an afterthought.
  - Goal: make crop/export/delete actions feel intentional, clear, and aligned with the rest of the editor.
  
### Getting Started / Help
- Moved Getting Started into its own `GettingStartedChecklistView.swift` file.
- Simplified Getting Started into a short setup-first guide focused on:
  - Picture Library Folder concept.
  - Apple Photos export note.
  - People setup.
  - Locations setup.
  - Basic review workflow.
- Removed longer “watch for these picture types” tutorial-style content.
- Removed Tags from the required starter checklist because default tags already exist.
- Changed “Show automatically until setup is complete” to “Show at startup.”
- Added matching Settings-style icons to People and Location Settings buttons.
- Kept Getting Started available from Help > Getting Started.

### Crops / Headshots
- Completed: Temporarily hide face boxes while viewing/editing headshot crops.
  - Face boxes remain controlled by the user’s normal show/hide setting.
  - Headshot crops suppress the overlay only while selected.
  - The face-box toggle is disabled while a headshot crop is selected to avoid a no-visible-change interaction.
- Deferred: Smarter initial headshot crop placement from detected face boxes.
  - Current centered default is acceptable for now.
  - Revisit only if headshot creation becomes a frequent workflow pain point.

### Help
- Added traditional in-app dMPP Help window.
- Bundled Markdown help topics in the app target.
- Added Help > dMPP Help menu item.
- Added topic sidebar and lightweight Markdown rendering for headings, paragraphs, lists, and code blocks.
- Kept Help > Getting Started as a separate setup-focused guide.
