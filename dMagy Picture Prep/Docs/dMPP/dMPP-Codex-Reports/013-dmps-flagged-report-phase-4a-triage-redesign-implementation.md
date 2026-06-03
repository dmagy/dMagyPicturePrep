# 013 - dMPS Flagged Report Phase 4A Triage Redesign Implementation

Save path:

```text
Docs/dMPP/dMPP-Codex-Reports/013-dmps-flagged-report-phase-4a-triage-redesign-implementation.md
```

## 1. Executive Summary

Revised Phase 4A now frames the dMPS Flagged Review Queue import window as import triage, not a second review workflow.

The per-item action-choice model was removed and replaced with a no-write triage/import-plan model. The window now previews whether dMPP can safely bring dMPS flagged pictures into the normal dMPP `Flagged` review workflow later.

The primary future action is shown as:

```text
Tag Ready Pictures as Flagged
```

The button is disabled in Phase 4A. No saved information is changed.

## 2. Files Added

```text
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageStatus.swift
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageCoordinator.swift
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageSummaryView.swift
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageDetailView.swift
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageActionView.swift
```

## 3. Files Changed

```text
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportCoordinator.swift
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportView.swift
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedSidecarInspection.swift
```

Coordinator changes:

- Replaced the Phase 4A apply/action coordinator with `DMPSFlaggedTriageCoordinator`.
- Rebuilds the triage plan after import and saved-information inspection.
- Clears the triage plan when the session is cleared.

Import view changes:

- Removed per-item action picker UI.
- Added triage summary, action preview, and per-item triage detail subviews.
- Updated header and empty-state wording toward import triage.
- Kept existing item detail and advanced details available for troubleshooting.

Saved-information inspection change:

- Added a read-only `curatorNotesText` field and stable-note detection helper so triage can tell whether the stable dMPS review note is already present.

## 4. Files Removed or Renamed

Removed from the Phase 4A import workflow:

```text
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyAction.swift
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyCoordinator.swift
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyControlsView.swift
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyResultView.swift
dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplySummaryView.swift
```

These were replaced conceptually by the new `DMPSFlaggedTriage*` files. No persistent data migration is needed because the removed action choices were in-memory only.

## 5. Confirmation That No Sidecars Are Written

Confirmed. This implementation does not write sidecars, update tags, append curator notes, create `.dmpms.json` files, repair saved information, or persist triage results.

## 6. Confirmation That No Original Images Are Changed

Confirmed. No original image files are read for writing or modified.

## 7. Confirmation That DMPPImageEditorView.swift Was Not Touched

Confirmed. `DMPPImageEditorView.swift` was not edited.

## 8. Confirmation That dMagy_Picture_PrepApp.swift Was Not Touched

Confirmed. `dMagy_Picture_PrepApp.swift` was not edited.

## 9. Summary of the Revised Triage Workflow

After importing a dMPS Flagged Review Queue, dMPP now builds a no-write triage plan from:

- report validation
- path resolution
- current read-only saved-information inspection
- current `Flagged` tag presence
- current stable dMPS review note presence

The window shows:

- pictures in review queue
- ready to tag as Flagged
- ready to create saved information
- already updated
- need attention

The primary action area previews that future Phase 4B will tag ready pictures as `Flagged` and add:

```text
Flagged in dMagy Picture Show for later review.
```

Phase 4A keeps the button disabled and clearly says:

```text
Preview only. No saved information has been changed.
```

## 10. Status Bucket Definitions

`Ready to tag as Flagged`

- Picture is inside the current Picture Library Folder.
- Picture exists.
- Saved information is readable and belongs to the picture.
- The item does not already have both `Flagged` and the stable dMPS review note.

`Ready to create saved information`

- Picture is inside the current Picture Library Folder.
- Picture exists.
- No saved information exists yet.
- Phase 4A previews future creation only.

`Ready to add review note`

- `Flagged` already exists.
- The stable dMPS review note is missing.
- Phase 4B should add the note only.

`Already updated`

- `Flagged` exists.
- The stable dMPS review note exists.

`Needs attention`

- Invalid report item.
- Unresolved path.
- Outside current Picture Library Folder.
- Missing picture.
- Unsupported image extension.
- Unreadable saved information.
- Saved information appears to belong to a different picture.

## 11. Known Limitations

- Phase 4A does not write anything.
- The primary button is intentionally disabled.
- Tolerant decoding of public-valid minimal dMPMS sidecars is not implemented here.
- Unknown-field preservation is not implemented here.
- Shared sidecar metadata I/O is not implemented here.
- Phase 4B still needs a final dry-run/recheck confirmation before writes.

## 12. Phase 4B Prerequisites

Before enabling the batch write:

1. Implement tolerant decoding for public-valid minimal sidecars.
2. Preserve unknown fields during batch writes.
3. Create or extract a shared dMPP sidecar metadata I/O path.
4. Add a final dry-run/recheck confirmation.
5. Apply both the `Flagged` tag and stable dMPS review note to safe ready pictures.
6. Create saved information only for safe missing-information items inside the Picture Library Folder.
7. Do not auto-repair unreadable saved information.
8. Do not auto-fix saved information that appears to belong to a different picture.

## 13. Build/Test Result

Normal build succeeded:

```text
xcodebuild -project 'dMagy Picture Prep.xcodeproj' -scheme 'dMagy Picture Prep' -destination 'platform=macOS' build
```

Existing warning observed:

- `DMPPPhotoLocationReader.swift` uses `CLGeocoder`, deprecated in macOS 26.0 in favor of MapKit. This is unrelated to the Phase 4A triage redesign.

No app run was performed.

## 14. Manual Test Checklist

Recommended manual checks:

1. Open the dMPS Flagged Report window.
2. Import the sample dMPS Flagged Review Queue.
3. Confirm the page is framed as triage, not per-item review.
4. Confirm no per-item action picker is shown.
5. Confirm the primary button label is `Tag Ready Pictures as Flagged`.
6. Confirm the button is disabled/no-write in Phase 4A.
7. Confirm the window says no saved information has been changed.
8. Confirm ready items, already updated items, missing saved information, outside-folder items, unreadable saved information, and mismatched saved information have clear statuses where available.
9. Confirm no choices are stored as per-item actions.
10. Confirm no `.dmpms.json` files are created, changed, or deleted.
11. Confirm no original image files are changed.
