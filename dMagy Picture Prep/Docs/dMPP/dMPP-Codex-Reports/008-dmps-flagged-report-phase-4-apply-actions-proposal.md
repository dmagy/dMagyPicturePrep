# dMPS Flagged Report Phase 4 Apply Actions Proposal

## 1. Executive Summary

Phase 4 should introduce the first write-capable step for the dMPS Flagged Review Queue workflow, but it should do so carefully and in small pieces.

The user-facing goal is simple: after importing a dMPS Flagged Review Queue and inspecting current saved picture information, dMPP should let the user choose what to do for each ready item:

- Add the `Flagged` tag.
- Append the suggested review note.
- Apply both.
- Skip.

The architecture goal is more important: dMPP must apply durable saved picture information through the existing dMPP sidecar-writing behavior, not through a second metadata-writing system. Today, the main write behavior lives inside `DMPPImageEditorView.swift`, which is already very large. Phase 4 should not make that file larger. The safest path is to extract or wrap the existing sidecar read/modify/write behavior into a small focused service, then have the dMPS import workflow call that service.

Recommended implementation split:

1. Phase 4A: action selection, in-memory apply-state modeling, preview/result UI, no writes.
2. Phase 4B: focused saved-information apply service using the existing dMPP write semantics, then enable Apply for ready items.

If Phase 4 is kept as one implementation pass, it should still be organized as separate model, service, result, and subview files. Existing large files should receive only thin wiring.

## 2. Current Code Survey

Required docs reviewed:

- `Docs/dMPP/dMPP-Codex-Reports/001-dmps-flagged-report-import-design.md`
- `Docs/dMPP/dMPP-Codex-Reports/002-dmps-flagged-report-phase-1-proposal.md`
- `Docs/dMPP/dMPP-Codex-Reports/003-dmps-flagged-report-phase-1-implementation.md`
- `Docs/dMPP/dMPP-Codex-Reports/004-dmps-flagged-report-phase-2-proposal.md`
- `Docs/dMPP/dMPP-Codex-Reports/005-dmps-flagged-report-phase-2-implementation.md`
- `Docs/dMPP/dMPP-Codex-Reports/006-dmps-flagged-report-phase-3-sidecar-inspection-proposal.md`
- `Docs/dMPP/dMPP-Codex-Reports/007-dmps-flagged-report-phase-3-sidecar-inspection-implementation.md`
- `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`
- `Docs/dMPP/dMagy Project Collaboration Guide.md`
- `Docs/dMPP/dMPP-AI-Collaboration.md`
- `Docs/dMPP/dMagy Design Standards.md`
- `Docs/dMPP/dMPP-Context-v17.md`
- `Docs/dMPMS/README.md`
- `Docs/dMPMS/dMPMS-v1.0.md`

Relevant Swift code inspected:

- `dMPP/Source/Models/DmpmsMetadata.swift`
  - Defines the dMPMS sidecar model used by dMPP.
  - Includes `sourceFile`, `tags`, and `curatorNotes`, which are the Phase 4 fields to modify.
  - The custom decoder still requires several fields beyond the public dMPMS minimum, including `title`, `description`, `dateTaken`, `tags`, `people`, `virtualCrops`, and `history`.
  - The encoder writes known fields only. It does not preserve unknown JSON fields.

- `dMPP/Source/Views/DMPPImageEditorView.swift`
  - Contains the current sidecar URL helper: `imageURL.appendingPathExtension("dmpms.json")`.
  - Contains `loadMetadata(for:)`, which decodes current saved information, normalizes people, forces `metadata.sourceFile` to the current image filename, and returns default metadata for missing/unreadable sidecars.
  - Contains `makeDefaultMetadata(for:)`, used when no readable sidecar exists.
  - Contains `backupUnreadableSidecarIfNeeded(sidecarURL:)`.
  - Contains `saveCurrentMetadata()`, which normalizes metadata, sets `dmpmsVersion = "1.0"`, backs up unreadable sidecars when applicable, encodes with `JSONEncoder`, and writes using `Data.write(..., .atomic)`.
  - This is the current durable sidecar write path, but the file is too large to grow further.

- `dMPP/Source/ViewModels/DMPPImageEditorViewModel.swift`
  - Owns editable `DmpmsMetadata`.
  - Has a local `saveCurrentMetadata()` stub; actual sidecar writing is handled by the higher-level owner view.

- `dMPP/DMPPUserPreferences.swift`
  - Defines canonical reserved tag spelling: `static let reservedFlaggedTag = "Flagged"`.
  - Includes reserved tag enforcement for user preferences.

- `dMPP/Source/Stores/DMPPTagStore.swift`
  - Maintains the portable tag registry.
  - Ensures reserved tags exist in `tags.json`.
  - Sanitizes and de-duplicates tags case-insensitively.
  - Phase 4 should not need to update the tag registry just to add the reserved `Flagged` tag to a picture, because `Flagged` is already reserved and should already exist. If a future implementation detects the registry is missing `Flagged`, it should use existing tag-store behavior, not importer-specific registry writes.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportCoordinator.swift`
  - Owns the imported session and Phase 3 saved-information inspection results.
  - Is read-only today.
  - Should remain the import/session coordinator, not become the write engine.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportView.swift`
  - Presents the current import window.
  - Already has summary, list/detail, current saved-information status, suggested update, and per-item advanced details.
  - Should not absorb substantial write logic or large action UI code.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedSidecarInspection.swift`
  - Reads only the exact derived saved-information file.
  - Decodes `DmpmsMetadata`, reports current tags, `Flagged` presence, curator notes preview, and readiness.
  - Good read-only input for deciding which actions can be offered.

## 3. Large File / File Size Risk Survey

Current line counts from the survey:

```text
6558  dMPP/Source/Views/DMPPImageEditorView.swift
 749  dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportView.swift
 559  dMPP/dMagy_Picture_PrepApp.swift
 485  dMPP/Source/Models/DmpmsMetadata.swift
 459  dMPP/Source/Stores/DMPPTagStore.swift
 283  dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedSidecarInspection.swift
 160  dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportCoordinator.swift
```

Risk assessment:

- `DMPPImageEditorView.swift` is the biggest hotspot and should not receive Phase 4 logic.
- `DMPSFlaggedReportImportView.swift` is already large enough that Phase 4 action controls should be split into subviews.
- `dMagy_Picture_PrepApp.swift` should not be touched for Phase 4 unless new environment injection is unavoidable. No app-menu or window changes appear necessary.
- `DmpmsMetadata.swift` should not be modified for Phase 4 unless a separate, explicit compatibility task is created.
- `DMPPTagStore.swift` should not be used as a general action writer. At most, future implementation can rely on its existing reserved-tag normalization if the registry needs a repair outside this workflow.

Phase 4 should add new focused files instead of expanding these hotspots.

## 4. Proposed Phase 4 Scope

In scope:

- Add an in-memory action model for imported queue items.
- Let the user choose `Add Flagged tag`, `Append review note`, `Apply both`, or `Skip` per item.
- Provide batch choices for selected ready items and all ready items.
- Preview what will be changed before writing.
- Apply only to items that are ready:
  - valid report item
  - resolved picture path
  - picture exists
  - saved information file exists and is readable
  - `sourceFile` matches expected filename
- Write durable metadata through a focused saved-information apply service that reuses dMPP sidecar write semantics.
- Record per-item apply results in memory.
- Refresh Phase 3 saved-information inspection after successful writes.

Out of scope:

- Broad relinking.
- Repairing invalid saved-information files inside the import workflow.
- Creating missing saved-information files automatically.
- Editing original image files.
- Editing the dMPS report.
- Persisting import-session choices across app launches.
- Adding generic metadata-manager abstractions larger than this feature needs.
- Modifying `DMPPImageEditorView.swift` except as part of a separate extraction task.

## 5. Proposed User Workflow

Recommended normal workflow:

1. User imports a dMPS Flagged Review Queue.
2. dMPP shows the current Phase 3 summary:
   - pictures in review queue
   - ready to update
   - need attention
   - previously flagged in dMPP
3. User selects an item.
4. The detail pane shows:
   - what dMagy Picture Show flagged
   - current saved picture information
   - suggested update
   - action choice
5. For a ready item, the user can choose:
   - `Add Flagged tag`
   - `Add review note`
   - `Add tag and note`
   - `Skip`
6. For items that need attention, action controls are disabled with plain language, such as:

```text
This picture needs attention before dMPP can update saved information.
```

7. User can apply:
   - the selected item
   - selected ready items
   - all ready items
8. dMPP shows a confirmation/preview before durable writes:

```text
dMPP will update saved picture information for 4 pictures.
Original picture files will not be changed.
```

9. After apply, rows show:
   - `Updated`
   - `Skipped`
   - `Failed`
   - `Already up to date`
10. User can leave completed items visible, or use a small filter such as `Hide updated`.

User-facing wording should avoid `sidecar`, `dMPMS`, `JSON`, `schema`, and `sourceFile` in the normal path. Use:

- `saved information`
- `saved picture information`
- `information file`
- `ready to update`
- `needs attention`
- `previously flagged in dMPP`

Technical terms can remain under the existing per-item `Advanced details` disclosure.

## 6. Proposed Action Model

Add a small action/result model file:

```text
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyAction.swift
```

Proposed types:

```swift
enum DMPSFlaggedReviewAction: String, Codable, Equatable, CaseIterable {
    case pending
    case addFlaggedTag
    case appendReviewNote
    case addFlaggedTagAndAppendReviewNote
    case skip
}
```

```swift
enum DMPSFlaggedApplyState: String, Codable, Equatable {
    case pending
    case ready
    case skipped
    case applying
    case applied
    case failed
    case notEligible
}
```

```swift
struct DMPSFlaggedApplyChoice: Identifiable, Equatable {
    var id: String { itemID }
    var itemID: String
    var action: DMPSFlaggedReviewAction
    var state: DMPSFlaggedApplyState
    var lastResult: DMPSFlaggedApplyResult?
}
```

```swift
struct DMPSFlaggedApplyResult: Identifiable, Equatable {
    var id: UUID
    var itemID: String
    var action: DMPSFlaggedReviewAction
    var status: DMPSFlaggedApplyResultStatus
    var message: String
    var changedTags: Bool
    var changedCuratorNotes: Bool
    var informationFileURL: URL?
    var errorMessage: String?
}
```

```swift
enum DMPSFlaggedApplyResultStatus: String, Codable, Equatable {
    case applied
    case skipped
    case alreadyUpToDate
    case notEligible
    case failed
    case cancelled
}
```

Modeling rules:

- `pending` means no user choice yet.
- `skip` is an explicit user choice and should be retained in memory for the current session.
- `alreadyUpToDate` is a result, not a user action. It can happen when `Flagged` and the suggested note are already present.
- Apply choices should live in memory on a focused coordinator or view model, keyed by import session item ID.
- No apply choices should be persisted in Phase 4.

## 7. Proposed Apply Coordinator / Service

Use two small layers:

1. UI-facing coordinator/model:

```text
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyCoordinator.swift
```

Responsibilities:

- Own action choices for the current import session.
- Decide which items are eligible based on Phase 1 validation and Phase 3 inspection.
- Offer default action suggestions.
- Apply selected/all ready items by calling the write service.
- Store per-item apply results in memory.
- Ask the import coordinator to refresh saved-information inspection after writes complete.

2. File-write service:

```text
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedSavedInformationApplier.swift
```

Responsibilities:

- Receive one resolved import session item, its Phase 3 inspection result, and chosen action.
- Read the current saved-information file from the exact derived path.
- Validate that the picture still exists.
- Validate that saved information still decodes.
- Validate that `sourceFile` still matches the expected filename.
- Mutate only `tags` and/or `curatorNotes` as requested.
- Use shared dMPP write behavior to write the modified metadata atomically.
- Return `DMPSFlaggedApplyResult`.

The apply service should be dependency-injection friendly:

```swift
struct DMPSFlaggedSavedInformationApplier {
    var reader: DMPPMetadataReading
    var writer: DMPPMetadataWriting
    var fileManager: FileManager

    func apply(
        item: DMPSFlaggedImportSessionItem,
        inspection: DMPSFlaggedSidecarInspectionResult,
        action: DMPSFlaggedReviewAction
    ) -> DMPSFlaggedApplyResult
}
```

The protocol names above are illustrative. The key is to avoid baking AppKit, SwiftUI, or `DMPPImageEditorView` into the write path.

## 8. Existing Sidecar Writer Reuse

Current writer reality:

- The durable per-picture sidecar write currently lives in `DMPPImageEditorView.saveCurrentMetadata()`.
- It writes to `sidecarURL(for: vm.imageURL)`, where `sidecarURL(for:)` appends `.dmpms.json`.
- It sets `metadataToSave.dmpmsVersion = "1.0"`.
- It runs existing people normalization before saving.
- It backs up an unreadable sidecar only when the editor previously marked that exact sidecar as unreadable.
- It writes pretty-printed JSON with `Data.write(to:options: .atomic)`.
- It updates editor-local dirty-state and face-learning state after successful saves.

Why Phase 4 should not call `saveCurrentMetadata()` directly:

- It is tied to the editor's `vm`, selected image, warning banners, dirty tracking, identity store, and face-learning behavior.
- The import window is independent of the editor.
- Calling editor save behavior from the import workflow would couple two windows and make behavior harder to reason about.
- Adding import-specific branches to `DMPPImageEditorView.swift` would make the large-file problem worse.

Recommended reuse path:

- Extract the file-format write core from the editor into a small reusable service before enabling Phase 4 writes.
- Keep editor-only behavior in the editor.
- Let both the editor and the dMPS import applier call the shared service.

Suggested shared service:

```text
dMPP/Source/Services/DMPPSidecarMetadataIO.swift
```

Suggested responsibilities:

- `sidecarURL(for imageURL: URL) -> URL`
- `readMetadata(at sidecarURL: URL) throws -> DmpmsMetadata`
- `makeDefaultMetadata(for imageURL: URL) -> DmpmsMetadata`
- `writeMetadata(_ metadata: DmpmsMetadata, to sidecarURL: URL) throws`
- optional `backupUnreadableSidecar(at:) throws -> URL`

The first Phase 4 write implementation should probably use only:

- exact sidecar URL derivation
- read existing metadata
- atomic write existing metadata after tag/note mutation

Missing sidecars and invalid sidecars should remain not eligible in the first write-capable phase unless there is a separate explicit repair/create task. This avoids silently changing the workflow from "apply dMPS intent" into "repair or create saved information."

Unknown-field preservation:

- The dMPMS spec says writers should preserve unknown fields when possible.
- The current `DmpmsMetadata` encoder writes known fields only.
- Therefore Phase 4 writes may drop unknown fields if the sidecar contains fields outside `DmpmsMetadata.CodingKeys`.
- This is already true for current editor saves, but Phase 4 batch writes would amplify the risk.
- Recommendation: before enabling batch writes, decide whether Phase 4 accepts current editor behavior for consistency, or whether a separate unknown-field preservation improvement is needed first.

Atomic writes:

- Current editor writes use `Data.write(..., .atomic)`.
- The Phase 4 shared writer should use the same or a stricter atomic replace pattern.
- Avoid direct non-atomic writes.

Missing sidecars:

- Current editor creates default metadata when loading a picture without a sidecar, then writes it when the user saves.
- Phase 4 should not automatically create missing saved-information files in the first write-capable pass. Mark those items `Needs saved information file` and direct the user to open/save the picture in normal dMPP or wait for a later explicit create/repair phase.

Invalid sidecars:

- Current editor handles invalid saved information by showing a warning, returning default metadata, and backing up the unreadable file if the user saves.
- Phase 4 should not repair invalid files automatically. Mark them not eligible and show clear per-item failure/precondition text.

Source filename mismatch:

- Phase 3 already detects mismatches.
- Phase 4 should block writes for mismatches until a future repair/relink workflow exists.

## 9. Duplicate Prevention Rules

Flagged tag:

- Canonical spelling is exactly `DMPPUserPreferences.reservedFlaggedTag`, currently `Flagged`.
- Before adding, trim tags and compare case-insensitively.
- Remove empty tags.
- Do not append `Flagged` if any case variant already exists.
- If a case variant such as `flagged` exists, normalize it to `Flagged` during the write rather than adding a second tag.
- Preserve the order of existing non-empty tags as much as possible; append `Flagged` at the end unless dMPP later adopts reserved-tag ordering inside sidecars.

Review note:

- Use the report item's suggested note when present and non-empty.
- Fallback note:

```text
Flagged in dMagy Picture Show for later review.
```

- Detect duplicate notes by trimming whitespace and comparing either:
  - exact suggested note as a line/paragraph, or
  - exact Phase 4 formatted note if a prefix is added.
- Recommended Phase 4 format is plain and stable:

```text
Flagged in dMagy Picture Show for later review.
```

- Avoid timestamped prefixes in Phase 4 unless product design explicitly wants repeated event history. A stable note is easier to de-duplicate across re-imports.
- Append with a blank line separator only when existing curator notes are non-empty.
- Preserve existing curator notes exactly except for appending the new note.

Both:

- Apply tag and note independently.
- If one part is already present and the other is missing, perform only the missing part and report partial changes clearly:

```text
Updated: added review note. Flagged tag was already present.
```

Skip:

- Skip never writes.
- Skip should not mark the source report or saved information.

## 10. Failure Handling

Use partial success. One failed item should not stop the whole batch unless the user cancels before writes begin.

Preflight failures:

- Missing image:
  - Not eligible.
  - Message: `Picture file was not found.`

- Missing saved-information file:
  - Not eligible in the first write-capable phase.
  - Message: `This picture needs a saved information file before dMPP can update it from the queue.`

- Invalid saved-information file:
  - Not eligible.
  - Message: `dMPP could not read saved information for this picture. Open the picture in dMPP to repair it before applying queue actions.`

- Filename mismatch:
  - Not eligible.
  - Message: `The saved information appears to belong to a different picture.`

Write failures:

- Mark only that item `failed`.
- Preserve successful results for other items.
- Show the underlying error in advanced details or an expandable result row.
- Keep the chosen action so the user can retry.

User cancellation:

- If cancelled before confirmation, write nothing.
- If cancelled during a long batch, stop before the next item and report already completed items as applied. Do not try to roll back successful writes automatically.

Concurrent/stale state:

- Re-read the saved-information file immediately before each write.
- Re-check `sourceFile`, `Flagged`, and note presence at write time.
- If another process already applied the same change, return `alreadyUpToDate`.

Batch summary:

- Show counts:
  - updated
  - skipped
  - already up to date
  - failed
  - not eligible

## 11. Proposed UI Updates

Do not turn `DMPSFlaggedReportImportView.swift` into the action implementation file.

Recommended UI additions:

- Add a compact action picker in the selected item detail pane, under `Suggested update`.
- Add a small batch bar above the item list or below the summary:
  - `Apply Selected Ready Items`
  - `Apply All Ready Items`
  - optional `Set Selected to Skip`
- Add row state labels:
  - `Ready to update`
  - `Will add tag`
  - `Will add note`
  - `Will add tag and note`
  - `Skipped`
  - `Updated`
  - `Failed`
  - `Needs attention`
- Add a confirmation sheet before writes.

Recommended subviews:

```text
DMPSFlaggedApplyControlsView.swift
DMPSFlaggedApplySummaryView.swift
DMPSFlaggedApplyResultView.swift
DMPSFlaggedApplyConfirmationView.swift
```

Normal UI should avoid technical language. Advanced details can continue to expose troubleshooting fields such as item ID, image path, information file path, and filename match.

Do not show raw action enum names in the UI.

Suggested copy:

```text
dMPP can update saved picture information for ready items. Original picture files will not be changed.
```

```text
Choose what dMPP should add for this picture.
```

```text
Actions are applied only to saved picture information.
```

## 12. File-Size Control Plan

Existing large files that should not grow:

- `dMPP/Source/Views/DMPPImageEditorView.swift` at about 6,558 lines.
- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportView.swift` at about 749 lines.
- `dMPP/dMagy_Picture_PrepApp.swift` at about 559 lines.

Rules for Phase 4:

- Do not add write logic to `DMPPImageEditorView.swift`.
- Do not add a large action/result UI directly inside `DMPSFlaggedReportImportView.swift`.
- Do not add app-level behavior to `dMagy_Picture_PrepApp.swift` unless absolutely necessary.
- Keep action modeling separate from apply execution.
- Keep write execution separate from SwiftUI views.
- Keep formatting labels in small helpers or subviews.

Proposed responsibility split:

- `DMPSFlaggedApplyAction.swift`
  - Action enums, apply state, apply choice, apply result.

- `DMPSFlaggedApplyCoordinator.swift`
  - In-memory choices/results, eligibility, batch orchestration.

- `DMPSFlaggedSavedInformationApplier.swift`
  - Per-item durable update logic using shared dMPP metadata I/O.

- `DMPPSidecarMetadataIO.swift`
  - Small reusable sidecar read/write core extracted from editor behavior.

- `DMPSFlaggedApplyControlsView.swift`
  - Per-item action controls.

- `DMPSFlaggedApplySummaryView.swift`
  - Batch controls and result counts.

- `DMPSFlaggedApplyResultView.swift`
  - Per-item result/status display.

- Existing `DMPSFlaggedReportImportView.swift`
  - Thin composition only: place new subviews in the existing summary/list/detail layout.

- Existing `DMPSFlaggedReportImportCoordinator.swift`
  - Either remain read/import/inspection focused, or own a small `@Published var applyCoordinator` only if dependency injection is simpler. Prefer a separate apply coordinator.

Approximate file-size targets:

- New model/service files: under 250 lines each where practical.
- New subviews: under 250 lines each.
- Changes to `DMPSFlaggedReportImportView.swift`: ideally under 80 lines of wiring.
- Changes to `DMPPImageEditorView.swift`: zero for Phase 4, unless a separate extraction task is explicitly approved.

## 13. Files Likely Added

Recommended:

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyAction.swift`
- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyCoordinator.swift`
- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedSavedInformationApplier.swift`
- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyControlsView.swift`
- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplySummaryView.swift`
- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyResultView.swift`
- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyConfirmationView.swift`
- `dMagy Picture PrepTests/DMPSFlaggedSavedInformationApplierTests.swift`
- `Docs/dMPP/dMPP-Codex-Reports/009-dmps-flagged-report-phase-4-apply-actions-implementation.md`

Recommended if extracting shared write behavior:

- `dMPP/Source/Services/DMPPSidecarMetadataIO.swift`
- `dMagy Picture PrepTests/DMPPSidecarMetadataIOTests.swift`

## 14. Files Likely Modified

Likely:

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportView.swift`
  - Thin composition of action subviews.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportCoordinator.swift`
  - Reset apply state when importing/clearing sessions.
  - Refresh saved-information inspection after successful apply.

Possibly:

- `dMPP/Source/Views/DMPPImageEditorView.swift`
  - Only if a separate, deliberate extraction moves reusable sidecar I/O into `DMPPSidecarMetadataIO`.
  - Any touch should be mechanical and limited to calling the extracted service.

- `dMPP/Source/Services/DMPPSidecarMetadataIO.swift`
  - New service, if approved.

Avoid:

- `dMPP/dMagy_Picture_PrepApp.swift`
- `dMPP/Source/Models/DmpmsMetadata.swift`
- `dMPP/Source/Stores/DMPPTagStore.swift`
- Xcode project file, unless filesystem-synchronized groups unexpectedly fail.

## 15. Testing Plan

Unit tests:

- `addFlaggedOnlyAddsCanonicalTag`
- `addFlaggedDoesNotDuplicateCaseVariant`
- `appendNoteOnlyAppendsSuggestedNote`
- `appendNoteDoesNotDuplicateExistingSuggestedNote`
- `applyBothAddsMissingTagAndNote`
- `applyBothReportsAlreadyUpToDateWhenBothPresent`
- `skipDoesNotWrite`
- `missingImageIsNotEligible`
- `missingSavedInformationFileIsNotEligible`
- `invalidSavedInformationFileIsNotEligible`
- `sourceFilenameMismatchIsNotEligible`
- `writeFailureReturnsFailedResult`
- `reimportSameReportDoesNotDuplicateTagOrNote`

Manual tests:

1. Create a Git checkpoint before implementation.
2. Build in Xcode.
3. Import the sample dMPS Flagged Review Queue.
4. For a ready item without `Flagged`, choose `Add Flagged tag`, apply, and confirm only saved picture information changes.
5. For a ready item without the note, choose `Add review note`, apply, and confirm curator notes are appended.
6. Choose `Add tag and note`, apply, and confirm both are present.
7. Choose `Skip`, apply selected/all, and confirm no file changes for skipped items.
8. Re-import the same report and confirm no duplicate `Flagged` tag or duplicate review note.
9. Test an item already flagged in dMPP and confirm it is shown as previously flagged / already up to date.
10. Test missing saved-information file and confirm it is not silently created.
11. Test invalid saved-information file and confirm it is not repaired by the import workflow.
12. Test a simulated write failure, such as a locked or unwritable information file, and confirm the batch reports partial success.

Recommended command when approval is given:

```text
xcodebuild test -project "dMagy Picture Prep.xcodeproj" -scheme "dMagy Picture Prep" -destination "platform=macOS"
```

## 16. Rollback and Safety Plan

Before implementing write behavior:

- Create a Git checkpoint from the current clean state.
- Keep Phase 4 changes grouped by file responsibility.
- Prefer implementing Phase 4A action selection first without writes.
- Only enable writes after the apply service has focused unit tests.

Rollback:

- If action-selection UI behaves poorly, revert only the new apply UI/model files and thin view wiring.
- If write behavior is wrong, revert the apply service and disable Apply controls while keeping the read-only import window.
- Because writes are durable, do not rely on undoing in-app state. Use Git for code rollback and file backups or disposable test fixtures for data rollback.

Safety:

- Apply should require a confirmation step.
- Apply should preflight every item before writing.
- Apply should re-read current saved information immediately before writing.
- Apply should use atomic writes.
- Apply should never modify original image files.
- Apply should not repair invalid saved information or create missing saved-information files in the first write-capable pass.
- A dry-run/preview state is useful and should be part of Phase 4A:
  - show how many tags would be added
  - show how many notes would be appended
  - show which items are skipped/not eligible
  - show that original picture files will not be changed

Recommendation:

- Split Phase 4 into Phase 4A and Phase 4B unless Dan explicitly wants one larger implementation pass.
- Phase 4A: action choices, preview, and result-state UI with Apply disabled or dry-run only.
- Phase 4B: shared sidecar metadata I/O extraction and real writes through `DMPSFlaggedSavedInformationApplier`.

## 17. Risks and Open Questions

Risks:

- Existing `DmpmsMetadata` writes do not preserve unknown fields. This matches current editor behavior but is worth an explicit decision before batch writes.
- Existing durable write behavior is embedded in `DMPPImageEditorView.swift`. Extracting the reusable core must be small and carefully tested.
- Missing/invalid saved-information behavior differs between editor and import workflow. Phase 4 should intentionally block those cases rather than surprising users by creating or repairing files from the queue.
- The import view is already moderately large. Adding action controls directly will make it harder to review.
- Batch writes can produce partial success. The UI must make that ordinary and understandable, not scary.

Open questions:

- Should Phase 4A be its own implementation checkpoint before real writes?
- Should the appended review note include the dMPS flagged date, or stay stable for duplicate prevention?
- Should the action default be `Add tag and note` for ready items, or `pending` until the user chooses?
- Should completed items remain visible by default, or should the window offer `Hide updated`?
- Should missing saved-information files be deferred to normal editor save behavior, or should a later Phase 5 add explicit create support?
- Should unknown-field preservation be improved before batch writes, even though the current editor writer does not preserve unknown fields?

## 18. Recommended Next Codex Prompt for Phase 4 Implementation

```text
You are working in the local dMagy Picture Prep macOS Swift/SwiftUI repo.

Repo root:
/Users/danandamy/Developer/dMagy Picture Prep

Current checkpoint:
6622a5ea Add read-only saved information inspection

Task:
Implement Phase 4A only for the dMPS Flagged Review Queue workflow: in-memory action selection and preview UI, with no durable writes yet.

Hard boundary:
Do not write sidecars.
Do not update tags.
Do not append curator notes.
Do not modify original images.
Do not modify dMPMS sidecars.
Do not implement the real Apply writer yet.
Do not modify DMPPImageEditorView.swift.
Do not grow dMagy_Picture_PrepApp.swift.

Required reading:
- Docs/dMPP/dMPP-Codex-Reports/008-dmps-flagged-report-phase-4-apply-actions-proposal.md
- Docs/dMPP/dMPP-Codex-Reports/007-dmps-flagged-report-phase-3-sidecar-inspection-implementation.md
- Current Phase 1/2/3 files under dMPP/Source/Imports/DMPSFlaggedReport

Implementation scope:
- Add DMPSFlaggedApplyAction.swift with action/result/choice models.
- Add a small DMPSFlaggedApplyCoordinator.swift that owns in-memory choices and eligibility only.
- Add focused subviews for action controls and preview/result state.
- Modify DMPSFlaggedReportImportView.swift only for thin composition.
- Modify DMPSFlaggedReportImportCoordinator.swift only if needed to reset action state on import/clear.
- Keep all Apply/write controls disabled or dry-run only.

After implementation:
- Show the changed-file summary or diff.
- Do not run the app or tests unless you first ask.
```
