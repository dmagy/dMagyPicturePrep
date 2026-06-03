# 014 - dMPS Flagged Report Phase 4A Triage Polish Implementation

Save path: `Docs/dMPP/dMPP-Codex-Reports/014-dmps-flagged-report-phase-4a-triage-polish-implementation.md`

## 1. Executive summary

This polish pass keeps the dMPS Flagged Review Queue import window as a no-write triage workflow.

The top summary now combines all safe future-update categories into one user-facing `ready to tag as Flagged` count. The window still keeps the internal distinction between existing saved information and missing saved information for later Phase 4B planning.

Needs-attention wording now points the user toward opening the picture in dMPP or showing it in Finder, rather than implying that the queue is a repair workflow.

Picture list rows now have a right-click context menu with `Show Picture in Finder` when the picture exists and `Copy Original Path` when a path is available.

## 2. Files changed

- `dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageSummaryView.swift`
- `dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageCoordinator.swift`
- `dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageDetailView.swift`
- `dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportView.swift`

## 3. Files added

- `dMagy Picture Prep/Docs/dMPP/dMPP-Codex-Reports/014-dmps-flagged-report-phase-4a-triage-polish-implementation.md`

## 4. Confirmation that no sidecars are written

Confirmed. This change does not add sidecar creation, sidecar writing, tag updates, curator note appends, or dMPMS mutation.

The new Finder context menu only reveals an existing picture file or copies a path to the pasteboard.

## 5. Confirmation that no original images are changed

Confirmed. No original image files are created, modified, moved, copied, or deleted.

## 6. Confirmation that `DMPPImageEditorView.swift` was not touched

Confirmed. `DMPPImageEditorView.swift` was not modified.

## 7. Confirmation that `dMagy_Picture_PrepApp.swift` was not touched

Confirmed. `dMagy_Picture_PrepApp.swift` was not modified.

## 8. Summary of summary-label changes

The top triage summary now shows four curator-facing boxes:

- `pictures in review queue`
- `ready to tag as Flagged`
- `already updated`
- `needs attention`

The `ready to tag as Flagged` count combines items that already have readable saved information, items where saved information can be created later, and items that only need the stable dMPS review note later.

## 9. Summary of needs-attention wording changes

Generic needs-attention wording now says:

`This picture needs attention before dMPP can safely update saved information.`

The supporting detail now says:

`Open the picture in dMPP or show it in Finder to see what needs attention.`

Unreadable saved-information wording now tells the user to inspect or repair the saved information and review why the picture was flagged, without framing the queue as a repair-and-return workflow.

## 10. Summary of Finder context-menu behavior

Each picture row now has a context menu.

If the picture file exists, `Show Picture in Finder` reveals it using Finder. This also works for existing files outside the current Picture Library Folder, so the user can manually decide what to do.

If the picture file does not exist, `Show Picture in Finder` is disabled.

If the queue item has an original path or resolved candidate path, `Copy Original Path` copies that path to the pasteboard.

## 11. Build/test result

Build succeeded with:

```text
xcodebuild -project 'dMagy Picture Prep.xcodeproj' -scheme 'dMagy Picture Prep' -destination 'platform=macOS' build
```

No app run or manual UI test was performed.

## 12. Manual test checklist

1. Open the dMPS Flagged Report window.
2. Import the sample dMPS Flagged Review Queue.
3. Confirm the summary has one combined `ready to tag as Flagged` count.
4. Confirm the summary no longer has a separate top-level `ready to create saved information` count.
5. Confirm missing saved information still has useful detail text.
6. Confirm unreadable saved-information wording points the user to open the picture in dMPP and review why it was flagged.
7. Right-click a picture row and confirm `Show Picture in Finder` reveals an existing file.
8. Confirm `Show Picture in Finder` is disabled when the picture file is missing.
9. Confirm `Copy Original Path` copies an available queue path.
10. Confirm no `.dmpms.json` files are created, changed, or deleted.
11. Confirm no original picture files are changed.

## 13. Follow-up concerns

Phase 4B should still wait for the planned tolerant dMPMS decoding and unknown-field preservation work before any batch write path is enabled.
