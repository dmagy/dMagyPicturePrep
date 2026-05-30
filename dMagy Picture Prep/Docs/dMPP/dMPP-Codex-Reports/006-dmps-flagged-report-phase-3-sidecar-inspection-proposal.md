# dMPS Flagged Report Phase 3 Sidecar Inspection Proposal

## 1. Executive Summary

Phase 3 should add read-only sidecar inspection to the existing dMPS Flagged Review Queue import window.

Phase 1 parses and validates the dMPS report. Phase 2 lets the user import and inspect the report in dMPP without changing saved information. Phase 3 should keep that boundary intact while adding one more useful layer: for each resolved imported picture, dMPP should read the matching `.dmpms.json` sidecar, summarize its current state, and show whether the item appears ready for later apply actions.

Recommended shape:

- Add a small read-only sidecar inspector service under `dMPP/Source/Imports/DMPSFlaggedReport/`.
- Derive sidecar paths from the already classified image candidate URL by appending `.dmpms.json`.
- Read and decode `DmpmsMetadata` only; do not call editor save paths, tag stores, sidecar repair, sidecar creation, or registry writers.
- Store inspection results in memory on the import coordinator, keyed by import session item ID.
- Trigger inspection automatically after a successful import, with a manual `Refresh Sidecar Status` button if practical.
- Extend the existing import window with sidecar status, current tags, whether `Flagged` is already present, source-file match/mismatch, curator notes preview, and read/parse errors.

Phase 3 must remain read-only. It should not write sidecars, update tags, append curator notes, modify original images, create durable relink mappings, or implement Add Flagged / Append Note / Both / Skip.

## 2. Current Code Survey

Required docs reviewed:

- `Docs/dMPP/dMPP-Codex-Reports/001-dmps-flagged-report-import-design.md`
- `Docs/dMPP/dMPP-Codex-Reports/002-dmps-flagged-report-phase-1-proposal.md`
- `Docs/dMPP/dMPP-Codex-Reports/003-dmps-flagged-report-phase-1-implementation.md`
- `Docs/dMPP/dMPP-Codex-Reports/004-dmps-flagged-report-phase-2-proposal.md`
- `Docs/dMPP/dMPP-Codex-Reports/005-dmps-flagged-report-phase-2-implementation.md`
- `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`
- `Docs/dMPP/dMagy Project Collaboration Guide.md`
- `Docs/dMPP/dMPP-AI-Collaboration.md`
- `Docs/dMPP/dMagy Design Standards.md`
- `Docs/dMPP/dMPP-Context-v17.md`
- `Docs/dMPMS/README.md`
- `Docs/dMPMS/dMPMS-v1.0.md`

Relevant Swift code inspected:

- `dMPP/Source/Models/DmpmsMetadata.swift`
  - Defines the app's current dMPMS sidecar model.
  - Exposes `sourceFile`, `tags`, and `curatorNotes`, which are the Phase 3 fields needed for inspection.
  - Decoding is backwards-compatible for some optional fields, but several fields are still decoded as required in the current model. Invalid or older sidecars can throw and must be reported as inspection errors.
  - Encoding does not preserve unknown fields. Phase 3 should not encode at all.

- `dMPP/Source/Views/DMPPImageEditorView.swift`
  - Contains the current editor-local sidecar URL helper:

```swift
imageURL.appendingPathExtension("dmpms.json")
```

  - Contains editor-local read helpers such as `hasSidecar(for:)`, `isFlaggedPhoto(_:)`, and `loadMetadata(for:)`.
  - `loadMetadata(for:)` is not a good Phase 3 dependency because it mutates editor warning state, normalizes metadata, sets `metadata.sourceFile` to the current image filename, and returns default metadata when sidecars are missing or unreadable. For import inspection, missing and invalid sidecars must remain visible as missing/invalid, not become default metadata.
  - `saveCurrentMetadata()` writes sidecars using `JSONEncoder` and `Data.write(..., .atomic)`. Phase 3 must not call it or recreate its write behavior.

- `dMPP/DMPPUserPreferences.swift`
  - Defines the canonical reserved tag:

```swift
static let reservedFlaggedTag = "Flagged"
```

  - Phase 3 can use this constant for case-insensitive inspection, but must not call tag-store persistence.

- `dMPP/Source/Imports/DMPSFlaggedReport/`
  - Phase 1/2 files are already grouped and should remain the home for this feature.
  - `DMPSFlaggedResolvedPath` stores `candidateURL`, `fileExists`, and root classification.
  - `DMPSFlaggedReportImportCoordinator` owns the current in-memory session and import errors.
  - `DMPSFlaggedReportImportView` already displays summary, list, item details, report intent, suggested tags, suggested review note, and path classification.

Current dMPMS spec constraints:

- Sidecars are named `<photo filename>.dmpms.json`.
- `dmpmsVersion` and `sourceFile` are required.
- `tags` is a human-readable array of strings.
- `curatorNotes` is the curator-facing notes field.
- Readers should ignore unknown fields. Writers should preserve unknown fields when possible.
- Phase 3 is read-only, so unknown-field preservation risk is relevant for later writing phases but not directly for this phase.

## 3. Proposed Phase 3 Scope

In scope:

- For each imported item with a usable resolved image candidate, derive the expected sidecar URL.
- Check whether the sidecar exists.
- Decode existing sidecars into `DmpmsMetadata`.
- Report sidecar status:
  - not inspected
  - unresolved image
  - image missing
  - sidecar missing
  - sidecar valid
  - sidecar invalid
  - source-file mismatch
- Expose current sidecar tags.
- Show whether `Flagged` is already present, using case-insensitive comparison against `DMPPUserPreferences.reservedFlaggedTag`.
- Expose a compact curator notes preview.
- Show read/parse error text for invalid sidecars.
- Compute a read-only readiness classification for later apply actions.
- Update the import window to display sidecar inspection status and counts.

Out of scope:

- Sidecar creation.
- Sidecar repair.
- Sidecar writes.
- Tag updates.
- Curator note appends.
- Original image modifications.
- Add Flagged / Append Note / Both / Skip actions.
- Broad recursive file search.
- Durable relink mappings.
- A new generic metadata manager or second metadata-writing system.

## 4. Proposed Sidecar Discovery

Sidecar discovery should be deterministic and local to the already resolved item path.

Algorithm per item:

1. If `item.pathResolution.candidateURL` is nil, return `unresolvedImage`.
2. If `item.pathResolution.fileExists == false`, return `imageMissing`.
3. If the path status is `missingLocator`, `missingFile`, `notResolved`, `outsideArchiveRoot`, or `unsupportedImageExtension`, do not search elsewhere. Return the matching inspection status and include the path-resolution reason.
4. For `hasAbsolutePath` or `hasRelativePath`, derive:

```swift
let sidecarURL = imageURL.appendingPathExtension("dmpms.json")
```

5. If no file exists at `sidecarURL`, return `sidecarMissing`.
6. If a file exists, read and decode it as `DmpmsMetadata`.
7. Compare `metadata.sourceFile` with `imageURL.lastPathComponent`.
8. Return valid or source-file mismatch status with current tags and curator notes preview.

Unresolved items:

- Do not inspect sidecars.
- Show `No resolved picture path yet`.
- Keep the item visible and read-only.

Missing images:

- Do not inspect sidecars by guessing.
- Show `Picture file not found at report path`.
- Keep the existing Phase 2 path status visible.

No broad recursive search:

- Do not scan the Picture Library Folder for sidecars.
- Do not scan by filename.
- Do not search sibling folders beyond the exact derived sidecar path.
- Do not create or store a relink mapping.

## 5. Proposed Sidecar Inspection Model

Add a small model file:

```text
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedSidecarInspection.swift
```

Proposed types:

```swift
enum DMPSFlaggedSidecarInspectionStatus: String, Codable, Equatable {
    case notInspected
    case unresolvedImage
    case imageMissing
    case sidecarMissing
    case sidecarValid
    case sidecarInvalid
    case sourceFileMismatch
}
```

```swift
enum DMPSFlaggedSidecarReadiness: String, Codable, Equatable {
    case readyForFutureApply
    case alreadyFlagged
    case needsSidecar
    case needsRepair
    case needsResolvedImage
}
```

```swift
struct DMPSFlaggedSidecarInspectionResult: Identifiable, Equatable {
    var id: String
    var itemID: String
    var status: DMPSFlaggedSidecarInspectionStatus
    var readiness: DMPSFlaggedSidecarReadiness
    var imageURL: URL?
    var sidecarURL: URL?
    var sourceFile: String?
    var expectedSourceFile: String?
    var sourceFileMatches: Bool?
    var currentTags: [String]
    var containsFlaggedTag: Bool
    var curatorNotesPreview: String?
    var curatorNotesIsEmpty: Bool
    var errorMessage: String?
}
```

Add a focused read-only inspector:

```swift
struct DMPSFlaggedSidecarInspector {
    var fileManager: FileManager = .default

    func inspect(item: DMPSFlaggedImportSessionItem) -> DMPSFlaggedSidecarInspectionResult
    func inspect(items: [DMPSFlaggedImportSessionItem]) -> [String: DMPSFlaggedSidecarInspectionResult]
}
```

Fields to expose to the UI:

- status
- readiness
- sidecar filename/path
- sourceFile and expected filename
- source-file match/mismatch
- current tags
- `Flagged` already present: yes/no
- curator notes preview
- parse/read error message

Representing missing/invalid/mismatched sidecars:

- `sidecarMissing`: sidecar path is known, but no `.dmpms.json` exists.
- `sidecarInvalid`: file exists but cannot be read or decoded as `DmpmsMetadata`; show the underlying error in concise form.
- `sourceFileMismatch`: file decodes, but `sourceFile` does not match `imageURL.lastPathComponent`; show both values.
- `sidecarValid`: file decodes and `sourceFile` matches.

Readiness should be explanatory, not actionable yet:

- `readyForFutureApply`: sidecar decodes, sourceFile matches, `Flagged` is not present.
- `alreadyFlagged`: sidecar decodes and already contains `Flagged`.
- `needsSidecar`: sidecar is missing.
- `needsRepair`: sidecar invalid or source-file mismatch.
- `needsResolvedImage`: imported item does not have a usable resolved image path.

## 6. Existing Sidecar Reader Reuse

Reuse:

- `DmpmsMetadata` for decoding.
- The sidecar naming convention from `DMPPImageEditorView.sidecarURL(for:)`: append `.dmpms.json` to the image URL.
- `DMPPUserPreferences.reservedFlaggedTag` for the canonical tag spelling.
- Existing Phase 1 path classification in `DMPSFlaggedResolvedPath`.

Do not reuse directly:

- `DMPPImageEditorView.loadMetadata(for:)`
  - It mutates editor-local warning state.
  - It normalizes people through editor dependencies.
  - It overwrites `metadata.sourceFile` with the current image filename, which would hide source-file mismatches.
  - It returns default metadata for missing/invalid sidecars, which would erase the distinction Phase 3 needs to show.

- `DMPPImageEditorView.saveCurrentMetadata()`
  - It writes sidecars.
  - It normalizes and changes metadata.
  - It backs up unreadable sidecars before replacement.
  - Phase 3 must not call write or repair paths.

- `DMPPTagStore`
  - It persists registry tag data.
  - Phase 3 only needs to inspect strings already present in a sidecar.

Reader adequacy:

- `DmpmsMetadata` exposes enough for Phase 3: `sourceFile`, `tags`, and `curatorNotes`.
- It does not preserve unknown fields through encode, but Phase 3 should not encode anything.
- If decoding fails because a sidecar is invalid or older than the current model tolerates, Phase 3 should report `sidecarInvalid` rather than falling back to default metadata.

Longer-term note:

- If Phase 4 introduces writes, unknown-field preservation must be reviewed separately before applying durable changes. Phase 3 should not solve that by adding a writer.

## 7. Proposed UI Updates

Keep the existing Phase 2 import window and add a compact sidecar inspection layer.

Summary area:

- Add count pills:
  - `Sidecars OK`
  - `Missing sidecars`
  - `Invalid sidecars`
  - `Already Flagged`
  - `Needs attention`

List rows:

- Keep filename, report validation status, and path status.
- Add one compact sidecar line, for example:
  - `Sidecar OK`
  - `Missing sidecar`
  - `Invalid sidecar`
  - `Already Flagged`
  - `Source file mismatch`

Detail pane:

- Add a new section after `Path`:

```text
Current saved information
```

Suggested rows:

- `Sidecar status`
- `Sidecar file`
- `sourceFile`
- `Expected sourceFile`
- `Flagged already present`
- `Current tags`
- `Curator notes`
- `Readiness for later apply`
- `Read error`, only when present

Curator notes preview:

- Show `No curator notes` when empty.
- If notes exist, show a preview trimmed to a sensible length such as 300-500 characters.
- Preserve line breaks enough to be readable, but keep the detail pane from becoming a full editor.
- Do not show an editable `TextEditor`.

User language:

- Keep the existing header language that this is inspection only.
- Add a short section note:

```text
dMPP is reading current saved information only. No sidecar has been changed.
```

Avoid Phase 4 action controls:

- Do not show Add Flagged / Append Note / Both / Skip.
- If readiness is shown, present it as status text only, not a button.

## 8. Proposed State Ownership

Recommendation: sidecar inspection belongs in the import coordinator plus a separate read-only inspector service.

Why:

- The coordinator already owns the current import session and import-window state.
- The inspector can stay a pure, injection-friendly service with no UI and no write capabilities.
- The session model can remain close to Phase 1 and not absorb mutable sidecar state.
- The import window can render results from the coordinator without learning file I/O details.

Proposed coordinator additions:

```swift
@Published var sidecarInspectionResults: [String: DMPSFlaggedSidecarInspectionResult] = [:]
@Published var sidecarInspectionErrorMessage: String?
```

Proposed coordinator methods:

```swift
func inspectSidecars()
func sidecarInspection(for itemID: String) -> DMPSFlaggedSidecarInspectionResult?
```

Automatic or manual:

- Inspect automatically after a successful import. This keeps the window useful without another required click.
- Add a small `Refresh Sidecar Status` button if it remains visually calm and clearly read-only.
- Inspection should be synchronous for the expected small reports. If reports become large, Phase 4 or later can move inspection to a task with progress.

Caching:

- Cache results only in memory.
- Clear results when the session is cleared.
- Replace results when a new report is imported.
- Do not persist inspection results or write them back into the dMPS report.

## 9. Files Likely Added

Recommended new file:

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedSidecarInspection.swift`
  - `enum DMPSFlaggedSidecarInspectionStatus`
  - `enum DMPSFlaggedSidecarReadiness`
  - `struct DMPSFlaggedSidecarInspectionResult`
  - `struct DMPSFlaggedSidecarInspectionSummary`
  - `struct DMPSFlaggedSidecarInspector`

Optional test file:

- `dMagy Picture PrepTests/DMPSFlaggedSidecarInspectionTests.swift`
  - Missing sidecar.
  - Invalid JSON sidecar.
  - Valid sidecar without `Flagged`.
  - Valid sidecar with `Flagged`.
  - Source-file mismatch.
  - Curator notes preview.

Optional UI extraction only if the current view gets unwieldy:

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedSidecarInspectionView.swift`
  - Small read-only detail section for current saved information.
  - Not necessary if the addition stays readable inside `DMPSFlaggedReportImportView.swift`.

Each new Swift file should include the standard plain-English header:

- Purpose
- Dependencies & Effects
- Data Flow
- Section Index

Use clear `// MARK:` sections.

## 10. Files Likely Modified

Likely modified:

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportCoordinator.swift`
  - Add in-memory sidecar inspection results.
  - Call the inspector after successful import.
  - Clear inspection results when clearing the session.
  - Add summary helpers.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportView.swift`
  - Add sidecar count pills.
  - Add sidecar status to item rows.
  - Add read-only sidecar detail section.
  - Keep selection local to the view.

Possibly modified:

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportValidation.swift`
  - Only if Phase 3 wants to reuse validation issue display for sidecar inspection issues. Recommendation: keep sidecar inspection status separate unless a concrete need appears.

Not recommended:

- `dMPP/Source/Views/DMPPImageEditorView.swift`
  - Avoid touching this large editor file for Phase 3.

- `dMPP/Source/Models/DmpmsMetadata.swift`
  - Do not change the sidecar model for this read-only phase.

- `dMPP/DMPPUserPreferences.swift`
  - Existing `reservedFlaggedTag` is enough.

- `dMPP/Source/Stores/DMPPTagStore.swift`
  - Phase 3 should not persist tag registries.

- `dMPP/dMagy_Picture_PrepApp.swift`
  - Phase 2 window wiring already exists. Phase 3 should not need new app commands.

- `project.pbxproj`
  - The project has been using filesystem-synchronized groups. Modify only if Xcode requires it.

## 11. Read-Only Safeguards

Naming safeguards:

- Use names like `Inspector`, `InspectionResult`, `Readiness`, and `currentTags`.
- Avoid method names such as `apply`, `save`, `write`, `updateTag`, or `appendNote`.

Code safeguards:

- The new inspector should call only:
  - `FileManager.fileExists`
  - `Data(contentsOf:)`
  - `JSONDecoder().decode(DmpmsMetadata.self, from:)`
- It should not call:
  - `JSONEncoder`
  - `Data.write`
  - `saveCurrentMetadata`
  - `backupUnreadableSidecarIfNeeded`
  - `makeDefaultMetadata`
  - `DMPPTagStore`
  - portable registry writes
  - sidecar repair or creation flows

Behavior safeguards:

- Missing sidecars stay missing.
- Invalid sidecars stay invalid.
- Source-file mismatches stay visible.
- No default metadata should be created during inspection.
- No backup sidecars should be created during inspection.
- No results should be persisted.

UI safeguards:

- Keep the existing inspection-only banner.
- Add sidecar wording such as:

```text
dMPP is reading current saved information only. No sidecar has been changed.
```

- Show readiness as informational text only.
- Do not add Phase 4 buttons.

Review safeguard:

- Before implementation is accepted, search the new Phase 3 files for:
  - `write`
  - `save`
  - `apply`
  - `append`
  - `JSONEncoder`
  - `Data.write`
  - `DMPPTagStore`

Some of these words may appear in comments describing what not to do; there should be no write-capable code path.

## 12. Testing Plan

Manual tests after implementation:

1. Build in Xcode.
2. Open the dMPS Flagged Report window.
3. Import `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`.
4. Confirm the window still shows 5 imported items.
5. Confirm sidecar status appears in the summary, list, and selected detail pane.
6. For a picture with a valid sidecar, confirm current tags and curator notes preview display.
7. For a picture already tagged `Flagged`, confirm `Already Flagged` appears.
8. For a picture with no sidecar, confirm `Missing sidecar` appears and no sidecar is created.
9. Temporarily create an invalid `.dmpms.json` beside a test image and confirm `Invalid sidecar` plus a readable error appears.
10. Temporarily create a sidecar whose `sourceFile` does not match the image filename and confirm `Source file mismatch` appears.
11. Confirm no Add Flagged / Append Note / Both / Skip buttons exist.
12. Confirm no `.dmpms.json` file timestamps, original image timestamps, portable registries, or tag files change during inspection.

Unit test opportunities:

- `sidecarMissing` for a resolved image with no sidecar.
- `sidecarInvalid` for malformed JSON.
- `sidecarValid` for a minimal valid sidecar.
- `sourceFileMismatch` when `metadata.sourceFile` differs from `imageURL.lastPathComponent`.
- `containsFlaggedTag` is true for `Flagged`, `flagged`, or `FLAGGED`.
- `containsFlaggedTag` is false when the tag is absent.
- curator notes preview trims long notes without changing the original sidecar content.
- unresolved and missing-image items do not attempt sidecar reads.

Suggested implementation verification command, to be approved before running:

```text
xcodebuild test -project "dMagy Picture Prep.xcodeproj" -scheme "dMagy Picture Prep" -destination "platform=macOS"
```

## 13. Risks and Open Questions

Risks:

- The current `DmpmsMetadata` decoder may reject some sidecars that the editor later repairs or replaces. For Phase 3, that is acceptable and should be shown as `Invalid sidecar`.
- Existing editor read helpers are private inside `DMPPImageEditorView`, so Phase 3 should duplicate only the tiny sidecar URL convention and decode path rather than depend on the editor.
- Automatic inspection after import performs file reads for every item. This is fine for small queues but may need progress or batching if reports become large.
- Current sidecar writes do not preserve unknown fields on encode, so Phase 4 should not blindly write through the current model without a separate unknown-field preservation decision.

Open questions:

- Should missing sidecars count as `Needs attention` or get their own top-level count only? Recommendation: both a specific count and inclusion in attention count.
- Should sidecar inspection require an active Picture Library Folder? Recommendation: no hard requirement if the report path resolves, but outside-root items should remain clearly marked and not searched.
- Should the inspector show full curator notes or only a preview? Recommendation: preview only in Phase 3, with full text selectable if the layout remains calm.
- Should invalid sidecars show raw decoder errors? Recommendation: show concise `localizedDescription` in the UI and keep fuller console logging out of Phase 3 unless needed.
- Should `sidecarStatusAtFlag` from dMPS be compared against current dMPP sidecar status? Recommendation: show both as separate facts, not as an error, because dMPS status was only a snapshot at flag time.

## 14. Recommended Next Codex Prompt for Phase 3 Implementation

```text
Implement Phase 3 read-only sidecar inspection for the dMPS Flagged Review Queue import window.

Use the proposal in:
dMagy Picture Prep/Docs/dMPP/dMPP-Codex-Reports/006-dmps-flagged-report-phase-3-sidecar-inspection-proposal.md

Scope:
- Add a small read-only sidecar inspection model/service under:
  dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/
- Derive sidecar paths from resolved image paths using:
  imageURL.appendingPathExtension("dmpms.json")
- Read existing sidecars with Data(contentsOf:) and JSONDecoder into DmpmsMetadata.
- Report sidecar exists/missing/invalid, sourceFile match/mismatch, current tags, whether Flagged is already present, curator notes preview, and readiness for later apply.
- Store inspection results in memory on DMPSFlaggedReportImportCoordinator.
- Update DMPSFlaggedReportImportView to show sidecar counts, list-row status, and selected-item sidecar details.
- Add focused tests if practical.

Hard boundaries:
- Do not write sidecars.
- Do not update tags.
- Do not append curator notes.
- Do not modify original images.
- Do not modify dMPMS sidecars.
- Do not implement Add Flagged / Append Note / Both / Skip actions.
- Do not create durable relink mappings.
- Do not touch DMPPImageEditorView.swift unless absolutely necessary.
- Do not introduce a generic metadata manager or second metadata-writing system.

Before running build/test commands, state the exact command and wait for approval.

After implementation, write a short implementation report and show the changed-file summary/diff.
```
