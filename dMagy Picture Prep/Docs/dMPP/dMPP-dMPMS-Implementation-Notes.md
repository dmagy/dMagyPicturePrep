# dMPP dMPMS Implementation Notes

Purpose: keep dMPP implementation caveats separate from the public dMPMS standard.

The public standard remains:

```text
Docs/dMPMS/dMPMS-v1.0.md
```

## Current Write Version

dMPP currently writes:

```text
dmpmsVersion: "1.0"
```

The previous concern that dMPP might still write `dmpmsVersion: "1.1"` is closed. Older draft specs under `Docs/dMPMS/Draft Archives/` are historical only and should not guide current implementation.

## Public-Minimal Sidecars

dMPMS v1.0 requires only:

```text
dmpmsVersion
sourceFile
```

All other fields are optional in the public standard.

dMPP implementation should move toward tolerant decoding of public-valid minimal sidecars. In practice, missing optional fields should be treated as defaults where that is safe, rather than making the sidecar unreadable solely because optional fields are absent.

## Unknown Fields

dMPMS readers should ignore unknown fields.

dMPMS writers should preserve unknown fields when possible.

Before dMPP adds importer-driven batch writes, the implementation should deliberately decide one of these paths:

1. Preserve unknown fields in the sidecar write path.
2. Explicitly defer unknown-field preservation and document that Phase 4 writes match current editor save behavior.

Do not let batch-write behavior happen accidentally. Phase 4B should make the sidecar I/O decision explicit before durable writes are enabled.

## dMPS Flagged Review Queue Relevance

The dMPS Flagged Review Queue importer is moving toward a write-capable phase.

Recommended split:

- Phase 4A: no-write action selection and preview.
- Phase 4B: durable saved-information writes only after decoder tolerance and unknown-field preservation are deliberately addressed or explicitly deferred.
