# Full Repository Source and Context Review

Save path:

```text
Docs/dMPP/dMPP-Codex-Reports/009-source-and-context-review-full-repo.md
```

## 1. Executive summary

- The prior limited review was directionally right about the largest source risk: `DMPPImageEditorView.swift` is the main hotspot at about 6,558 lines and should not absorb Phase 4 dMPS queue write logic.
- The prior `dmpmsVersion` concern is not a real repo mismatch. Current Swift code writes `"1.0"`, and the public dMPMS v1.0 spec says writers should write `"1.0"`.
- The real dMPMS/code mismatch is decoder tolerance: `dMPMS-v1.0.md` says only `dmpmsVersion` and `sourceFile` are required, but `DmpmsMetadata.init(from:)` currently requires several optional fields such as `title`, `description`, `dateTaken`, `tags`, `people`, `virtualCrops`, and `history`.
- Current docs and source are broadly aligned on the product direction: dMPP prepares archives, writes local saved information, leaves original pictures untouched, and does not become a slideshow app.
- `dMPP-Context-v17.md` is mostly current, but its headshot crop section still reads partly as future work even though the code already has headshot crop variants and person-linked headshot helpers.
- No repo file named `dMPP-AI-Context-v2.md` was found. If ChatGPT project files still include that file, it should be treated as stale external context and replaced or retired.
- Phase 4 should remain paused until the dMPMS decoder/write-risk decision is made, because Phase 4 would be the first importer-driven batch write path.
- The best next action is documentation/context cleanup plus a small explicit decision note on dMPMS decoder tolerance and unknown-field preservation before any write-capable implementation resumes.

## 2. Source/content alignment review

### What the code appears to do now

dMagy Picture Prep is a local-first macOS Swift/SwiftUI app for preparing picture collections. The code supports:

- Selecting a Picture Library Folder through `DMPPArchiveStore`.
- Creating and using `dMagy Portable Archive Data` under the selected root.
- Managing portable People, Tags, Locations, Crops, locks, and face index data.
- Editing per-picture `DmpmsMetadata`.
- Writing per-picture `.dmpms.json` sidecars beside images.
- Leaving original image files untouched during normal editing.
- Managing virtual crops, including headshot crop variants.
- Supporting manual and suggested/face-based people workflows.
- Importing dMPS Flagged Review Queue files through Phase 1/2/3 read-only groundwork.

The code does not appear to implement slideshow playback. dMPS import work is scoped to receiving review intent from dMagy Picture Show and preparing dMPP to apply durable saved picture information later.

### What the docs say the app should do

The current repo docs say dMPP should:

- Prepare picture collections rather than display slideshows.
- Save meaning beside original pictures rather than modifying original image files.
- Treat the Picture Library Folder as the root of a portable archive.
- Store shared archive data in `dMagy Portable Archive Data`.
- Write dMPMS v1.0 sidecars beside images.
- Keep dMPP local-first, with no analytics, cloud accounts, tracking, or network dependency.
- Preserve user meaning and avoid silent data loss.
- Keep large future changes small, reversible, and clearly proposed.

This is consistent with the app code at the product/architecture level.

### Mismatches or stale assumptions

- `dMPMS-v1.0.md` says only `dmpmsVersion` and `sourceFile` are required. The current Swift decoder requires more fields. This matters for dMPP reading minimal public-valid sidecars and for Phase 4 applying queue actions to sidecars that might be valid by spec but invalid to the app today.
- `dMPP-Context-v17.md` says "Headshot (Tight) / Headshot (Full) per-person tabs" and the planned model are future/planned. The code already includes `VirtualCrop.CropKind.headshot`, `HeadshotVariant.tight/full`, `headshotPersonID`, and helper methods such as `selectOrCreateHeadshotCrop(variant:personID:)`.
- The Phase 4 proposal correctly flags unknown-field preservation, but this review confirms it is not just theoretical. `DmpmsMetadata` encodes known fields only, so batch writes can drop unknown fields just like the current editor save path can.
- `DMPSFlaggedReportImportView.swift` still contains some stale helper functions that look left over from previous UI iterations, such as `countPill`, `statusText`, `statusSymbol`, `statusColor`, and `pathStatusText`. This is not urgent, but the file should be trimmed when next touched.

## 3. dMPMS/schema alignment review

### Current write version

The app currently writes:

```text
dmpmsVersion: "1.0"
```

Evidence:

- `DmpmsMetadata.swift` defaults `var dmpmsVersion: String = "1.0"`.
- `DMPPImageEditorView.saveCurrentMetadata()` explicitly sets `metadataToSave.dmpmsVersion = "1.0"` before encoding.
- `DMPPImageEditorView.makeDefaultMetadata(for:)` creates default metadata with `dmpmsVersion: "1.0"`.
- All current public example sidecars under `Docs/dMPMS/Examples/` use `"dmpmsVersion": "1.0"`.

### Public spec write version

`Docs/dMPMS/dMPMS-v1.0.md` says the public v1.0 standard writes:

```text
"dmpmsVersion": "1.0"
```

There is no current version mismatch between code and public spec. The older v1.1, v1.2, v1.3, and v1.4 specs are under `Docs/dMPMS/Draft Archives/` and should be treated as historical/archive only.

### Real mismatch: required fields

The public spec says:

- A sidecar requires only `dmpmsVersion` and `sourceFile`.
- All other fields are optional.
- Readers should tolerate missing optional fields.
- Readers should ignore unknown fields.

The current Swift decoder in `DmpmsMetadata.init(from:)` requires these fields:

- `dmpmsVersion`
- `sourceFile`
- `title`
- `description`
- `dateTaken`
- `tags`
- `people`
- `virtualCrops`
- `history`

It tolerates missing values for some newer fields, such as `curatorNotes`, `dateRange`, `gps`, `location`, `peopleV2`, `peopleV2Snapshots`, `peopleMethod`, `ignoredFaceNumbers`, and `faceAssignments`.

This means a public-valid minimal sidecar like:

```json
{
  "dmpmsVersion": "1.0",
  "sourceFile": "IMG_0001.jpg"
}
```

would be valid by spec but would not decode as `DmpmsMetadata` in the app today.

### Unknown fields

The spec says writers should preserve unknown fields when possible. The current app does not preserve unknown fields when it encodes `DmpmsMetadata`; it writes the known coding keys only.

This is already current editor behavior, so it is not a new Phase 4-specific defect. It becomes more important in Phase 4 because importer-driven batch writes could touch multiple sidecars at once.

### Recommendation before more implementation work

Recommended minimum decision before Phase 4 resumes:

- [documentation-only] Record that current dMPP writes `dmpmsVersion: "1.0"` and that the prior `1.1` mismatch concern is closed.
- [source organization] Decide whether Phase 4 should first add a tolerant dMPMS reader/update path for importer writes.
- [refactor-risk] If real writes are enabled in Phase 4B, consider extracting a small sidecar metadata I/O service and making its decoder tolerant of missing optional fields.
- [process/context] Decide whether unknown-field preservation is acceptable as "same as current editor save" for now, or whether batch writes should wait until preservation is improved.

Safest practical decision: do not change the public spec. The spec is already correct for the desired portable standard. Fix or wrap the reader/writer behavior when Phase 4B introduces writes.

## 4. Context file review

### `Docs/dMPP/dMPP-Context-v17.md`

- Purpose: Current app architecture, implementation reality, release posture, and v2 planning context.
- Current: Mostly current.
- Overlap: Overlaps with `dMPP Backlog.md` on v2 candidates and with `dMPP-AI-Collaboration.md` on guardrails.
- Classification: Both repo and ChatGPT project context.
- Recommended action: [documentation-only] Update the headshot section so implemented headshot variant/person-link support is not described entirely as future work. Add a short note that dMPS Flagged Review Queue Phases 1-3 exist and Phase 4 is paused pending source/context review.

### `Docs/dMPP/dMPP-AI-Collaboration.md`

- Purpose: Working brief for AI assistants on dMPP-specific guardrails.
- Current: Mostly current. It correctly points to `dMPP-Context-v17.md`.
- Overlap: Some overlap with the shared collaboration guide, but useful as a short dMPP-specific brief.
- Classification: Both repo and ChatGPT project context.
- Recommended action: [process/context] Keep this as the primary ChatGPT/Codex working brief. Add a note to treat `dMPP-Context-v17.md` as source of truth and Codex reports as phase history, not standing architecture unless current.

### `Docs/dMPP/dMagy Project Collaboration Guide.md`

- Purpose: Shared cross-project working agreement.
- Current: Current and aligned with how this repo is being worked.
- Overlap: Intentionally overlaps with `dMPP-AI-Collaboration.md` at a higher level.
- Classification: Both repo and ChatGPT project context.
- Recommended action: [process/context] Keep as shared rules. No urgent update needed.

### `Docs/dMPP/dMagy Design Standards.md`

- Purpose: Shared dMagy product voice, local-first design principles, and wording preferences.
- Current: Current and useful.
- Overlap: Some product framing overlaps with `dMPP-Context-v17.md`, but this is cross-suite and design-language focused.
- Classification: Both repo and ChatGPT project context.
- Recommended action: [process/context] Keep available to ChatGPT because it directly affects UI copy, especially "saved information" vs technical language.

### `Docs/dMPP/dMPP Backlog.md`

- Purpose: Living planning/backlog document.
- Current: Mostly current but should stay fluid.
- Overlap: Overlaps with `dMPP-Context-v17.md` in v2 candidates.
- Classification: Repo primary, ChatGPT project context optional.
- Recommended action: [documentation-only] Keep in repo as the living backlog. For ChatGPT project files, include either the whole file or a short synced summary only if project-file space is limited.

### `Docs/dMPMS/dMPMS-v1.0.md`

- Purpose: Public dMPMS v1.0 sidecar standard.
- Current: Current public spec.
- Overlap: Some field details overlap with `DmpmsMetadata.swift`, but this document is the standard, not app implementation notes.
- Classification: Both repo and ChatGPT project context.
- Recommended action: [process/context] Keep available to ChatGPT. Add no code-specific caveats to the public spec unless they belong in an implementation notes document.

### `Docs/dMPMS/README.md`

- Purpose: Entry point to the public dMPMS standard.
- Current: Current.
- Overlap: Minimal.
- Classification: Repo only, or ChatGPT project context only as a small pointer.
- Recommended action: [documentation-only] No urgent update.

### `Docs/dMPMS/Examples/*.dmpms.json`

- Purpose: Public example sidecars for the standard.
- Current: Current for spec examples.
- Overlap: Field examples overlap with spec sections.
- Classification: Repo primary; selectively include in ChatGPT project context if schema questions are common.
- Recommended action: [documentation-only] Keep. Note that `basic-photo.dmpms.json` demonstrates the decoder-tolerance mismatch because it omits several fields the current app decoder requires.

### `Docs/dMPMS/Draft Archives/*`

- Purpose: Historical draft specs/schema.
- Current: Historical only.
- Overlap: They intentionally conflict with current public version numbers.
- Classification: Historical/archive only.
- Recommended action: [process/context] Do not upload these to ChatGPT project context unless the task is specifically about historical migration. They can confuse model reasoning about current `dmpmsVersion`.

### `Docs/dMPP/Help/*.md`

- Purpose: User-facing in-app help content.
- Current: Mostly current and aligned with product behavior.
- Overlap: Overlaps with public product language and context docs, but at user-help level.
- Classification: Repo only, except selected topics can be included when working on Help or user-facing wording.
- Recommended action: [documentation-only] No urgent update. Minor formatting issue noticed in `Help/02-Sidecars-and-Portable-Archive-Data.md`: the "Curator Notes are stored..." paragraph has unexpected indentation.

### `Docs/dMPP/dMPP-Codex-Reports/*.md`

- Purpose: Phase design/implementation history, decision trail, and task-specific reports.
- Current: Current as historical records through `008`.
- Overlap: Phase reports intentionally overlap with each other.
- Classification: Repo only by default; current/relevant phase reports can be temporarily included in ChatGPT project context.
- Recommended action: [process/context] Do not treat all Codex reports as permanent context. For Phase 4, use `008` and this `009` as current working reports.

### `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`

- Purpose: Sample dMPS queue file used by parser/import tests and manual workflow checks.
- Current: Current for Phase 1-4 work.
- Overlap: Referenced by Codex reports and tests.
- Classification: Both repo and ChatGPT project context while dMPS import work is active.
- Recommended action: [process/context] Keep available for Phase 4 prompt context.

### Missing or external: `dMPP-AI-Context-v2.md`

- Purpose: Prior review referenced this as an AI context file.
- Current: Not found in this repository.
- Overlap: Unknown.
- Classification: If present only in ChatGPT project files, treat as stale external context.
- Recommended action: [process/context] Replace it with `dMPP-AI-Collaboration.md` plus `dMPP-Context-v17.md`, or mark it historical/archive if it must be retained.

## 5. Sync recommendation

### Files that should be in ChatGPT project context

Recommended standing context:

- `Docs/dMPP/dMagy Project Collaboration Guide.md`
- `Docs/dMPP/dMPP-AI-Collaboration.md`
- `Docs/dMPP/dMPP-Context-v17.md`
- `Docs/dMPP/dMagy Design Standards.md`
- `Docs/dMPMS/dMPMS-v1.0.md`

Recommended active-task context while dMPS import work continues:

- `Docs/dMPP/dMPP-Codex-Reports/008-dmps-flagged-report-phase-4-apply-actions-proposal.md`
- `Docs/dMPP/dMPP-Codex-Reports/009-source-and-context-review-full-repo.md`
- `Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json`

Optional/summarized:

- `Docs/dMPP/dMPP Backlog.md`
- selected `Docs/dMPP/Help/*.md` when working on Help or user-facing copy

Avoid as standing ChatGPT project context:

- `Docs/dMPMS/Draft Archives/*`
- all historical Codex reports at once
- stale external files such as `dMPP-AI-Context-v2.md`

### Source-of-truth recommendation

Use separate files by purpose, not one giant context file:

- Project/app truth: `dMPP-Context-v17.md`
- AI working rules: `dMPP-AI-Collaboration.md`
- Cross-project collaboration rules: `dMagy Project Collaboration Guide.md`
- Public standard: `dMPMS-v1.0.md`
- Active phase record: latest relevant Codex reports
- Future ideas: `dMPP Backlog.md`

This separation is already mostly in place. The needed improvement is not consolidation into one file; it is clearer project-context sync rules so stale ChatGPT project files do not compete with repo truth.

## 6. Large-file / responsibility review

### `DMPPImageEditorView.swift`

- Approximate line count: 6,558.
- Main responsibilities:
  - Main editor shell.
  - Folder selection, scanning, navigation, security-scoped access.
  - Crop pane and metadata pane hosting.
  - Face detection/recognition orchestration.
  - Save/dirty-state behavior.
  - Sidecar URL, load, default metadata, invalid-sidecar warning, backup, and write behavior.
  - Review filter helpers including `Flagged`.
- Risk:
  - High. It mixes UI, navigation, persistence, sidecar I/O, warning state, and feature orchestration.
  - It is navigable thanks to `// MARK:` anchors, but small changes can require wide scanning.
  - Phase 4 write behavior would make this worse if added here.
- Should future code avoid growing it:
  - Yes. Treat as "thin wiring only" unless a task specifically touches editor behavior.
- Possible extraction candidates:
  - [refactor-risk] Sidecar metadata I/O core.
  - [refactor-risk] Save/navigation command handling.
  - [refactor-risk] Tags section.
  - [refactor-risk] Curator notes/title/description sections.
  - [refactor-risk] Face recognition orchestration.
  - [refactor-risk] Folder scanning and review filtering.
- Timing:
  - Extract only when a related feature naturally touches the area. For Phase 4, only sidecar I/O extraction is directly relevant.

### `DMPPImageEditorViewModel.swift`

- Approximate line count: 1,652.
- Main responsibilities:
  - Per-image metadata view model.
  - Image loading/decoded image caching.
  - Default crop creation.
  - Crop creation, duplication, deletion, updates, history.
  - Headshot crop helpers.
  - EXIF date inference.
  - People/date reconciliation.
- Risk:
  - Medium/high. It owns much of the crop/headshot logic and some metadata derivation.
  - It is better organized than the editor view but still broad.
- Should future code avoid growing it:
  - Yes for unrelated features. Phase 4 dMPS queue work should not touch it.
- Possible extraction candidates:
  - [refactor-risk] Crop factory/default crop service.
  - [refactor-risk] Headshot crop selection/creation service.
  - [refactor-risk] EXIF date inference service if it grows.
- Timing:
  - Wait until crop/headshot work resumes.

### `DMPPSettingsView.swift`

- Approximate line count: 1,384.
- Main responsibilities:
  - Settings tabs for Crops, Locations, People, Tags, General.
  - Portable crop preset management.
  - Portable locations/tags UI.
  - Registry diagnostics rows.
  - UserDefaults settings.
- Risk:
  - Medium. It is broad but belongs to one conceptual window.
  - It has a good plain-English header and decent `// MARK:` organization.
- Should future code avoid growing it:
  - Yes, unless the work is clearly Settings-specific.
- Possible extraction candidates:
  - [source organization] Crop settings tab.
  - [source organization] Tags settings tab.
  - [source organization] Locations settings tab.
  - [source organization] Registry diagnostic rows.
- Timing:
  - Wait until a Settings-specific feature naturally touches it.

### `DMPPPeopleManagerView.swift`

- Approximate line count: 1,119.
- Main responsibilities:
  - People list/search.
  - Person detail editing.
  - Birth/additional identity versions.
  - Delete/reset learned face samples.
  - Linked-file details and local helpers.
- Risk:
  - Medium. It is a coherent feature view but large enough that future people-work could become hard to review.
  - It has `// MARK:` sections but lacks the newer full plain-English header format.
- Should future code avoid growing it:
  - Yes, unless people-management work requires it.
- Possible extraction candidates:
  - [source organization] Left pane/list.
  - [source organization] Birth editor.
  - [source organization] Additional identity event editor.
  - [source organization] Reset face samples UI.
- Timing:
  - Wait until People Manager work resumes.

### `DMPPIdentityStore.swift`

- Approximate line count: 796.
- Main responsibilities:
  - People registry storage.
  - Legacy-to-portable migration.
  - Record-per-person file reads/writes.
  - Normalization.
  - Person grouping, lookup, mutation.
- Risk:
  - Medium. It has real persistence responsibility and should be touched carefully.
  - It has a useful header, though not in the newer `Purpose / Dependencies & Effects / Data Flow / Section Index` format.
- Should future code avoid growing it:
  - Yes for non-People features.
- Possible extraction candidates:
  - [refactor-risk] Storage adapter for portable People files.
  - [refactor-risk] Normalization/migration helper.
- Timing:
  - Wait until People persistence changes are needed.

### `DMPSFlaggedReportImportView.swift`

- Approximate line count: 749.
- Main responsibilities:
  - dMPS queue window.
  - Header/empty state/session layout.
  - Summary tiles.
  - Item list/detail pane.
  - Current saved-information display.
  - Suggested update display.
  - Advanced details.
  - Formatting helpers.
- Risk:
  - Medium and rising. It is not huge yet, but Phase 4 action UI could push it into another large view if not split.
  - It has the newer plain-English header and clear `// MARK:` sections.
- Should future code avoid growing it:
  - Yes. Phase 4 should add subviews and keep this file as composition/wiring.
- Possible extraction candidates:
  - [source organization] Summary view.
  - [source organization] Item row view.
  - [source organization] Current saved-information detail view.
  - [source organization] Advanced details view.
  - [source organization] Formatting helper type.
- Timing:
  - Phase 4 is the natural moment to avoid further growth by adding new subview files.

### `dMagy_Picture_PrepApp.swift`

- Approximate line count: 559.
- Main responsibilities:
  - App entry.
  - App-owned stores.
  - Menu commands and notifications.
  - Main editor window.
  - Settings window.
  - Getting Started and Help windows.
  - dMPS Flagged Report window.
  - Archive root gate.
  - Store configuration on root changes.
  - Settings lock gate and heartbeat.
- Risk:
  - Medium. It is not as large as the editor, but it mixes app shell, gates, settings locking, toolbar shortcuts, and window routing.
  - It lacks the newer full plain-English file header.
- Should future code avoid growing it:
  - Yes. Phase 4 should not need changes here.
- Possible extraction candidates:
  - [source organization] Archive root gate view.
  - [source organization] Settings lock gate view.
  - [source organization] Notification names / app command definitions.
- Timing:
  - Wait until app shell or settings-lock work resumes.

### `DmpmsMetadata.swift`

- Approximate line count: 485.
- Main responsibilities:
  - Core dMPMS model.
  - Date range model.
  - Metadata coding keys/custom Codable behavior.
  - History and location models.
- Risk:
  - Medium because it is schema-critical, not because of size.
  - Any change affects reading/writing sidecars.
- Should future code avoid growing it:
  - Yes except schema-alignment work.
- Possible extraction candidates:
  - [source organization] Move date range, location, and history models into separate files if future schema work expands.
  - [refactor-risk] Tolerant decoder behavior should be a focused change with tests.
- Timing:
  - Decoder-tolerance work may need to happen before Phase 4B writes.

### `DMPPTagStore.swift`

- Approximate line count: 459.
- Main responsibilities:
  - Portable tags registry.
  - Reserved tags.
  - Legacy tag-file reads.
  - Sanitization and registry writes.
- Risk:
  - Low/medium. It is focused and already owns tag registry behavior.
  - Phase 4 should not call it for per-picture tag writes.
- Should future code avoid growing it:
  - Yes unless tag registry behavior changes.
- Possible extraction candidates:
  - [source organization] Tag sanitization helper if reused elsewhere.
- Timing:
  - Wait until tag-registry work resumes.

### `DMPPArchiveStore.swift`

- Approximate line count: 440.
- Main responsibilities:
  - Picture Library Folder selection.
  - Bookmark persistence.
  - Security-scoped access.
  - Portable archive bootstrap and folder-change warnings.
- Risk:
  - Medium because folder access is sensitive.
  - Size is acceptable but changes can affect app launch and persistence.
- Should future code avoid growing it:
  - Yes unless the feature is folder-access related.
- Possible extraction candidates:
  - [refactor-risk] Alert/open-panel presenter if folder-access UI grows.
- Timing:
  - Wait until folder access recovery work resumes.

## 7. Recommended changes

### Documentation-only

- Update `dMPP-Context-v17.md` to clarify implemented vs planned headshot support.
- Add a short current-phase note to `dMPP-Context-v17.md`: dMPS Flagged Review Queue Phases 1-3 are implemented; Phase 4 proposal exists; writes are paused pending dMPMS/source-context decision.
- Add a note to the dMPP docs or a small implementation note that current editor saves write `dmpmsVersion: "1.0"`; the old `1.1` concern is closed.
- Fix minor Help indentation in `Help/02-Sidecars-and-Portable-Archive-Data.md`.
- Optionally add a small "Document Types Reference" repo doc later, based on the draft section at the end of this report.

### Process/context

- Replace any ChatGPT project file named `dMPP-AI-Context-v2.md` with repo-current `dMPP-AI-Collaboration.md` and `dMPP-Context-v17.md`, or clearly mark it historical.
- Keep draft dMPMS specs out of standing ChatGPT context.
- For active dMPS queue work, include only current phase reports `008` and `009`, plus the sample queue JSON.
- Use `dMPP-Context-v17.md` as app/project truth, `dMPMS-v1.0.md` as public schema truth, and Codex reports as phase-specific decision history.

### Source organization

- For Phase 4A, add new action/model/subview files instead of adding substantial code to `DMPSFlaggedReportImportView.swift`.
- Remove stale helper functions from `DMPSFlaggedReportImportView.swift` when next touched, if confirmed unused.
- Add or improve plain-English headers when next touching:
  - `dMagy_Picture_PrepApp.swift`
  - `DMPPImageEditorViewModel.swift`
  - `DMPPPeopleManagerView.swift`
  - `DMPPUserPreferences.swift`
  - `DMPPIdentityStore.swift`
- Preserve existing `// MARK:` anchors, but use the newer `Purpose / Dependencies & Effects / Data Flow / Section Index` style for new files.

### Future refactor-risk items

- Extract sidecar metadata I/O from `DMPPImageEditorView.swift` into a small service before enabling importer-driven writes.
- Make dMPMS decoding tolerant of missing optional fields, with tests against `Docs/dMPMS/Examples/basic-photo.dmpms.json` and a minimal two-field sidecar.
- Decide whether to preserve unknown fields before batch writes, or document that Phase 4 uses the same known-field rewrite behavior as the editor.
- Eventually split `DMPPImageEditorView.swift` by responsibility, one extraction at a time, only when related feature work naturally touches that section.
- Consider extracting `DMPPArchiveRootGateView` and `DMPPSettingsLockGateView` from `dMagy_Picture_PrepApp.swift` when app-shell work resumes.

## 8. Phase 4 readiness note

Phase 4 implementation should remain paused for real writes until these minimum items are decided:

1. Decoder tolerance: Should Phase 4B require `DmpmsMetadata` to decode public-valid minimal sidecars, or should not-fully-populated sidecars remain not eligible?
2. Unknown fields: Is it acceptable for Phase 4 writes to match current editor behavior and rewrite known fields only, or should unknown-field preservation be improved first?
3. File-size control: Confirm Phase 4 will not add substantial logic to `DMPPImageEditorView.swift`, `dMagy_Picture_PrepApp.swift`, or the existing import view.

Phase 4A action selection and preview UI can proceed sooner if it remains no-write, isolated, and uses new files. Phase 4B real writes should wait for the sidecar I/O decision.

## 9. Proposed next step

Single best next action:

```text
Write a short context/schema decision note before Phase 4 resumes.
```

Why this first:

- It closes the incorrect `1.1` version concern.
- It names the real blocker: decoder tolerance and unknown-field preservation.
- It gives Phase 4 implementation a clear boundary before any durable writes are introduced.
- It is documentation/process work, so it does not risk changing app behavior.

Suggested scope:

- Update or add a small repo note summarizing:
  - code writes `dmpmsVersion: "1.0"`
  - public spec requires only `dmpmsVersion` and `sourceFile`
  - current decoder is stricter than the public spec
  - Phase 4B should not write until that behavior is deliberately accepted or improved

## Dan checklist draft

- Decide whether Phase 4 should split into Phase 4A no-write action selection and Phase 4B real writes.
- Retire or replace any old ChatGPT project file named `dMPP-AI-Context-v2.md`.
- Sync `dMPP-Context-v17.md`, `dMPP-AI-Collaboration.md`, `dMagy Project Collaboration Guide.md`, `dMagy Design Standards.md`, and `dMPMS-v1.0.md` into ChatGPT project context.
- Keep `008` and `009` available while Phase 4 is active.
- Make a small decision on whether dMPP should decode public-minimal dMPMS sidecars before importer writes are added.
- Decide whether unknown-field preservation must be solved before batch writes, or explicitly deferred.
- Keep Phase 4 implementation out of `DMPPImageEditorView.swift` unless extracting shared sidecar I/O is the specific task.
- When next touching the import view, split new Phase 4 UI into small subviews.

## Document types reference draft

- AI context: A short guide for AI assistants. Example: `dMPP-AI-Collaboration.md`.
- Collaboration guide: Cross-project rules for how Dan and AI assistants work. Example: `dMagy Project Collaboration Guide.md`.
- App context: Current architecture and product reality for one app. Example: `dMPP-Context-v17.md`.
- Public spec: External/public standard documentation. Example: `dMPMS-v1.0.md`.
- Backlog: Living list of possible future work. Example: `dMPP Backlog.md`.
- Help topic: User-facing in-app documentation. Example: `Help/04-Saving-Your-Work.md`.
- Codex report: Task-specific investigation, proposal, or implementation record. Example: `008-dmps-flagged-report-phase-4-apply-actions-proposal.md`.
- Phase proposal: A Codex report that designs a future implementation phase before code changes.
- Implementation report: A Codex report that records what changed after an implementation phase.
- Current phase note: A short active-work summary that says what phase is current, what is paused, and what boundaries matter next.
- Historical/archive doc: A retained older design/spec that should not guide current implementation unless explicitly referenced. Example: `Docs/dMPMS/Draft Archives/*`.
