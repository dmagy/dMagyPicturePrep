dMPS Flagged Report Import Design for dMPP

1. Executive Summary

This document proposes how dMagy Picture Prep (dMPP) should import a Flagged Pictures Report produced by dMagy Picture Show (dMPS) and guide the curator through a safe, review-first workflow that applies durable metadata updates to dMPMS sidecar files. The design preserves the architectural boundary: dMPS records slideshow review intent only; dMPP owns durable metadata authoring. No new sidecar-writing subsystem is introduced—existing dMPP sidecar I/O is reused.

Key outcomes:
• Introduce a report import entry point in dMPP (File > Import Flagged Pictures Report…).
• Parse and validate a JSON report describing flagged images and context.
• Resolve each reported item to a concrete picture within the active Picture Library Folder, with user-assisted relinking when necessary.
• Present a Review Queue UI to apply, per item or in batch: Add reserved tag Flagged, append a review note, apply both, or skip.
• Route missing/invalid sidecars through existing dMPP sidecar workflows (create/repair) rather than inventing a new path.
• Perform safe, atomic writes through existing sidecar-writing mechanisms, avoiding duplicate tags and preserving user data.

This is a design/survey only. No implementation changes are made by this document.

2. Current Code Survey

Notes based on repository conventions and prior dMPP patterns (to be confirmed during implementation):

• Sidecar model and I/O: dMPP already reads/writes dMPMS sidecar files. Identify the types/files that:
   • Parse/validate sidecar JSON.
   • Provide safe/atomic write operations.
   • Preserve unknown fields if supported (read–modify–write).
• Picture Library Folder: dMPP appears to operate relative to a user-selected “Picture Library Folder.” Sidecar discovery typically occurs relative to image paths under this root.
• Reserved tags: dMPP likely centralizes tag normalization and reserved tag constraints. Confirm whether Flagged already exists as a reserved tag constant and how duplicates/casing are handled.
• Error/reporting surfaces: dMPP likely uses non-modal alerts, inline validation rows, and/or a results sheet for batch operations.
• Codex-Reports: This document follows the collaboration style found under Docs/dMPP and existing Codex reports.

Action for implementation phase: locate and reuse the existing sidecar loading/writing pathways and any tag normalization utilities. Do not introduce a parallel writer.

3. Proposed User Workflow

1. User prepares dMPP with an active Picture Library Folder (PLF). If none is selected, dMPP prompts to select one before import proceeds.

2. User chooses File > Import Flagged Pictures Report… and selects a report exported by dMPS.

3. dMPP validates the file (readability, schema/version, structural integrity). Any blocking errors are reported immediately; otherwise an Import Session is created.

4. dMPP resolves each reported item to a picture within the current PLF:
• Direct absolute match if path points into the PLF.
• Relative path match using an archive-root hint if provided.
• Filename-only fallback with user confirmation if multiple matches.
• User-assisted relinking if no match found; unresolved items remain in the queue with a status.

5. dMPP loads current sidecar status per resolved item (exists/valid/missing/invalid/type mismatch).

6. dMPP opens a Review Queue window showing the items, their preview, reported context, current tags/notes, and per-item actions: Add Flagged, Append Note, Both, Skip.

7. User selects items and applies actions (per-item or batch). dMPP uses existing sidecar mechanisms to:
• Ensure Flagged tag exists exactly once (case-stable, deduplicated).
• Append the report note to curator notes with a prefixed context line (e.g., “Flagged in dMagy Picture Show on 2026-05-28 …”).
• Create/repair sidecar via existing workflows if missing/invalid.

8. Results are summarized. Unapplied or unresolved items remain visible for further action. User can close the session, export a session log, or re-run later with the same report.

4. Proposed Data/Validation Model

4.1 Report Format Assumptions

Given the sample report (app-local queue export), dMPP should expect a JSON object with:

Required top-level fields:
• schema: string, e.g., "com.dmagy.dmps.flaggedReviewQueue".
• schemaVersion: integer. dMPP should support a minimum version and warn/deny on higher incompatible versions.
• createdAt: ISO-8601 UTC string.

Recommended top-level fields (optional but useful):
• createdBy: string (source app name), e.g., "dMagy Picture Show".
• sourceAppVersion: string (if present in future).
• archiveRootHint: string path or token to help map relative paths to the PLF.
• updatedAt: ISO-8601 UTC string.

Items array: each entry describes one flagged picture.

Required per-item fields:
• id: stable UUID string (unique per report entry).
• imageAbsolutePath OR relativePath: at least one locator must be present.
• flaggedAt: ISO-8601 UTC string.

Optional per-item fields:
• flagSource: string (e.g., "dMPS slideshow").
• suggestedDMPMSTags: array of strings (should include "Flagged").
• suggestedReviewNote: string (e.g., “Flagged in dMagy Picture Show for later review.”).
• runtimeFlagState: string (e.g., "flagged").
• sidecarStatusAtFlag: string (e.g., "notChecked").
• filename: string (redundant convenience if provided).
• slideshow/profile context: object or strings capturing which show/profile.

4.2 Validation

• Readable file: confirm the file exists and is readable; show an error if not.
• JSON decode: must be valid JSON object with required top-level keys.
• Schema/version: schema must match expected prefix; schemaVersion must be supported. For unknown higher versions, warn and attempt best-effort parsing if compatible keys are present; otherwise block.
• Structural checks:
   • items: array present; may be empty (warn user, allow cancel).
   • Per-item required keys present.
   • id uniqueness within the report (deduplicate or mark duplicates).
• Path checks:
   • Absolute paths must be canonicalized and normalized.
   • Relative paths (if present) combined with archiveRootHint or PLF.
   • Paths outside the current PLF flagged for user attention; allow user-assisted relinking.
• Image type support: verify file extension/UTType is supported by dMPP.
• Staleness: if the pointed file no longer exists, mark as unresolved; do not block entire import.
• Malformed entries: mark as invalid and continue; present in UI under a filter like “Invalid entries,” excluded from batch apply.

5. Proposed Path Resolution Strategy

Resolution phases per item:
1. Absolute path, if provided and under PLF, and exists: resolve immediately.
2. Absolute path exists but outside PLF: attempt to map via archiveRootHint or user-selected new root; if mapped into PLF and exists, resolve.
3. Relative path + archiveRootHint or PLF: join and test.
4. Filename-only fallback: search within PLF (configurable scope: same year/month folder first, then broader); if multiple matches, present a chooser; if none, mark unresolved.
5. User-assisted relinking: per-item “Locate…” action to pick the correct file; store the temporary mapping in the Import Session only.

Storage of resolution:
• Store resolved URL in the in-memory Import Session model. Do not write back to the report or any durable mapping.
• If user cancels, the session is discarded. If user saves a session log, include only non-sensitive relative hints.

Collision handling:
• Multiple matches: require user choice; default to not resolved until selected.
• No match: remain unresolved; allow skip.

6. Proposed Sidecar Update Strategy

Principles:
• Reuse existing dMPP sidecar reading/writing paths. Do not implement a new writer.
• Never write until the user triggers Apply for selected items.
• For each item to apply:
   • Load or create sidecar using existing APIs.
   • Validate sourceFile consistency; if mismatch, route to existing repair flow.
   • Tags: ensure Flagged exists exactly once. Use existing tag normalization utilities; avoid case variants.
   • Curator notes: append a line for the review note. Suggested format:
"[dMPS] Flagged on 2026-05-28 02:55:55Z — Flagged in dMagy Picture Show for later review."

- If a user note from dMPS is added in future, include it.
- Preserve existing notes; do not overwrite.

• Unknown fields: if the sidecar writer preserves unknown fields, keep them intact. If not, call out as a risk.
• Atomicity: use temp-file + replace semantics or equivalent, consistent with existing writer.

Handling sidecar states:
• Exists and valid: modify in place via read–modify–write.
• Missing: invoke existing sidecar creation path; then apply changes.
• Exists but invalid JSON: invoke existing repair path; if user declines, leave item unresolved or allow skip.
• sourceFile mismatch: route to existing mismatch resolution flow; if unresolved, skip.

7. Reserved Flagged Tag

• Durable tag spelling is exactly Flagged.
• dMPP should use the same normalization logic used elsewhere so that flagged, FLAGGED, etc., collapse to the canonical Flagged.
• The importer should not introduce synonyms like Flag or Needs Review.
• If suggestedDMPMSTags includes Flagged, that is advisory; dMPP remains the authority on durable tag spelling.

8. Failure and Recovery UX

• Cannot open report: present an alert with the file path and underlying error; offer “Choose Another File” and “Cancel.”
• Empty report: show a non-blocking sheet stating no usable items; allow user to close.
• PLF mismatch: if many items resolve outside PLF, suggest switching PLF or mapping an archive root; provide a guided relink dialog.
• Partial resolution: proceed with resolved items; unresolved remain with clear status and filters. Batch actions exclude unresolved by default.
• Sidecar update fails for an item: show per-item error with retry option; continue with others. Summarize failures at the end with an exportable log.
• User cancels mid-import: session is discarded without writing.
• Re-import same report: allowed. De-duplicate by item id within the active session; optionally detect previously applied items by checking sidecar state and mark as “Already applied.”

9. Architecture Recommendation

Introduce the following new types/namespaces (Swift types and folders noted for implementation later):

• Report Parser: DMPSFlaggedReportParser
   • Input: file URL
   • Output: FlaggedReport model (schemaVersion, createdAt, items: [FlaggedReportItem])
   • Handles version checks, structural validation, duplicate id detection.

• Import Session Model: FlaggedImportSession
   • Holds the parsed report, resolution map (itemID -> resolved URL or unresolved), per-item status, and transient user choices.

• Path Resolver: ImportPathResolver
   • Strategies for absolute/relative/filename searches within PLF; user-assisted relinking hooks.

• Review Queue View Model: FlaggedReviewQueueViewModel
   • Drives the UI, filters, selection, batch actions, and bridges to sidecar updates.

• Sidecar Update Coordinator: SidecarUpdateCoordinator
   • Adapts existing sidecar read/modify/write APIs for batch application; collects results.

• Review Window/View: FlaggedReviewWindow / FlaggedReviewView
   • SwiftUI UI for queue list, preview pane, current tags/notes, report note, and action controls.

Reuse existing:
• Sidecar I/O types and tag/notes helpers.
• Picture preview pipeline.
• Error reporting/log exporter utilities if present.

Entry points to touch later:
• File menu command: “Import Flagged Pictures Report…”
• Optional toolbar button if appropriate.

10. Likely Files Affected

(Names illustrative; confirm exact file names during implementation.)
• AppMenus.swift or MenuBuilder.swift (add File menu item)
• Import/DMPSFlaggedReportParser.swift (new)
• Import/FlaggedImportSession.swift (new)
• Import/ImportPathResolver.swift (new)
• Review/FlaggedReviewQueueViewModel.swift (new)
• Review/FlaggedReviewView.swift (new)
• Sidecar/SidecarUpdateCoordinator.swift (new adapter over existing writer)
• Sidecar/SidecarIO.swift (existing; reused, not modified if possible)
• Tags/TagUtilities.swift (existing; reused)
• Notes/CuratorNotesUtilities.swift (existing; reused)

11. Risks and Open Questions

Risks:
• Report schema drift: dMPS may evolve the report; require forward-compatible parsing and clear user messaging for unsupported versions.
• Sidecar unknown fields: if existing writer does not preserve unknown fields, updates could inadvertently drop data.
• Path resolution ambiguity: filename-only matches may produce false positives; mitigate with user confirmation and previews.
• Batch write failures: ensure per-item isolation and robust rollback to avoid partial corruption.
• Performance on large reports: list virtualization and batched I/O needed.

Open questions for Dan:
• Is there a canonical reserved-tags list and normalization service in dMPP? Where is Flagged defined today?
• Should the appended note include slideshow/profile context if provided by dMPS? Preferred format?
• What is the expected behavior if a sidecar already contains Flagged and an equivalent note—should we suppress duplicates entirely?
• Do we need a session log export format for auditing? If so, where should it live?
• Are there privacy constraints around embedding absolute paths in session logs?

12. Phased Implementation Plan

Phase 1 — Parser and Session (no writes):
• Add File > Import Flagged Pictures Report… command.
• Implement DMPSFlaggedReportParser with strict validation and best-effort parsing for known schema.
• Implement FlaggedImportSession and path resolution logic (including user-assisted relink UI stubs).
• Build Review Queue UI skeleton showing items, statuses, and filters. No write actions yet.

Phase 2 — Sidecar Read-Only Integration:
• Wire in sidecar loading to display current tags/notes/status for each item.
• Implement deduplication indicators (already flagged, note present).

Phase 3 — Apply Actions (writes via existing I/O):
• Introduce SidecarUpdateCoordinator that wraps existing writer.
• Implement per-item and batch apply for: Add Flagged, Append Note, Both.
• Ensure atomic writes, error capture, and per-item results.

Phase 4 — Robustness and UX Polish:
• Comprehensive error states, relinking flows, and result summaries.
• Session log export; re-import idempotency hints.
• Performance tuning for large queues.

Phase 5 — Documentation and Tests:
• Update Docs/dMPP with final schema assumptions and user guide.
• Add unit tests for parser, path resolver, tag/notes update logic (using test doubles for sidecar I/O).
• Manual verification checklist.

13. Manual Test Plan

Scenarios:
• Import a valid report with 5 items where all images exist under the PLF; apply Both to all; verify sidecars updated with Flagged tag and appended note; ensure no duplicate tags.
• Import when PLF is not set; confirm prompt to choose PLF before continuing.
• Report with items outside PLF; relink to correct folder; resolve and apply.
• Items with missing sidecars; ensure existing create/repair flows are used; apply changes successfully.
• Sidecar invalid JSON; verify repair path is offered; if declined, item remains unresolved.
• Duplicate entries by id; ensure one is ignored or flagged; no duplicate writes.
• Empty report; user sees notice and can close.
• Mixed success writes; verify per-item errors reported; others succeed.
• Re-import same report; items already applied are recognized (already flagged/note present) and excluded from batch by default.