# dMPP Backlog

_Last updated: 2026-05-06_

---

### dMPP Launch Readiness

1. Privacy Policy / App Store Privacy — Complete

   - Privacy policy updated to cover local sidecars, portable archive data, face processing, and user-selected folders.
   - App Store privacy answer: Data Not Collected, pending final code sanity check during item 9 / release build.

2. Folder Access / First-Run Clarity — Complete

   - First-run explains that the user should choose the main folder for the picture collection they plan to prepare.
   - First-run explains that dMPP saves notes, people, places, tags, and crop choices inside that folder so everything stays together.
   - Settings exposes the selected Picture Library Folder and the portable archive data location.
   - Users are informed that dMPP keeps its working information inside the selected folder rather than sending it elsewhere.

3. Sandbox / Entitlements Review — Complete

- App Sandbox is enabled.
- Hardened Runtime is enabled.
- User Selected Files is set to Read/Write.
- Audio Input is enabled for speech-to-text description entry.
- Microphone and Speech Recognition usage descriptions are present.
- Network incoming/outgoing, camera, contacts, location, calendar, printing, USB, and other unused capabilities are disabled.
- Code Signing Entitlements is blank, so Xcode appears to be managing effective sandbox entitlements through target settings rather than an explicit entitlements file.

Release-build check:
- Reconfirm these settings before Archive / App Store submission.

4. **Failure-State Testing**
   - Test missing folder, renamed folder, read-only folder, invalid sidecar JSON, deleted image, and missing portable archive folders.
   - Improve messaging only where a normal user would be stuck.

5. **dMPMS Publishing**
   - Commit `dMPMS-v1.0.md` and example sidecars under `Docs/dMPMS`.
   - Publish the dMagy.com/dmpms overview page and link to the canonical spec.

6. **Help / README Alignment**
   - Update Help files, `_Read_Me_`, and any in-app text to use `curatorNotes`, `dmpmsVersion: "1.0"`, and current dMPMS language.
   - Make sure dMPMS docs are repo-only unless intentionally bundled.

7. **Sample Archive / Screenshots**
   - Create a small clean sample archive for testing, screenshots, and App Review notes.
   - Use it to produce App Store screenshots and verify the new-user path.

8. **App Review Notes**
   - Write a short reviewer note explaining local folder selection, sidecar writing, and that original photos are not modified or uploaded.
   - Include simple test steps using a folder of sample images.

9. **Final Data-Safety Pass**
   - Confirm save, Next Picture auto-save, sidecar versioning, `curatorNotes`, people, tags, locations, and crops behave correctly.
   - Confirm existing sidecars remain readable.

10. **Release Build / Distribution Check**
   - Build a clean release archive and test it outside Xcode.
   - Verify app icon, version/build number, signing, notarization/App Store packaging, and launch behavior.  



Here are the failure-state test results so far.

## 4. Failure-State Testing — Results So Far

### Test 1 — Renamed Picture Library Folder

**Result: Pass**

What you did:

* Renamed the selected Picture Library Folder outside dMPP.
* Relaunched dMPP.

What happened:

* dMPP successfully found and continued using the renamed folder.

Conclusion:

* No fix needed.
* This is good behavior. macOS/security-scoped bookmarks can often continue tracking a renamed folder.

---

### Test 1b — Picture Library Folder moved to Trash

**Result: Pass**

What you did:

* Moved the selected Picture Library Folder to Trash.
* Relaunched dMPP.

What happened:

* dMPP still found and used the folder.

Conclusion:

* No fix needed.
* Still acceptable behavior because the folder technically still existed.

---

### Test 1c — Picture Library Folder permanently deleted

**Result: Pass**

What you did:

* Emptied Trash so the selected Picture Library Folder was actually gone.
* Relaunched dMPP.

What happened:

* dMPP asked you to select a new Picture Library Folder.

Conclusion:

* No fix needed.
* This is the correct recovery path.

Backlog note:

```markdown
- Missing / deleted Picture Library Folder: Pass
  - Renamed or moved folders may still resolve correctly.
  - When the folder was permanently deleted, dMPP prompted for a new Picture Library Folder.
  - No fix needed.
```

---

### Test 5a — Deleted `Tags` support folder

**Initial Result: Confusing / suspected fail**

What you did:

* Deleted:

```text
dMagy Portable Archive Data/Tags
```

* Relaunched dMPP.

What happened:

* `Tags` did not recreate immediately.
* Tags were still available in the app.
* Opening Settings > General recreated the folder.

Then we investigated:

* Console showed sandbox permission errors: “Operation not permitted.”
* After refreshing access to the Picture Library Folder, `Tags` was regenerated properly.

**Final Result: Pass after folder access refresh**

Conclusion:

* Missing folder repair works when dMPP has valid write access.
* The first failure was likely stale/lost sandbox permission after the rename/trash/delete testing.

Backlog note:

```markdown
- Deleted Tags support folder: Pass after access refresh
  - dMPP recreated the missing Tags folder once write access to the Picture Library Folder was refreshed.
  - Finding: stale macOS folder permission can prevent support-folder repair.
  - Possible polish: if dMPP cannot write inside the Picture Library Folder, show a plain message prompting the user to refresh folder access.
```

---

### Test 5b — Deleted `Locations` support folder

**Result: Pass**

What you did:

* Deleted:

```text
dMagy Portable Archive Data/Locations
```

* Relaunched dMPP after folder access had been refreshed.

What happened:

* `Locations` was recreated automatically.

Conclusion:

* No structural repair fix needed.
* This confirms the bootstrap repair behavior works when folder permission is valid.

Backlog note:

```markdown
- Deleted Locations support folder: Pass
  - dMPP recreated the missing Locations folder on relaunch.
  - No fix needed.
```

---

## Summary so far

```markdown
4. Failure-State Testing — In progress

Completed:
- Renamed Picture Library Folder: Pass
- Picture Library Folder moved to Trash: Pass
- Picture Library Folder permanently deleted: Pass
- Deleted Tags support folder: Pass after access refresh
- Deleted Locations support folder: Pass

Finding:
- Missing portable archive folders are repaired correctly when dMPP has valid write access.
- Stale/lost macOS sandbox folder permission can prevent repair and cause “Operation not permitted” console errors.

Possible polish:
- Add a user-facing message when dMPP cannot write inside the Picture Library Folder:
  “dMPP needs permission to save inside your Picture Library Folder. Choose the folder again to refresh access.”

Remaining tests:
- Read-only folder / save failure
- Invalid `.dmpms.json` sidecar
- Deleted image while app is open
- Deleted entire `dMagy Portable Archive Data` folder
```

My read: nothing here is a launch blocker yet, but the stale-permission message may be worth adding if we hit it again in another test.

### Test 2 — Invalid `.dmpms.json` sidecar

Result: Partial fail / Fix needed

What I did:
- Created a valid `.dmpms.json` sidecar.
- Replaced its contents with invalid JSON:
  `{ "title": "Broken"`
- Relaunched dMPP and navigated to that picture.

What happened:
- dMPP did not crash.
- Console logged a decoding failure: “The given data was not valid JSON.”
- No user-facing warning appeared.
- I could continue working.
- Saving overwrote the broken sidecar with valid new data.

Fix needed:
- Show a plain warning when a sidecar cannot be read.
- Prevent silent overwrite, or back up/quarantine the unreadable sidecar before writing a replacement.
---

## Near-Term Backlog



### Locations
- Location manager UX parity with People manager.
- Improve GPS-derived location confidence and correction:
  - Prefer saved Locations when reverse geocoding returns a nearby / slightly different street address.
  - Consider a subtle UI note when a saved Location was applied from a nearby GPS result.
  - Consider adding GPS coordinates to saved Locations later for stronger distance-based matching.


### Help
- Add search to dMPP Help.
- Add “Open full Help topic…” links from section help popovers.
- Improve Markdown rendering for bold, inline code, links, and nested lists if needed.
- Consider screenshots once the UI stabilizes.
---

## Planned / Future

### Crops
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

### People Settings
- Fixed Add Event flow so unsaved original person fields are committed before adding an identity event.
- Prevents new-person draft details from being lost when an event is added immediately.

### dMPMS Standard / Publishing — Complete
- Formalized dMPMS v1.0 as the first public sidecar metadata standard.
- Separated the public sidecar standard from dMPP-specific implementation details.
- Documented required, optional, display-facing, curator-facing, and workflow/app-private fields.
- Renamed `privateNotes` to `curatorNotes` before public release to avoid implying encryption or privacy protection.
- Confirmed `description` is display-facing and `curatorNotes` is curator-facing.
- Included examples for basic sidecars, people, dates/date ranges, GPS/location, tags, virtual crops, headshots, workflow fields, and curator notes.
- Chose `dmpmsVersion: "1.0"` for the first public release.
- Clarified migration expectations for older internal-draft sidecars.
- Licensed the specification under CC BY 4.0.

### Shipping Readiness / Refactor Question — Decision Made
- Decided `DMPPImageEditorView.swift` size is primarily a maintainability concern, not an immediate shipping blocker.
- Do not begin a broad refactor before first outside-user readiness unless current behavior is stable, committed, and there is a specific bug or pain point requiring extraction.
- Continue using `// MARK:` anchors to keep the large file navigable.
- Refactor later in small, reversible extractions only.
- Use a versioning checkpoint before each extraction.

Future extraction candidates:
- Title / Description / Curator Notes section
- Tags section
- Location section
- People section
- Crop header/actions
- File/folder toolbar helpers
- Save/navigation command handling
