# dMPP Backlog

_Last updated: 2026-04-04_

## Critical / Active Now

### People / Identity Model
- 
- 
- 
- 

### People UI / Checklist
- Date from photo metadata does **not** automatically filter the people checklist.
- Birth-date differentiators are still showing in Auto-Detect chips (example: `Anna b. 1991`) and should be removed.
- Continue People workflow polish in both Suggested and Manual modes.
- Help content is getting closer to needing a real Help article / help surface.

### Review / Navigation
- `Review: Never Reviewed` seems to persist on restart even though the dropdown shows `All Pictures` by default.
- Investigate picture-list navigation improvements, such as **Go to First in List**.
- Consider other lightweight navigation improvements once the current flow is stable.

---

## High Priority

### Portable Archive / UX
- Portable archive settings folder naming + migration when root moves.
- First-run instruction window / help.
- Review `_Read_Me_` and add examples.
- Validation / health indicators (missing dates, missing crop, missing people, etc.).
- Clearer save / dirty status indicators.

### Performance
- Faster folder scanning.
- Thumbnail caching.
- Continue to favor correctness and UI stability over premature optimization.

### Locations
- Location manager UX parity with People manager.
- Bulk apply location to selection.

### Tags
- Continue refining tag descriptions / portability as needed.
- Keep the Tags “Linked file (advanced)” area aligned with People / General behavior.

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
Future refactor: separate Person core from Identity versions

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

Missing-reference handling when sidecar IDs are no longer in the registry.

---

## Recently Completed

### Face Recognition / Auto-Detect Safety
- Move face learning to **Save only**.
- Add a permanent action to **reset learned face samples for a person**.
- Audit current face-learning data for contamination from accidental assignments.
- Verify stale face suggestions do not leak between pictures.
- Require all visible face chips to be **assigned or ignored** before Save / Previous / Next.
- Investigate whether bad accepted suggestions may have already polluted the face index.

### Face Recognition / Performance
- Picture crop slider jerkiness with facial recognition was addressed.
- Continued batch-testing responsiveness across a variety of real photo sets.

### People UI / Checklist
- Auto-Detect / Suggested mode now includes **Ignore Other Faces** for remaining unassigned visible faces.

Added fatherID, motherID, and gender as shared person-level fields.
