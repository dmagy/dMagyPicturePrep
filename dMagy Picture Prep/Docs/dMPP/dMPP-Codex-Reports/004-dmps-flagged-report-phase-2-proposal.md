# dMPS Flagged Report Phase 2 Proposal

## 1. Executive Summary

Phase 2 should make the Phase 1 dMPS Flagged Pictures Report importer visible and testable inside dMPP while remaining strictly read-only.

Recommended shape:

- Add a File menu entry named `Import dMPS Flagged Pictures Report…`.
- Require an active Picture Library Folder before import, because path classification is meaningful only relative to the current dMPP collection.
- Use an AppKit `NSOpenPanel` for JSON report selection.
- Parse the selected report with the existing `DMPSFlaggedReportParser(archiveRootURL:)`.
- Open an independent read-only import session window that summarizes report-level issues, item counts, validation status, and path classification.
- Keep all future metadata actions absent or disabled. Phase 2 should say clearly that dMPS recorded review intent and dMPP has not applied any saved information yet.

No sidecars, tags, curator notes, original image files, portable registries, or durable mappings should be changed in Phase 2.

## 2. Current Code Survey

Required docs reviewed:

- `Docs/dMPP/dMPP-Codex-Reports/001-dmps-flagged-report-import-design.md`
- `Docs/dMPP/dMPP-Codex-Reports/002-dmps-flagged-report-phase-1-proposal.md`
- `Docs/dMPP/dMPP-Codex-Reports/003-dmps-flagged-report-phase-1-implementation.md`
- `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`
- `Docs/dMPP/dMagy Project Collaboration Guide.md`
- `Docs/dMPP/dMPP-AI-Collaboration.md`
- `Docs/dMPP/dMagy Design Standards.md`
- `Docs/dMPP/dMPP-Context-v17.md`
- `Docs/dMPMS/dMPMS-v1.0.md`

Swift code inspected:

- `dMPP/dMagy_Picture_PrepApp.swift`
  - App owns shared stores through `@StateObject`.
  - Commands live on the main `WindowGroup`.
  - Existing app commands either call an app-owned store directly or post notifications handled by the editor.
  - Auxiliary windows already exist for Getting Started and Help using `Window("...", id:)`.
  - `DMPPArchiveRootGateView` already uses `@Environment(\.openWindow)`.

- `dMPP/Source/Stores/DMPPArchiveStore.swift`
  - Owns Picture Library Folder selection and security-scoped access.
  - Exposes `archiveRootURL` and `hasArchiveRoot`.
  - Uses `NSOpenPanel` and `NSAlert` for folder flows.

- `dMPP/Source/Views/DMPPImageEditorView.swift`
  - Handles current editor notifications for save/export/delete/face boxes.
  - Has file picker examples using `NSOpenPanel`.
  - Has existing alert and warning-banner styles.
  - Is large and should not be touched for Phase 2 unless there is no alternative.

- `dMPP/Source/Views/HelpView.swift`
  - Uses a simple list/detail layout suitable as a lightweight pattern.

- `dMPP/Source/Views/DMPPPeopleManagerView.swift`
  - Uses `NavigationSplitView` with left list and detail pane.

- Phase 1 importer files under `dMPP/Source/Imports/DMPSFlaggedReport/`
  - `DMPSFlaggedReportParser` accepts optional `archiveRootURL`.
  - `DMPSFlaggedImportSession` is transient and exposes `validationSummary`.
  - `DMPSFlaggedPathResolution` classifies paths but does not crawl, relink, inspect sidecars, or write mappings.

Project structure:

- The Xcode project uses filesystem-synchronized groups.
- Phase 1 added Swift and test files without modifying `project.pbxproj`.

## 3. Proposed Phase 2 Scope

In scope:

- Add an app-visible import entry point.
- Let the user select a dMPS Flagged Pictures Report JSON file.
- Parse the report into a `DMPSFlaggedImportSession`.
- Display the session in a read-only window.
- Show report-level validation issues.
- Show item-level status: valid, warning, invalid.
- Show path-resolution classification.
- Show counts: total, valid, warnings, invalid, unresolved/path issues.
- Preserve current app behavior outside this import window.

Out of scope:

- Sidecar writes.
- Tag updates.
- Curator note updates.
- Original image changes.
- Durable relinking/mapping.
- Review actions such as Add Flagged, Append Note, Both, or Skip.
- Loading current sidecar metadata for each item.
- Broad recursive file search.
- UI inside `DMPPImageEditorView`.

## 4. Proposed User Workflow

1. User selects or already has an active Picture Library Folder.

2. User chooses:

```text
File > Import dMPS Flagged Pictures Report…
```

3. If no Picture Library Folder is active, dMPP shows a clear alert:

```text
Choose a Picture Library Folder first.

dMPP uses the Picture Library Folder to check whether report items belong to this picture collection. No saved information will be changed.
```

Recommended buttons:

- `Choose Picture Library Folder…`
- `Cancel`

4. dMPP opens an `NSOpenPanel`.

Recommended panel behavior:

- Title: `Import dMPS Flagged Pictures Report`
- Message: `Choose a JSON report exported by dMagy Picture Show. dMPP will inspect it only; no saved information will be changed.`
- Prompt: `Import`
- Can choose files: yes
- Can choose directories: no
- Allows multiple selection: no
- Allowed file types: `.json` using `UTType.json`, with a fallback extension check if needed.
- Initial folder:
  - Last successful import folder if remembered.
  - Otherwise the active Picture Library Folder.
  - Otherwise user Documents folder.

5. On selection, dMPP parses with:

```swift
DMPSFlaggedReportParser(archiveRootURL: archiveStore.archiveRootURL).parse(fileURL:)
```

6. dMPP opens or updates the read-only import session window.

7. User reviews summary, report issues, and item details. The only available action is to close the window or choose another report.

## 5. Proposed UI Structure

Use an independent window rather than a sheet attached to the editor.

Reasons:

- The report is a session-level review object, not an edit to the current picture.
- The user may want to compare the report to the editor later.
- It keeps Phase 2 out of `DMPPImageEditorView`.
- It creates a natural place for Phase 3 review actions without disturbing the current editor.

Recommended window:

```text
Window("dMPS Flagged Report", id: "DMPS-Flagged-Report-Import")
```

Recommended layout:

- Top summary band:
  - Report filename
  - Created by / created at / updated at
  - Read-only status message:

```text
dMPS recorded review intent. dMPP has not changed saved information yet.
```

- Count row:
  - Total
  - Valid
  - Warnings
  - Invalid
  - Unresolved / path issues

- Left pane:
  - List of report items.
  - Row should show:
    - filename or last path component
    - flagged timestamp
    - status symbol/text: `Valid`, `Warning`, `Invalid`
    - path status text such as `In Picture Library Folder`, `Outside Picture Library Folder`, `Missing file`, `Unsupported type`

- Right detail pane:
  - Item ID
  - Full image path or relative path
  - Flagged at
  - Flag source
  - Runtime flag state
  - Sidecar status at flag time from dMPS
  - Suggested tags
  - Suggested review note
  - Validation issues for that item
  - Path classification:
    - status
    - candidate path
    - file exists yes/no
    - inside Picture Library Folder yes/no/unknown

- Report-level issues section:
  - Visible when top-level issues exist.
  - Prefer a compact warning/error list near the top or in a collapsible section.

Status language:

- `valid`: `Ready for later review`
- `validWithWarnings`: `Needs attention before review`
- `invalid`: `Cannot be reviewed yet`

Path language:

- `hasAbsolutePath`: `Found from report path`
- `hasRelativePath`: `Found from relative path`
- `outsideArchiveRoot`: `Outside current Picture Library Folder`
- `missingFile`: `File not found at report path`
- `unsupportedImageExtension`: `Unsupported image type`
- `missingLocator`: `No usable path in report`
- `notResolved`: `Not resolved`

Do not include Phase 3 buttons yet, or show them disabled under a clearly labeled future-actions area. The cleaner Phase 2 choice is to omit them and include a small note:

```text
Review actions will be added in a later phase. This window is inspection-only.
```

## 6. Proposed State Ownership

Use a small app-owned coordinator/view model for the import flow, not editor-local state.

Recommended type:

```swift
final class DMPSFlaggedReportImportCoordinator: ObservableObject
```

Responsibilities:

- Hold the current `DMPSFlaggedImportSession?`.
- Hold import error text, if any.
- Hold selected session item ID.
- Present the file picker.
- Parse selected report.
- Store last import folder preference if Phase 2 includes that small convenience.

State lifetime:

- App-scoped for the current app run.
- Not persisted except optional last import folder bookmark or path convenience.
- Inject into the import window as `environmentObject`.

Why app-scoped:

- The import command is app-level.
- The import window is independent of the editor.
- The session should survive focus changes between windows.
- It avoids adding more responsibility to `DMPPImageEditorView`.

Recommended app integration:

- Add `@StateObject private var flaggedReportImportCoordinator = DMPSFlaggedReportImportCoordinator()`.
- Inject `archiveStore` into the coordinator by method call when importing, not as a singleton.
- Add an import window scene that reads the coordinator.

Command routing recommendation:

- Prefer a direct command call in `dMagy_Picture_PrepApp.swift`:

```swift
flaggedReportImportCoordinator.importReport(archiveRootURL: archiveStore.archiveRootURL)
openWindow(id: "DMPS-Flagged-Report-Import")
```

- If `openWindow` is not available inside `.commands`, use a notification handled by `DMPPArchiveRootGateView`, mirroring the existing Help/Getting Started pattern.
- Avoid routing through `DMPPImageEditorView`.

## 7. Proposed Files Added

Recommended new files:

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportCoordinator.swift`
  - App-level import coordinator.
  - Owns current session and import errors.
  - Uses `NSOpenPanel` and Phase 1 parser.
  - No sidecar writer references.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportView.swift`
  - Main read-only import window view.
  - `NavigationSplitView` or `HSplitView` list/detail layout.
  - Uses `@EnvironmentObject var coordinator`.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportSummaryView.swift`
  - Optional extraction if the main view gets large.
  - Shows counts and read-only warning text.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportDetailView.swift`
  - Optional extraction for selected item details.

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportStatusFormatting.swift`
  - Small formatting helpers for status labels, symbols, and colors.
  - Keeps raw enum-to-display text out of the main view.

Tests:

- `dMagy Picture PrepTests/DMPSFlaggedReportImportCoordinatorTests.swift`
  - Test coordinator parsing behavior without opening real panels by injecting a selected URL or parser/file-picker abstraction.
  - If panel injection is too much for Phase 2, keep tests focused on view-model summary formatting and rely on manual UI tests for picker behavior.

All future Swift files should include the standard plain-English header:

- Purpose
- Dependencies & Effects
- Data Flow
- Section Index

Use `// MARK:` sections consistently.

## 8. Proposed Files Modified

Likely modified:

- `dMPP/dMagy_Picture_PrepApp.swift`
  - Add notification name or direct command wiring.
  - Add `@StateObject` coordinator.
  - Add File menu item.
  - Add `Window("dMPS Flagged Report", id: ...)`.
  - Inject `archiveStore` and coordinator into the new window.

Possibly modified:

- `dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportParser.swift`
  - Only if Phase 2 needs a tiny non-behavioral convenience for display, such as better top-level issue messages.
  - Avoid changing parser semantics unless a bug is found.

Not recommended for Phase 2:

- `DMPPImageEditorView.swift`
- `DmpmsMetadata.swift`
- `DMPPTagStore.swift`
- `DMPPUserPreferences.swift`
- `DMPPArchiveStore.swift`, unless a tiny public helper is needed and clearly justified.
- `project.pbxproj`, unless filesystem-synchronized groups do not pick up the new files.

## 9. Read-Only Safeguards

Code safeguards:

- Coordinator depends on `DMPSFlaggedReportParser`, not `DmpmsMetadata`, `DMPPTagStore`, or sidecar write helpers.
- No functions named `apply`, `save`, `write`, `updateTag`, or `appendNote` in Phase 2 import files.
- No calls to `Data.write`, sidecar URL helpers, tag persistence, or portable registry writes.
- Path resolution remains classification only.
- No broad recursive file search.
- No durable session log or relink mapping.

UI safeguards:

- Header states:

```text
Inspection only. dMPP has not changed saved information for these pictures.
```

- Detail pane states:

```text
Suggested by dMPS, not yet applied by dMPP.
```

- No Add Flagged / Append Note / Both / Skip buttons in Phase 2.
- If future action placeholders are shown, they must be disabled and visually separated under `Future actions`.

Behavior safeguards:

- Closing the window discards only the in-memory view state.
- Importing another report replaces the current session in memory.
- No automatic sidecar reads beyond the Phase 1 parser/path file existence checks.

## 10. Testing Plan

No app-running or build commands should be run during proposal work. For Phase 2 implementation, state commands before running them.

Manual tests after implementation:

1. Launch dMPP with no Picture Library Folder.
2. Choose `File > Import dMPS Flagged Pictures Report…`.
3. Confirm dMPP asks for a Picture Library Folder and does not open the report picker first.
4. Select a Picture Library Folder.
5. Import `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`.
6. Confirm the import window opens.
7. Confirm summary shows 5 total items.
8. Confirm the header says no saved information has been changed.
9. Confirm each item appears in the list with status and path classification.
10. Select each item and confirm details show report path, flagged date, suggested tag, and suggested note.
11. Import invalid JSON and confirm a readable report-level error.
12. Import unsupported schema/version and confirm errors are displayed without crash.
13. Close the window and confirm no sidecar, tag registry, image file, or project file is changed.

Suggested implementation verification command, to be approved before running:

```text
xcodebuild test -project "dMagy Picture Prep.xcodeproj" -scheme "dMagy Picture Prep" -destination "platform=macOS"
```

Before Phase 3, verify:

- The import window is useful without write actions.
- Counts and statuses match parser output.
- Outside-root and missing-file wording is clear.
- There is an obvious future location for review actions.
- No durable files are modified during import/inspection.

## 11. Risks and Open Questions

Risks:

- App-level command wiring in SwiftUI may require choosing between direct `openWindow` access and the existing notification pattern.
- Showing absolute paths can be visually noisy and may expose sensitive folder structure. Phase 2 should show filename prominently and full path in detail only.
- The Phase 1 parser currently treats existing absolute paths as valid even without an archive root. Phase 2 should parse with the active archive root so outside-root warnings are meaningful.
- If the import window is app-scoped, importing a second report replaces the first in memory unless multi-session support is designed later.

Open questions:

- Should the menu label use `dMPS` or `dMagy Picture Show`? Recommendation: use `Import dMPS Flagged Pictures Report…` in the menu and spell out dMagy Picture Show inside the window.
- Should Phase 2 remember the last import folder? Recommendation: yes, but only as a small convenience if it does not add security-scope complexity. Starting in the Picture Library Folder is acceptable for the first pass.
- Should invalid reports still open the import window? Recommendation: yes if a session exists with top-level issues; show the error state in the same window.
- Should Phase 2 show image thumbnails? Recommendation: no. Thumbnails are tempting but add file access, performance, and layout complexity. Use filename/path/status first.

## 12. Recommended Next Codex Prompt for Phase 2 Implementation

```text
Implement Phase 2 read-only app integration for the dMPS Flagged Pictures Report importer.

Use the proposal in:
dMagy Picture Prep/Docs/dMPP/dMPP-Codex-Reports/004-dmps-flagged-report-phase-2-proposal.md

Scope:
- Add a File menu entry: Import dMPS Flagged Pictures Report…
- Require an active Picture Library Folder before importing.
- Use NSOpenPanel to choose a .json report.
- Parse with the Phase 1 DMPSFlaggedReportParser using the active archive root.
- Show an independent read-only import session window with summary counts, report-level issues, item list, item detail, validation status, and path classification.
- Add focused tests where practical.

Hard boundaries:
- Do not write sidecars.
- Do not update tags.
- Do not append curator notes.
- Do not modify original image files.
- Do not implement Add Flagged, Append Note, Both, or Skip actions.
- Avoid touching DMPPImageEditorView.swift.
- Keep changes small, isolated, and reviewable.

Before running build/test commands, state the exact command and wait for approval.

After implementation, show the changed-file summary and report whether the sample report imports as expected.
```
