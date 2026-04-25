# dMPP Backlog

_Last updated: 2026-04-24_


---

## High Priority

### Portable Archive / UX
- Handle Picture Library Folder changes safely:
  - Keep portable archive folder naming fixed as `dMagy Portable Archive Data`.
  - Detect whether a newly selected root already contains portable archive data.
  - If missing, avoid silently creating an empty “new archive” experience that makes People / Locations / Tags / Crops appear lost.
  - Consider options to create new portable data, copy from the previous root, or cancel root switching.
- First-run instruction window / help.
- Review `_Read_Me_` and add examples.
- Validation / health indicators:
  - Missing dates.
  - Missing crop.
  - Missing people / unreviewed people.
  - Unresolved or missing references.
- Clearer save / dirty status indicators.

### Performance
- Faster folder scanning.
- Thumbnail caching.
- Continue to favor correctness and UI stability over premature optimization.

### Locations
- Location manager UX parity with People manager.
- Improve GPS-derived location confidence and correction:
  - Prefer saved Locations when reverse geocoding returns a nearby / slightly different street address.
  - Consider a subtle UI note when a saved Location was applied from a nearby GPS result.
  - Consider adding GPS coordinates to saved Locations later for stronger distance-based matching.
- Bulk apply location to selection.

### Tags
- Continue refining tag descriptions / portability as needed.
- Keep the Tags “Linked file (advanced)” area aligned with People / General behavior.

### Editor / File Opening
- Ability to open an image directly from Finder / browser into dMPP.

### Metadata Source Indicators
- Add indicators showing whether date and location came from:
  - image metadata
  - sidecar data
  - user edits
  - saved registry matching

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
- Consider a better way to explicitly reject a wrong match, if the current reset workflow proves insufficient.

### Architecture / Future Refactor
- Separate Person core from Identity versions.

---

## Watch List / Complete for Now

### Face Recognition / Matching Quality
- Suggestion thresholds feel acceptable after real-world batch testing; revisit only if a clear pattern appears.
- Confidence % display currently feels acceptable; monitor rather than actively tune.
- Adding short names to face box overlays was investigated and intentionally declined for dMPP (prep app, not display app).

### Face Recognition / Workflow
- The current reset-person workflow is acceptable for wrong-match recovery, but may later be replaced or supplemented by per-sample review.
- Continue watching whether a stronger explicit “wrong match” workflow is actually needed.

### UI / Layout
- Continue watching right-column spacing / scrollbar breathing room during UI polish.
- Manual row behavior is currently acceptable even if an extra blank row is saved at the end.
- Toggling to Suggested and back can be used to clear the current Manual row state and start over.
- Suggested / Manual now feel closer to the same design system after UI polish.

### Data Integrity
- Missing-reference handling when sidecar IDs are no longer in the registry.

---

## Recently Completed

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
- Moved face learning to **Save only**.
- Added a permanent action to **reset learned face samples for a person**.
- Audited current face-learning data for contamination from accidental assignments.
- Verified stale face suggestions do not leak between pictures.
- Required all visible face chips to be **assigned or ignored** before Save / Previous / Next.
- Investigated whether bad accepted suggestions may have already polluted the face index.

### Image / Crop Performance
- Resolved crop drag and crop slider jerkiness by caching a decoded image in the editor view model.
- Continued batch-testing responsiveness across a variety of real photo sets.

### Crop UI
- Rearranged crop header so crop chips and New Crop sit on the same row.
- Moved crop actions to the upper right.
- Changed New Crop from a native Menu button to a button / popover.
- Refined New Crop popover row height and styling.

### People UI / Checklist
- Added **Ignore Other Faces** for remaining unassigned visible faces in Suggested mode.
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
