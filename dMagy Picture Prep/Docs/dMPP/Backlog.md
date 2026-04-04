# dMPP Backlog

_Last updated: 2026-04-03_

## Critical / Active Now

### Face Recognition / Auto-Detect Safety
- Move face learning to **Save only**.
- Add a permanent action to **reset learned face samples for a person**.
- Audit current face-learning data for contamination from accidental assignments.
- Verify stale face suggestions do not leak between pictures.
- Require all visible face chips to be **assigned or ignored** before Save / Previous / Next.
- Investigate whether bad accepted suggestions may have already polluted the face index.
- Add a safer “wrong match” recovery path later if needed.

### Face Recognition / Matching Quality
- Tune suggestion thresholds after more real-world batch testing.
- Revisit how confidence % is displayed so obvious bad matches do not look overly certain.
- Investigate adding **short names to face box overlays**.
- Investigate whether there should be a better way to explicitly reject a wrong match.

### Face Recognition / Performance
- Picture crop slider is again very jerky on pictures with facial recognition.
- Continue batch-testing responsiveness across a variety of real photo sets.

---

## High Priority

### People / Identity Model
- Add `parentID` to people.
- Unknown → identified conversion.
- Missing-reference handling when sidecar IDs are no longer in the registry.
- Ensure newly added unknown / one-off people always apply to the current row immediately.

### People UI / Checklist
- Date from photo metadata does **not** automatically filter the people checklist.
- Birth-date differentiators are still showing in Auto-Detect chips (example: `Anna b. 1991`) and should be removed.
- Continue People workflow polish in both Manual and Auto-Detect modes.
- Help content is getting closer to needing a real Help article / help surface.
- Auto-Detect: add Ignore Others action to ignore all remaining unassigned visible faces

### Review / Navigation
- `Review: Never Reviewed` seems to persist on restart even though the dropdown shows `All Pictures` by default.
- Investigate picture-list navigation improvements, such as **Go to First in List**.
- Consider other lightweight navigation improvements once the current flow is stable.

---

## Medium Priority

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

---

## Notes / Watch List
- Manual row behavior is currently acceptable even if an extra blank row is saved at the end.
- Toggling to Auto-Detect and back can be used to clear the current Manual row state and start over.
- Continue watching right-column spacing / scrollbar breathing room during UI polish.
