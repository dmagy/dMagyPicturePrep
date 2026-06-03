# 012 - dMPS Flagged Report Phase 4A Triage Redesign Proposal

Save path:

```text
Docs/dMPP/dMPP-Codex-Reports/012-dmps-flagged-report-phase-4a-triage-redesign-proposal.md
```

## 1. Executive Summary

The dMPS Flagged Review Queue import window should become an import triage workflow, not a second review workflow.

The current Phase 4A implementation lets the user choose per-item actions such as Add Flagged tag, Add review note, Add both, or Skip. That is functional, but it pulls the import window toward a parallel review process. The better product direction is simpler:

1. Validate the queue.
2. Show which pictures dMPP can safely match.
3. Show which pictures need attention.
4. Offer one primary future batch action for safe items.
5. After Phase 4B writes, show clear per-item results.

Recommendation: replace the current per-item action-choice model with a no-write triage preview in revised Phase 4A, then implement durable batch updates in Phase 4B after the sidecar I/O decisions remain explicit.

Best primary button label:

```text
Mark Ready Pictures as Flagged
```

Supporting text:

```text
dMPP will update saved information for pictures it can safely match. Original picture files will not be changed.
```

This label is clearer than `Add Flagged Tag and Review Note` because it describes the curator outcome instead of implementation details. The detail text can explain that dMPP will add the `Flagged` tag and a stable curator note.

## 2. Product Decision

The import window should answer:

```text
Can dMPP safely bring these dMPS flagged pictures into my normal dMPP review workflow?
```

It should not ask the user to review every picture inside the import window.

dMPS records review intent during slideshow use. dMPP owns durable saved picture information and already has a normal `Flagged` review process. The import workflow should only bridge intent into that existing dMPP process.

Phase 4B should therefore apply both of these by default for safe items:

- the canonical `Flagged` tag
- a stable curator note, for example:

```text
Flagged in dMagy Picture Show for later review.
```

The dMPS report's suggested note can remain visible as source/report context, but the write path should use one stable dMPP-owned note unless Dan explicitly decides otherwise before implementation.

## 3. Current Phase 4A Issues

Current Phase 4A files inspected:

```text
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyAction.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyCoordinator.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyControlsView.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplyResultView.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedApplySummaryView.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportCoordinator.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedReportImportView.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedSidecarInspection.swift
```

The implementation is technically scoped and no-write, but it now conflicts with the new product direction:

- It models per-item choices, including `skip`, which makes the import window feel like a review queue.
- It asks users to decide between tag-only, note-only, both, or skip, when the desired product behavior is to mark all safe items consistently.
- It creates UI affordances for "Preview Selected Ready Item" and "Preview All Ready Items" that are less useful than a clear triage result and one future batch action.
- It treats missing saved information as not eligible, but the new Phase 4B direction says dMPP may create saved information for pictures inside the current Picture Library Folder.
- It uses `Apply` naming internally for a no-write preview. That was acceptable as scaffolding, but the redesign should use `triage` or `import plan` naming until real writes exist.
- It adds more UI to `DMPSFlaggedReportImportView.swift`, which is already large enough that future changes should be composed from smaller subviews.

The useful parts to keep are the separation pattern and the no-write boundary. The per-item action picker itself should be removed or deferred.

## 4. Proposed Triage Workflow

Recommended workflow:

1. User opens the dMPS Flagged Review Queue window.
2. User imports a dMPS Flagged Review Queue file.
3. dMPP validates the report and inspects current saved information.
4. dMPP shows a triage summary:
   - pictures in review queue
   - ready to mark as flagged
   - already flagged in dMPP
   - need attention
5. The normal path explains:

```text
dMPP can mark ready pictures as Flagged so they appear in your normal dMPP review workflow.
```

6. Revised Phase 4A keeps the primary action disabled or preview-only:

```text
Mark Ready Pictures as Flagged
```

7. Phase 4B enables that button and applies the stable batch update to safe items only.
8. After Phase 4B apply, the result summary shows:
   - updated
   - already updated
   - created saved information
   - needs attention
   - failed

The item detail pane remains useful for troubleshooting and confidence. It should not become the place where normal review decisions happen.

## 5. Proposed UI Changes

Remove from the normal UI:

- per-item action picker
- `Add Flagged tag` / `Add review note` / `Add tag and note` / `Skip` choice model
- `Preview Selected Ready Item`
- `Preview All Ready Items`
- "choices made" count

Replace with:

- a triage summary band
- one primary future batch action
- a plain preview of what dMPP will do
- a needs-attention list/filter
- item detail inspection for troubleshooting

Recommended primary summary boxes:

- `pictures in review queue`
- `ready to mark as flagged`
- `already flagged in dMPP`
- `need attention`

Recommended primary action area:

```text
Mark Ready Pictures as Flagged
```

Disabled/no-write Phase 4A text:

```text
Preview only. This step shows what dMPP can safely update. No saved information has been changed.
```

Phase 4B enabled text:

```text
dMPP will update saved information for pictures it can safely match. Original picture files will not be changed.
```

Detail pane normal-path sections:

- Import status
- Current saved information
- What dMPP will do
- Advanced details

Suggested "What dMPP will do" wording:

```text
When enabled, dMPP will add the Flagged tag and this curator note:
"Flagged in dMagy Picture Show for later review."
```

For already-updated items:

```text
This picture is already marked as Flagged in dMPP.
```

For needs-attention items:

```text
dMPP will not update this picture from the queue until the issue is resolved.
```

Avoid normal-path words:

- sidecar
- JSON
- schema
- dMPMS
- sourceFile
- decoder

Those terms can stay under `Advanced details`.

## 6. Proposed Status Buckets

Use two levels of status: pre-apply triage status and post-apply result status.

### Pre-Apply Triage Buckets

`Ready to mark as flagged`

- Report item is valid.
- Picture path resolves inside the current Picture Library Folder.
- Original picture file exists.
- Image extension is supported by the Phase 1 resolver.
- Current saved information is readable and belongs to the same picture.
- The `Flagged` tag is not already present.

User text:

```text
dMPP can safely update saved information for this picture.
```

`Ready to create saved information`

- Report item is valid.
- Picture path resolves inside the current Picture Library Folder.
- Original picture file exists.
- No `.dmpms.json` information file exists yet.
- Phase 4B may create saved information for this picture.

User text:

```text
No saved information file exists yet. dMPP can create one because the picture is inside the current Picture Library Folder.
```

`Already flagged in dMPP`

- Report item is valid.
- Saved information is readable and belongs to the same picture.
- The canonical `Flagged` tag is already present.
- Stable curator note may or may not already be present.

User text:

```text
This picture is already marked as Flagged in dMPP.
```

Open decision: decide whether Phase 4B should append the stable note when `Flagged` is already present but the note is missing, or treat the item as already updated. The safer first behavior is "already updated" when `Flagged` exists.

`Needs attention`

Use for anything dMPP should not update automatically:

- invalid report item
- unsupported schema/version
- unresolved picture path
- outside current Picture Library Folder
- missing original picture
- unsupported image extension
- unreadable saved information
- read error
- saved information appears to belong to a different picture
- write permission problem, once Phase 4B attempts writes

User text:

```text
dMPP will not update this picture from the queue until the issue is resolved.
```

### Post-Apply Result Buckets

`Updated`

- Existing saved information was readable and matched the picture.
- dMPP added the `Flagged` tag and stable curator note.

`Already updated`

- The picture already had the durable `Flagged` tag, and Phase 4B did not need to change it.

`Created saved information`

- No saved information file existed.
- The picture was inside the current Picture Library Folder.
- dMPP created a new information file and added the `Flagged` tag plus stable curator note.

`Needs attention`

- dMPP intentionally skipped the item because it was not safe to update automatically.

`Failed`

- The item looked safe before apply, but a write failed, permission changed, file disappeared, or another runtime error occurred.

## 7. Status Explanations for Specific Conditions

`ready to update`

```text
dMPP can read the current saved information for this picture and can safely mark it as Flagged.
```

`already updated`

```text
This picture is already marked as Flagged in dMPP.
```

`missing saved information`

```text
No saved information file exists yet. If the picture is inside the current Picture Library Folder, dMPP can create one.
```

`outside Picture Library Folder`

```text
This picture is outside the current Picture Library Folder. dMPP will not update it from this queue.
```

`missing picture`

```text
dMPP could not find the original picture at the location listed in the queue.
```

`unreadable saved information`

```text
dMPP found saved information for this picture but could not read it. It will not be changed from this queue.
```

`saved information appears to belong to a different picture`

```text
The saved information file appears to describe a different picture. dMPP will not update it automatically.
```

`write permission problem`

```text
dMPP could not update saved information for this picture. Check folder access and try again.
```

## 8. File Impact Estimate

Current Phase 4A files:

```text
DMPSFlaggedApplyAction.swift
DMPSFlaggedApplyCoordinator.swift
DMPSFlaggedApplyControlsView.swift
DMPSFlaggedApplyResultView.swift
DMPSFlaggedApplySummaryView.swift
DMPSFlaggedReportImportCoordinator.swift
DMPSFlaggedReportImportView.swift
DMPSFlaggedSidecarInspection.swift
```

Recommended treatment:

`DMPSFlaggedApplyAction.swift`

- Simplify or replace.
- Better future name: `DMPSFlaggedTriageStatus.swift` or `DMPSFlaggedImportTriage.swift`.
- Remove per-item user action cases.
- Add triage status/result enums instead.

`DMPSFlaggedApplyCoordinator.swift`

- Rename or replace.
- Better future name: `DMPSFlaggedTriageCoordinator.swift`.
- It should compute an in-memory import plan, not own per-item choices.
- In revised Phase 4A, it should be no-write.
- In Phase 4B, a separate apply service should handle durable updates.

`DMPSFlaggedApplyControlsView.swift`

- Remove or replace.
- Better future replacement: `DMPSFlaggedTriageActionView.swift`.
- Should show one disabled/preview-only primary action in Phase 4A.

`DMPSFlaggedApplyResultView.swift`

- Defer or repurpose for Phase 4B.
- Better future replacement: `DMPSFlaggedTriageResultView.swift`.
- It should show post-apply result buckets, not per-item selected action state.

`DMPSFlaggedApplySummaryView.swift`

- Keep concept, rename/simplify.
- Better future name: `DMPSFlaggedTriageSummaryView.swift`.
- Should show triage counts and the future primary batch action.

`DMPSFlaggedReportImportCoordinator.swift`

- Keep as session/import coordinator.
- Replace `applyCoordinator` with a triage coordinator or import plan coordinator.
- Keep it thin: parse, inspect, triage, clear.
- Do not add write logic here.

`DMPSFlaggedReportImportView.swift`

- Keep, but trim per-item action picker wiring.
- Compose new triage subviews rather than adding large blocks directly.
- Consider removing stale helper functions when naturally touched.

`DMPSFlaggedSidecarInspection.swift`

- Keep.
- Extend its classification or feed it into a separate triage classifier.
- Do not make it responsible for write decisions beyond read-only facts.
- Consider adding enough information to distinguish:
  - missing saved information but safe to create
  - missing saved information and not safe to create

Likely new/replacement files:

```text
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageStatus.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageCoordinator.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageSummaryView.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageDetailView.swift
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedTriageResultView.swift
```

Phase 4B likely new file:

```text
dMPP/Source/Imports/DMPSFlaggedReport/DMPSFlaggedBatchApplyService.swift
```

That service should use the eventual shared saved-information I/O path, not duplicate the whole sidecar writer.

## 9. Risks

`Missing saved information creation`

Creating new saved information files is a product improvement but a write-path expansion. It should be Phase 4B only, and only for pictures inside the current Picture Library Folder.

`Unknown-field preservation`

Batch writes should not casually rewrite saved information and drop unknown fields. Phase 4B should preserve unknown fields or explicitly document a deferral.

`Decoder tolerance`

Current dMPP decoding may reject public-valid minimal dMPMS sidecars. Phase 4B should address tolerant decoding before importer-driven writes.

`Large-file growth`

`DMPSFlaggedReportImportView.swift` is already large. The redesign should remove the picker UI and compose the triage UI from small subviews.

`Parallel review workflow`

Any per-item action selector, skip workflow, or review-style detail decision tree risks recreating review inside the import window. Keep those out of the normal path.

`Result semantics`

"Already updated" needs one exact rule before Phase 4B. Recommended first rule: already updated means the `Flagged` tag is already present. Do not append the stable note to already-flagged items in the first write-capable pass unless Dan explicitly wants that.

## 10. Recommended Implementation Split

Recommended split:

### Revised Phase 4A: No-Write Triage UI

Do this next.

Scope:

- Remove/defer per-item action choices.
- Replace action picker with triage summary and import plan preview.
- Treat missing saved information inside the Picture Library Folder as "ready to create saved information" in the preview.
- Keep the primary batch action disabled or clearly preview-only.
- Keep item details and advanced details for troubleshooting.
- No sidecar writes.
- No `.dmpms.json` changes.
- No original image changes.
- No `DMPPImageEditorView.swift` changes.
- No `dMagy_Picture_PrepApp.swift` changes.

### Phase 4B: Batch Write Implementation

Do after revised Phase 4A is approved.

Scope:

- Enable `Mark Ready Pictures as Flagged`.
- Add the canonical `Flagged` tag and stable curator note to safe items.
- Create saved information only for safe missing-information items inside the current Picture Library Folder.
- Do not write outside the Picture Library Folder.
- Do not auto-repair unreadable saved information.
- Do not auto-fix saved information that appears to belong to a different picture.
- Show post-apply results.
- Use dMPP's existing saved-information semantics through a focused shared I/O path.

Before Phase 4B:

- Decide unknown-field preservation behavior.
- Decide tolerant decoding behavior.
- Decide exact duplicate-note rule.
- Decide exact already-updated rule.

## 11. Specific Recommendation for What To Do Next

Next best action:

```text
Implement revised Phase 4A no-write triage UI.
```

Why this first:

- It removes the product confusion immediately.
- It keeps the import window focused on safe intake, not review.
- It preserves the no-write safety boundary.
- It gives Dan a chance to validate the new workflow before any durable saved-information updates exist.
- It keeps Phase 4B smaller and clearer.

Implementation prompt should explicitly say:

- remove/defer per-item action selection
- replace Phase 4A action files with triage/import-plan files
- keep the main import view thin
- do not touch `DMPPImageEditorView.swift`
- do not touch `dMagy_Picture_PrepApp.swift`
- do not write sidecars
- do not implement Phase 4B

## Dan Decision Checklist

Before implementing revised Phase 4A:

- Confirm primary button label: `Mark Ready Pictures as Flagged`.
- Confirm stable curator note text: `Flagged in dMagy Picture Show for later review.`
- Confirm missing saved information inside the Picture Library Folder should be previewed as ready for future creation.
- Confirm already-updated means `Flagged` tag already exists, even if the stable note is missing.
- Confirm per-item action selection should be removed, not merely hidden.

Before Phase 4B:

- Decide tolerant decoding implementation for public-valid minimal dMPMS sidecars.
- Decide unknown-field preservation behavior for batch writes.
- Decide whether Phase 4B creates saved information directly or calls/extracts an existing dMPP create/default metadata path.
- Decide whether to run a small dry-run summary immediately before enabling writes.
