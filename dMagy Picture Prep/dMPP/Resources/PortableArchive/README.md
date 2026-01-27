# dMagy Portable Archive Data

This folder is created and used by **dMagy Picture Prep (dMPP)**.

**Do not delete this folder** if you want to keep your photo archive organized and portable.

## Why this folder exists
Your photo files stay untouched. dMPP stores *portable* supporting data alongside the archive so that:
- People names are consistent across the whole archive
- Locations, tags, and crop presets are reused (no re-typing the same values)
- Metadata travels with the archive when you move/copy it

## What is stored here
Typical structure (names may evolve over time):

- `People/` — one JSON file per person (record-per-file)
- `Locations/` — one JSON file per location
- `Tags/` — one JSON file per tag
- `Crops/` — one JSON file per crop preset
- `_locks/` — soft locks that warn when someone else may be editing the same photo
- `_meta/` — schema/app version info used for safe upgrades
- `_indexes/` — optional, rebuildable index files to speed up browsing (safe to regenerate)

## Collaboration and shared archives (Drive, Dropbox, etc.)
If multiple family members use the same shared archive, dMPP is designed for working on **different photos at the same time**.

### Soft locks (warning only)
To reduce accidental double-editing of a single photo, dMPP may create a small lock file in `_locks/` while a photo is being edited.
- Locks are **warnings only**. They never block work.
- Locks become "stale" after a while and are ignored.

## What you can safely delete
- **Stale locks** in `_locks/` (optional)
- Any files under `_indexes/` (dMPP can rebuild them)

## What you should NOT delete
- Anything under `People/`, `Locations/`, `Tags/`, or `Crops/`
- Anything under `_meta/`

## Where photo metadata is stored
Per-photo metadata is stored next to each image as a **sidecar JSON** file (dMPMS).
This lets you back up, move, or share the archive without a database export step.

## If something looks wrong
- If you moved the archive, open dMPP and re-select the new folder.
- If you accidentally deleted this folder, restore it from a backup.

---

Generated: 2026-01-19
