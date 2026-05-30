# dMPS Flagged Report Phase 3 Sidecar Inspection Implementation Report

## 1. Summary

Implemented Phase 3 read-only sidecar inspection for the dMPS Flagged Review Queue import workflow.

The import window still imports and displays the dMPS Flagged Review Queue. After a successful import, dMPP now inspects the current saved dMPMS sidecar state for each imported item and displays that information in the existing read-only import window.

This phase remains inspection-only. It does not add review actions or durable metadata changes.

## 2. Files Added

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedSidecarInspection.swift`
- `Docs/dMPP/dMPP-Codex-Reports/007-dmps-flagged-report-phase-3-sidecar-inspection-implementation.md`

## 3. Files Modified

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportCoordinator.swift`
- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportView.swift`

No app entry, Xcode project, editor, sidecar model, tag store, archive store, or sidecar-writing files were modified.

## 4. Sidecar Inspection Behavior

Phase 3 adds `DMPSFlaggedSidecarInspector`, a small read-only service that:

- Uses the existing Phase 1 resolved image candidate URL.
- Derives the sidecar path with the dMPMS convention: `<image filename>.dmpms.json`.
- Does not search recursively.
- Does not relink.
- Does not create missing sidecars.
- Reads only the exact derived sidecar file when present.
- Decodes current saved information into `DmpmsMetadata`.
- Reports missing images, missing sidecars, invalid sidecars, read errors, valid sidecars, sourceFile mismatches, current tags, whether `Flagged` is already present, and a curator notes preview.

The import coordinator now stores inspection results in memory, keyed by import session item ID. Results are replaced after each successful import and cleared when the session is cleared.

The import view now shows:

- sidecar count pills
- sidecar status in item rows
- a selected-item `Current saved information` section
- current tags
- whether `Flagged` is already present
- curator notes preview
- sidecar path/status/errors
- informational readiness for later apply actions

The sidecar section includes:

```text
dMPP is reading current saved information only. No sidecar has been changed.
```

## 5. Read-Only Safeguards

The Phase 3 inspector performs only read/classification work:

- `FileManager.fileExists`
- `Data(contentsOf:)`
- `JSONDecoder().decode(DmpmsMetadata.self, from:)`

It does not call:

- `JSONEncoder`
- `Data.write`
- sidecar save/write helpers
- `saveCurrentMetadata`
- `backupUnreadableSidecarIfNeeded`
- `makeDefaultMetadata`
- `DMPPTagStore`
- portable registry writes
- sidecar repair or creation flows

The UI does not include Add Flagged, Append Note, Both, Skip, or any other apply action.

## 6. Manual Test Plan

1. Build in Xcode.
2. Open dMPP.
3. Open the dMPS Flagged Report window.
4. Import `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`.
5. Confirm the window still shows 5 imported items.
6. Confirm sidecar summary counts appear.
7. Select each item and confirm the `Current saved information` section appears.
8. Confirm missing sidecars are shown as missing and are not created.
9. Confirm invalid sidecars are shown as invalid and are not repaired.
10. Confirm sidecar sourceFile mismatches are visible if present.
11. Confirm current tags and curator notes preview display for valid sidecars.
12. Confirm no `.dmpms.json` file timestamps, original image timestamps, tag registries, or portable archive data files change during inspection.

## 7. Build/Test Result

No build or test command was run, per instruction to ask before running build/test commands.

Recommended verification command when approved:

```text
xcodebuild test -project "dMagy Picture Prep.xcodeproj" -scheme "dMagy Picture Prep" -destination "platform=macOS"
```

## 8. Risks or Follow-ups

- The current `DmpmsMetadata` decoder may mark older or partial sidecars invalid if required fields are absent. Phase 3 reports that read-only instead of repairing it.
- Duplicate item IDs in invalid reports remain an existing UI limitation; the sidecar inspection map avoids crashing but item selection can still be ambiguous.
- Phase 4 should decide how to preserve unknown sidecar fields before any durable write behavior is introduced.
- A later large-report pass may want asynchronous inspection or progress, but synchronous inspection is intentionally small for Phase 3.
