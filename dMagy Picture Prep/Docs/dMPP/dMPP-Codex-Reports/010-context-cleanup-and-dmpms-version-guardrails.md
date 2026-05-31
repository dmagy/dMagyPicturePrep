# Context Cleanup and dMPMS Version Guardrails

## 1. Executive Summary

This documentation cleanup aligned the current dMPP context files around the confirmed dMPMS v1.0 reality:

- dMPMS v1.0 remains the current public standard.
- dMPP currently writes `dmpmsVersion: "1.0"`.
- Older dMPMS draft specs are historical only and must not guide current implementation.
- The previous concern that dMPP might still write `dmpmsVersion: "1.1"` is closed.
- The remaining sidecar concern before write-capable dMPS importer work is decoder tolerance, unknown-field preservation, and batch-write safety.
- Phase 4 remains paused for durable writes. Phase 4A can proceed as no-write action selection/preview if kept isolated.

No Swift source files were changed as part of this cleanup.

## 2. Files Reviewed

- `Docs/dMPP/dMPP-Context-v17.md`
- `Docs/dMPP/dMPP-AI-Collaboration.md`
- `Docs/dMPP/dMagy Project Collaboration Guide.md`
- `Docs/dMPP/dMagy Design Standards.md`
- `Docs/dMPMS/dMPMS-v1.0.md`
- `Docs/dMPMS/Draft Archives/`
- `Docs/dMPP/dMPP-Codex-Reports/009-source-and-context-review-full-repo.md`
- Repo search for old AI/context files such as:
  - `dMPP-AI-Context-v2.md`
  - older `dMPP-Context-v##.md`
  - Codex/agent brief files

Search result: no repo file named `dMPP-AI-Context-v2.md` and no older numbered dMPP context files were found in the working tree. The only active app context file found is `Docs/dMPP/dMPP-Context-v17.md`.

## 3. Files Changed

- `Docs/dMPP/dMPP-Context-v17.md`
- `Docs/dMPP/dMPP-AI-Collaboration.md`
- `Docs/dMPMS/Draft Archives/README.md`
- `Docs/dMPMS/Draft Archives/Read Me.md`
- `Docs/dMPP/dMPP-dMPMS-Implementation-Notes.md`
- `Docs/dMPP/dMPP-Codex-Reports/010-context-cleanup-and-dmpms-version-guardrails.md`

Existing uncommitted work was already present in the repository before this report, including earlier Codex reports and unrelated non-documentation changes. This task did not modify Swift source.

## 4. Exact Summary of Changes

### `Docs/dMPP/dMPP-Context-v17.md`

Added a dMPMS version guardrail section stating:

- dMPP writes `dmpmsVersion: "1.0"`.
- the `1.1` version concern is closed.
- `Docs/dMPMS/dMPMS-v1.0.md` is the current public schema truth.
- `Docs/dMPMS/Draft Archives/` is historical only.
- the active implementation concern is decoder tolerance and unknown-field preservation before importer-driven batch writes.

Added a current dMPS Flagged Review Queue phase note stating:

- Phases 1-3 exist.
- Phase 4 proposal exists at `008-dmps-flagged-report-phase-4-apply-actions-proposal.md`.
- Phase 4 implementation is paused pending context cleanup and sidecar I/O decisions.
- Phase 4 should likely split into no-write Phase 4A and write-capable Phase 4B.

Updated the crop/headshot section to clarify implemented vs planned behavior:

- implemented headshot crop kind
- implemented `tight` and `full` variants
- implemented `headshotPersonID`
- implemented helper code that can select/create per-person headshot crops
- remaining planned/watch items around grouping, missing linked people, smarter initial placement, and wording polish

### `Docs/dMPP/dMPP-AI-Collaboration.md`

Corrected the collaboration guide path to:

```text
Docs/dMPP/dMagy Project Collaboration Guide.md
```

Added explicit source-of-truth roles:

- `dMPP-Context-v17.md` is app/project truth.
- `dMPMS-v1.0.md` is public schema truth.
- Codex reports are phase-specific history, proposals, or implementation notes.
- draft dMPMS specs are historical only.

Added dMPMS version guardrails:

- current public version is `1.0`
- dMPP writes `dmpmsVersion: "1.0"`
- archived draft version numbers must not be used as current guidance
- do not infer a `1.1` or later public version without an explicit new public spec decision

Added the current sidecar implementation watch point:

- dMPMS v1.0 requires only `dmpmsVersion` and `sourceFile`
- dMPP should move toward tolerant decoding of public-valid minimal sidecars
- unknown-field preservation or explicit deferral should be addressed before importer-driven batch writes

### `Docs/dMPMS/Draft Archives/README.md`

Created a conventional README for the draft archive folder.

It states:

- draft specs are historical only
- the current public standard is `Docs/dMPMS/dMPMS-v1.0.md`
- archived draft version numbers must not guide current implementation
- drafts should be used only for historical migration research
- dMPP currently writes `dmpmsVersion: "1.0"`

### `Docs/dMPMS/Draft Archives/Read Me.md`

Kept the existing Finder-readable note but made it point to the new canonical `README.md`.

### `Docs/dMPP/dMPP-dMPMS-Implementation-Notes.md`

Created a short implementation note so app-specific caveats do not clutter the public dMPMS spec.

It summarizes:

- current dMPP write version is `1.0`
- the `1.1` concern is closed
- public-valid minimal sidecars require only `dmpmsVersion` and `sourceFile`
- dMPP implementation should move toward tolerant decoding of missing optional fields
- unknown-field preservation must be considered before importer-driven batch writes
- Phase 4A / Phase 4B split remains recommended

### `Docs/dMPMS/dMPMS-v1.0.md`

Reviewed but not changed.

Reason: the public spec already says the current public version is v1.0, writers should write `dmpmsVersion: "1.0"`, and only `dmpmsVersion` plus `sourceFile` are required. The remaining caveats are dMPP implementation concerns, not public-spec corrections.

## 5. Confirmation: No Swift Source Files Changed

Confirmed for this cleanup task:

- No Swift source files were edited.
- Phase 4 was not implemented.
- No app behavior was changed.
- No sidecars were written.
- No Xcode project changes were made by this cleanup task.

Note: the repository already had unrelated uncommitted changes outside this documentation cleanup. Those were left untouched.

## 6. Confirmation: dMPMS Current Public Version Remains `1.0`

Confirmed:

```text
dMPMS current public version: 1.0
dMPP current write version: dmpmsVersion: "1.0"
```

No public dMPMS version bump was made or proposed as part of this cleanup.

## 7. Confirmation: Older dMPMS Draft Versions Are Marked Historical

The draft archive now has a conventional `README.md` stating that archived draft version numbers such as `1.1`, `1.2`, `1.3`, and `1.4` are historical only and must not guide current implementation.

The current context and AI collaboration docs now also point away from draft specs as active truth.

## 8. Remaining Context Risks

- `Docs/dMPMS/Draft Archives/Read Me.md` and `README.md` now both exist. This is intentional for Finder readability plus conventional tooling, but the canonical note should be `README.md`.
- ChatGPT project files outside this repo may still contain stale context such as `dMPP-AI-Context-v2.md`. The repo does not contain that file.
- The remaining technical risk before Phase 4B is not documentation: current dMPP decoding may be stricter than public dMPMS v1.0, and current writes do not preserve unknown fields.
- Older historical Codex reports remain useful history but should not all be uploaded as standing ChatGPT project context.

## 9. Recommended Next Step Before Phase 4 Resumes

Recommended next step:

```text
Implement Phase 4A only: no-write action selection and preview.
```

Why:

- The context files now clearly close the version-number concern.
- Phase 4A can improve the workflow without touching sidecar writes.
- Phase 4B should still wait until the sidecar I/O decision is explicit:
  - tolerant decoding of public-valid minimal sidecars
  - unknown-field preservation or documented deferral
  - shared write path / no second metadata-writing system

If Dan prefers to resolve the sidecar I/O decision before any Phase 4 UI work, the best next documentation/code-design task would be a focused proposal for `DMPPSidecarMetadataIO`.

## 10. Suggested ChatGPT Project File Sync List

Recommended standing project context:

- `Docs/dMPP/dMPP-AI-Collaboration.md`
- `Docs/dMPP/dMPP-Context-v17.md`
- `Docs/dMPP/dMagy Project Collaboration Guide.md`
- `Docs/dMPP/dMagy Design Standards.md`
- `Docs/dMPMS/dMPMS-v1.0.md`

Recommended active Phase 4 context:

- `Docs/dMPP/dMPP-Codex-Reports/008-dmps-flagged-report-phase-4-apply-actions-proposal.md`
- `Docs/dMPP/dMPP-Codex-Reports/009-source-and-context-review-full-repo.md`
- `Docs/dMPP/dMPP-Codex-Reports/010-context-cleanup-and-dmpms-version-guardrails.md`
- `Docs/dMPP/dMPP-dMPMS-Implementation-Notes.md`

Suggested files to avoid as standing ChatGPT project context:

- `Docs/dMPMS/Draft Archives/*`
- older superseded context files
- all historical Codex reports at once
- any stale external file named `dMPP-AI-Context-v2.md`
