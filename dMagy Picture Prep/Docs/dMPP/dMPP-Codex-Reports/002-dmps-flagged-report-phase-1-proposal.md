# dMPS Flagged Report Phase 1 Implementation Proposal

## 1. Executive Summary

Phase 1 should add a small, isolated read-only import foundation for dMPS Flagged Pictures Reports. The goal is to parse the dMPS JSON report, validate its structure, normalize the imported intent into dMPP-owned models, and create an in-memory import session that can later feed a review queue.

This phase must not write `.dmpms.json` sidecars, update tags, append curator notes, create review UI, or change app behavior. dMPS remains the app that records slideshow review intent. dMPP remains the only app that can later apply durable picture information through its existing dMPMS sidecar model and writer.

Recommended Phase 1 shape:

- Add isolated report/import model files under a new source grouping such as `Source/Imports/DMPSFlaggedReport/`.
- Add parser and validator types that can be unit-tested without SwiftUI, AppKit panels, archive stores, or sidecar writes.
- Add a path-resolution placeholder that classifies report paths against a supplied Picture Library Folder URL, but does not relink or persist mappings yet.
- Add tests using `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`.

## 2. Current Code Survey

Required docs reviewed:

- `Docs/dMPP/dMPP-Codex-Reports/001-dmps-flagged-report-import-design.md`
- `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`
- `Docs/dMPP/dMagy Project Collaboration Guide.md`
- `Docs/dMPP/dMPP-AI-Collaboration.md`
- `Docs/dMPP/dMagy Design Standards.md`
- `Docs/dMPP/dMPP-Context-v17.md`
- `Docs/dMPMS/README.md`
- `Docs/dMPMS/dMPMS-v1.0.md`

Current relevant code surfaces:

- `dMPP/dMagy_Picture_PrepApp.swift`
  - App owns shared stores and injects them with `environmentObject`.
  - File/menu commands currently live in the app scene and post notifications for editor actions.
  - Later UI/menu work should be very small here, but Phase 1 can avoid touching it.

- `dMPP/Source/Stores/DMPPArchiveStore.swift`
  - Owns Picture Library Folder selection, security-scoped bookmark persistence, and portable archive bootstrap.
  - Publishes `archiveRootURL`.
  - Later import entry points should use this as the source of the active Picture Library Folder.

- `dMPP/Source/Models/DmpmsMetadata.swift`
  - Defines the dMPMS sidecar model currently read and written by dMPP.
  - Includes `sourceFile`, `tags`, `curatorNotes`, crops, people, and workflow fields.
  - This file should not be changed in Phase 1.

- `dMPP/Source/Views/DMPPImageEditorView.swift`
  - Currently contains sidecar URL calculation, sidecar loading, unreadable sidecar handling, default metadata creation, save/write behavior, and Flagged review filtering.
  - `saveCurrentMetadata()` writes sidecars using pretty-printed JSON and `.atomic`.
  - `loadMetadata(for:)` decodes existing sidecars and falls back to default metadata when missing or unreadable.
  - `isFlaggedPhoto(_:)` checks `DmpmsMetadata.tags` for `Flagged` case-insensitively.
  - This concentration is useful context, but Phase 1 should avoid touching this large editor file.

- `dMPP/DMPPUserPreferences.swift`
  - Defines `reservedFlaggedTag = "Flagged"` and reserved tag ordering.
  - Includes case-insensitive reserved tag detection.

- `dMPP/Source/Stores/DMPPTagStore.swift`
  - Maintains portable `Tags/tags.json`.
  - Ensures reserved tags `Do Not Display` and `Flagged`.
  - Sanitizes and de-duplicates tags case-insensitively.
  - Phase 1 should not call tag persistence.

- `dMPP/Source/Services/DMPPPortableArchiveBootstrap.swift`
  - Defines the portable archive folder name and bootstrap behavior.
  - Phase 1 should not bootstrap anything as part of parsing.

- `dMagy Picture PrepTests/dMagy_Picture_PrepTests.swift`
  - Uses Swift Testing and is currently only a placeholder.
  - Phase 1 parser/session tests can fit here or in a new test file.

dMPMS constraints from the public spec:

- Sidecars are non-destructive and live beside images as `<photo filename>.dmpms.json`.
- Required fields are `dmpmsVersion` and `sourceFile`.
- Tags are plain `[String]`; `Flagged` is a normal human-readable tag.
- `curatorNotes` is the correct field name for curation notes.
- Readers should ignore unknown fields. Writers should preserve unknown fields when possible.

## 3. Proposed Phase 1 Scope

In scope:

- Decode the dMPS Flagged Pictures Report JSON.
- Represent top-level report fields and item fields as `Codable` Swift models.
- Validate schema, version, timestamps, item IDs, duplicate IDs, and locator presence.
- Create an in-memory import session that holds parsed items and validation results.
- Provide a path-resolution placeholder that classifies each item relative to a supplied Picture Library Folder URL.
- Add focused tests against the sample report and a few synthetic invalid reports.
- Document future integration boundaries in code comments using `// MARK:`.

Out of scope:

- Sidecar writes.
- Tag updates.
- Curator note updates.
- Existing sidecar repair or creation flows.
- Review queue UI.
- File menu commands.
- Xcode project changes until the implementation step explicitly permits them.
- Any new metadata-writing system.

## 4. Proposed New Types and Files

Use a narrow namespace prefix so these types are easy to find and easy to remove if the import design changes.

Recommended model/parser files:

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReport.swift`
  - `struct DMPSFlaggedReport: Codable, Equatable`
  - `struct DMPSFlaggedReportItem: Codable, Identifiable, Equatable`
  - `enum DMPSFlaggedReportRuntimeFlagState: String, Codable, Equatable`
  - `enum DMPSFlaggedReportSidecarStatusAtFlag: String, Codable, Equatable`

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportParser.swift`
  - `struct DMPSFlaggedReportParser`
  - `func parse(data: Data) -> DMPSFlaggedImportSession`
  - `func parse(fileURL: URL) throws -> DMPSFlaggedImportSession`
  - JSON decoding only. No AppKit panel. No sidecar inspection. No UI.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportValidation.swift`
  - `enum DMPSFlaggedReportValidationSeverity`
  - `enum DMPSFlaggedReportValidationCode`
  - `struct DMPSFlaggedReportValidationIssue`
  - `enum DMPSFlaggedReportItemValidationStatus`
  - `struct DMPSFlaggedReportValidationSummary`

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedImportSession.swift`
  - `struct DMPSFlaggedImportSession: Identifiable, Equatable`
  - `struct DMPSFlaggedImportSessionItem: Identifiable, Equatable`
  - Holds report identity, parsed items, validation issues, and path-resolution state.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedPathResolution.swift`
  - `enum DMPSFlaggedPathResolutionStatus`
  - `struct DMPSFlaggedResolvedPath`
  - `struct DMPSFlaggedPathResolver`
  - Placeholder classification only in Phase 1.

Each future file should use clear `// MARK:` sections such as:

- `// MARK: - Constants`
- `// MARK: - Codable Models`
- `// MARK: - Validation`
- `// MARK: - Session Construction`
- `// MARK: - Path Classification`

## 5. Proposed Validation Model

Use structured validation so the later review queue can filter and explain items without re-parsing.

Suggested severities:

- `info`
- `warning`
- `error`

Suggested top-level validation codes:

- `unreadableFile`
- `invalidJSON`
- `unsupportedSchema`
- `unsupportedSchemaVersion`
- `missingItems`
- `emptyItems`
- `invalidCreatedAt`
- `invalidUpdatedAt`

Suggested item validation codes:

- `missingID`
- `invalidID`
- `duplicateID`
- `missingLocator`
- `invalidFlaggedAt`
- `emptySuggestedReviewNote`
- `unexpectedRuntimeFlagState`
- `unexpectedSidecarStatusAtFlag`
- `suggestedTagsMissingFlagged`
- `absolutePathOutsideArchiveRoot`
- `imageFileMissing`
- `unsupportedImageExtension`

Recommended status model:

- `valid`
  - Item has a valid ID, valid timestamp, and at least one locator.

- `validWithWarnings`
  - Item can remain in the session but needs attention, such as missing `Flagged` in `suggestedDMPMSTags` or a missing file.

- `invalid`
  - Item cannot participate in future review actions because required identity or locator data is missing or malformed.

Validation should be tolerant where safe:

- Unknown JSON fields should be ignored.
- Optional fields should stay optional.
- A malformed item should not reject the entire report unless the top-level JSON cannot decode.
- Higher schema versions should become an error unless the known required fields are still present and the implementation deliberately allows best-effort parsing. For Phase 1, the conservative choice is to support only schema `com.dmagy.dmps.flaggedReviewQueue` version `1`.

## 6. Proposed Import Session Model

The session should be transient and in-memory only.

Suggested shape:

```swift
struct DMPSFlaggedImportSession: Identifiable, Equatable {
    var id: UUID
    var sourceReportURL: URL?
    var report: DMPSFlaggedReport?
    var createdAt: Date?
    var importedAt: Date
    var topLevelIssues: [DMPSFlaggedReportValidationIssue]
    var items: [DMPSFlaggedImportSessionItem]
}
```

Suggested item shape:

```swift
struct DMPSFlaggedImportSessionItem: Identifiable, Equatable {
    var id: String
    var reportItem: DMPSFlaggedReportItem
    var validationStatus: DMPSFlaggedReportItemValidationStatus
    var validationIssues: [DMPSFlaggedReportValidationIssue]
    var pathResolution: DMPSFlaggedResolvedPath
}
```

The session should not include mutable sidecar data in Phase 1. It can include enough future-facing structure to support read-only queue planning:

- original report item
- validation status
- raw absolute path if present
- raw relative path if present in a future report
- suggested tags and note as advisory dMPS intent
- path-resolution classification

The session should not persist itself. If a later phase wants session logs, that should be a separate explicit design.

## 7. Path Resolution Boundary for Phase 1

Phase 1 should classify paths, not solve the full relinking problem.

Inputs:

- `DMPSFlaggedReportItem`
- optional active Picture Library Folder URL
- `FileManager` dependency, defaulting to `.default`

Suggested statuses:

- `notAttempted`
- `missingArchiveRoot`
- `absolutePathInsideArchiveRootExists`
- `absolutePathInsideArchiveRootMissing`
- `absolutePathOutsideArchiveRoot`
- `relativePathCandidateExists`
- `relativePathCandidateMissing`
- `filenameOnlyCandidate`
- `unresolved`
- `invalidLocator`

Recommended Phase 1 behavior:

- If no Picture Library Folder URL is provided, mark items `missingArchiveRoot` instead of failing parse.
- If `imageAbsolutePath` exists and is under the Picture Library Folder, classify as inside-root and note whether the file exists.
- If `imageAbsolutePath` is outside the Picture Library Folder, classify as outside-root. Do not map it yet.
- If a future report includes `relativePath`, join it to the Picture Library Folder and classify existence.
- Do not crawl the Picture Library Folder for filename matches in Phase 1. That can be expensive and belongs to a later review/relink phase.
- Do not store user relink choices or write mappings in Phase 1.

This keeps path resolution useful for tests and future UI without creating a hidden import behavior.

## 8. Files Likely Added

Implementation phase likely adds:

- `dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReport.swift`
- `dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportParser.swift`
- `dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportValidation.swift`
- `dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedImportSession.swift`
- `dMagy Picture Prep/dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedPathResolution.swift`
- `dMagy Picture PrepTests/DMPSFlaggedReportParserTests.swift`

If the Xcode project does not automatically include filesystem-synchronized files, the implementation phase may also need a targeted project update after the Swift files are added. That is intentionally not part of this proposal task.

## 9. Files Likely Touched

Phase 1 implementation should touch as few existing files as possible.

Likely touched:

- `dMagy Picture Prep.xcodeproj/project.pbxproj`
  - Only if the project requires explicit file references for the new Swift and test files.

Potentially touched later, but not Phase 1:

- `dMPP/dMagy_Picture_PrepApp.swift`
  - Later File menu entry and import command routing.

- `dMPP/Source/Stores/DMPPArchiveStore.swift`
  - Later convenience accessors may be useful, but Phase 1 can accept an archive root URL as a parser/session input.

- `dMPP/Source/Views/DMPPImageEditorView.swift`
  - Later review queue launch or navigation hooks might relate to current Flagged filtering, but Phase 1 should avoid this large file.

- `dMPP/Source/Models/DmpmsMetadata.swift`
  - Should not be touched for this import foundation.

- `dMPP/Source/Stores/DMPPTagStore.swift`
  - Should not be touched for this import foundation.

## 10. Risks and Open Questions

Risks:

- The sample report uses absolute paths only. Future dMPS exports may need relative paths or archive-root hints for portability.
- dMPP currently has sidecar read/write behavior embedded in `DMPPImageEditorView.swift`; later apply behavior may need extraction or an adapter to avoid duplicating writer logic.
- Existing sidecar writes encode `DmpmsMetadata` directly. The dMPMS spec asks writers to preserve unknown fields when possible, so a later write phase should revisit preservation risk before batch updates.
- The Xcode project may require manual file references for new files, which should be kept as a separate implementation step.
- Filename-only matching could produce false positives. It should remain out of Phase 1.

Open questions:

- Should dMPS add `relativePath` and `archiveRootHint` to future reports, or should dMPP derive relative paths only when possible?
- Should `suggestedDMPMSTags` be treated only as display context, or should later phases require `Flagged` to be present before offering the default apply action?
- Should duplicate item IDs invalidate only later duplicates or all copies of that ID?
- Should `createdBy` be constrained to `dMagy Picture Show`, or should schema/version be the only authoritative source check?
- Which image formats should the importer classify as supported in Phase 1: only the formats currently scanned by the editor, or the broader dMPMS list?

## 11. Phase 1 Manual Test Plan

Manual checks after implementation:

1. Parse the sample report at `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`.
2. Confirm the session contains 5 items.
3. Confirm schema is `com.dmagy.dmps.flaggedReviewQueue` and schema version is `1`.
4. Confirm all sample item IDs decode as UUID strings and remain stable as session item IDs.
5. Confirm each sample item preserves:
   - `imageAbsolutePath`
   - `flaggedAt`
   - `flagSource`
   - `runtimeFlagState`
   - `sidecarStatusAtFlag`
   - `suggestedDMPMSTags`
   - `suggestedReviewNote`
6. Run validation with no Picture Library Folder URL and confirm items are parse-valid but path status is `missingArchiveRoot`.
7. Run validation with a temporary Picture Library Folder containing matching copied filenames, if practical, and confirm inside-root existence classification works.
8. Run invalid JSON and confirm the parser returns or throws a structured top-level `invalidJSON` failure.
9. Run a report with duplicate IDs and confirm duplicate validation issues are attached.
10. Run a report with an item missing both `imageAbsolutePath` and future `relativePath`, and confirm that item is invalid without rejecting the entire report.
11. Confirm no `.dmpms.json`, `Tags/tags.json`, portable archive file, image file, user defaults entry, or project file is modified by parser/session tests.

Automated test recommendations:

- `testParsesSampleReport`
- `testRejectsUnsupportedSchema`
- `testRejectsUnsupportedSchemaVersion`
- `testMarksDuplicateItemIDs`
- `testMarksMissingLocatorInvalid`
- `testClassifiesMissingArchiveRootWithoutFailingParse`
- `testClassifiesAbsolutePathInsideArchiveRoot`
- `testDoesNotWriteFilesDuringParseOrValidation`

## 12. Recommended Next Codex Prompt for Implementation

```text
Implement Phase 1 of the dMPS Flagged Pictures Report import foundation only.

Use the proposal in:
dMagy Picture Prep/Docs/dMPP/dMPP-Codex-Reports/002-dmps-flagged-report-phase-1-proposal.md

Constraints:
- Add parser, Codable report models, validation types, import session model, and path-resolution placeholder.
- Add focused tests using Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json.
- Do not write sidecars.
- Do not update tags.
- Do not append curator notes.
- Do not create review UI.
- Do not add menu commands yet.
- Keep changes isolated and reviewable.
- Use clear // MARK: organization.

After implementation, run the relevant tests and show the changed-file summary.
```
