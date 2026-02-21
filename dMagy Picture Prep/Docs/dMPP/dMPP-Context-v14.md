
# dMPP-Context-v14.md

**dMagy Picture Prep — Application Context & Architecture Overview**
**Version:** dMPP-2026-02-15-CTX14
**Supersedes:** dMPP-2026-02-04-CTX13

---

## 0. What changed since CTX13 (Reality Delta + Intent Delta)

### 0.1 Reality (implemented)

* **Prefs model retired as a source of truth.** Stores are now authoritative (runtime + persistence). Any remaining “prefs sync” language in CTX13 is obsolete and should be treated as legacy documentation debt.
* **App-owned stores confirmed** (injected via `.environmentObject(...)`):

  * `DMPPIdentityStore`, `DMPPTagStore`, `DMPPLocationStore`, `DMPPCropStore`, `DMPPArchiveStore`
* **Archive Root Gate remains a hard requirement**: app is gated until a valid archive root is selected.

> **Known uncertainty (flagged, not asserted):** there may still be accidental singleton usage in parts of the codebase. Treat as a medium-priority audit item until verified.

### 0.2 Intent (planned / proposed)

* **Documentation alignment:** CTX14 treats “stores-only truth” as the current architecture pattern and removes transitional prefs language (or moves it to “legacy notes” where needed).
* **Medium Priority Work is now explicitly ordered** (see §15.1) so we stop “optimizing by wandering.”

---

## 1. Purpose of dMagy Picture Prep (dMPP)

dMPP is a macOS Swift/SwiftUI application for preparing a personal photo archive to be:

* **Structured** (portable archive folder, registries, consistent IDs)
* **Searchable** (tags, people, locations, dates/ranges)
* **Display-ready** (virtual crops + export crops for downstream use)
* **Durable** (metadata lives with the archive, not trapped in one machine)

Primary goal: make photo curation repeatable, not heroic.

---

## 2. Relationship to dMPMS and dMPS

### 2.1 dMPP ↔ dMPMS

dMPP is the editor/curator for the dMagy Photo Metadata Standard (dMPMS):

* Reads/writes sidecar metadata files (per-image)
* Normalizes and validates metadata at save time
* Connects per-image metadata to archive-wide registries (People / Tags / Locations / Crops)

### 2.2 dMPP ↔ dMPS

dMPP prepares content for dMagy Picture Show (dMPS):

* dMPS consumes the curated archive (images + sidecars + exported crops)
* dMPP ensures the archive is consistently structured so dMPS can remain “dumb but fast” (in a good way)

---

## 3. Core Workflow Model

### 3.1 Metadata-first editing

dMPP is primarily a **metadata editor** with strong rules:

* Per-image metadata is authoritative for “what’s in this photo”
* Archive registries provide canonical vocabularies and IDs
* Save-time normalization keeps the archive consistent over years of edits

### 3.2 Folder-based review (“archive browsing”)

Users browse a folder tree under the selected archive root:

* Optional include subfolders
* Optional “unprepped only” filtering (current behavior may vary by view; treat as workflow option)
* Per-photo editing occurs in a consistent editor shell

---

## 4. Technical Architecture (CTX14)

### 4.1 Application entry

* App is the owner of the shared stores (single source of truth).
* Stores are injected using `environmentObject`.
* **Design rule:** no view should silently create its own store instance.

### 4.2 Archive Root Gate + configuration

* App launches into an **Archive Root Gate** until the user selects a valid archive root.
* Archive selection is persisted via a security-scoped bookmark (implementation detail; keep behavior stable).
* After selection, stores are configured to read/write data under the chosen root.

> **Note:** Exact configuration sequencing (who calls `configureForArchiveRoot` and when) should be verified in code before we claim it as “Reality.” CTX14 treats it as “behavior exists” without overstating the wiring.

### 4.3 Editor shell

* “Shell” view hosts navigation, preview, editing panels, and binds to stores.
* The shell should tolerate “not configured yet” only during the gate flow; after gate success, stores should assume a configured archive root.

### 4.4 Crop editing

* Crops exist in two forms:

  * **Virtual crops**: per-photo crop definitions stored in metadata (authoritative for intent)
  * **Export crops**: rendered image outputs written to the archive (authoritative for downstream consumption)

### 4.5 Metadata editing

Per-photo metadata includes (typical scope):

* People-in-photo records (`peopleV2`)
* Tags (with reserved tags + canonical registries)
* Locations (canonical list + per-photo assignment)
* Date ranges (start/end) and derived age calculations

### 4.6 ViewModel

* ViewModels (where used) should be **thin coordinators**:

  * Assemble view state from stores
  * Provide intent-level actions (save, add tag, export crop)
  * Avoid duplicating normalization rules (those belong in stores / model layer)

---

## 5. Portable Archive (Implemented)

### 5.1 Folder name + required subfolders

Portable data lives under the selected archive root in:

`<Archive Root>/dMagy Portable Archive Data/`

Typical subfolders:

* `People/`
* `Locations/`
* `Tags/`
* `Crops/`
* `_locks/` (if used)
* Additional subfolders may exist; do not break forward compatibility.

### 5.2 What data lives where (current)

**Portable archive (shared, portable):**

* People registry (canonical people)
* Tags registry
* Locations registry
* Crop vocab / presets (current or planned depending on implementation)
* Any store-owned persisted state intended to travel with the archive

**Per-image metadata (sidecars):**

* Per-photo authoritative assignments (peopleV2, tags, location, date range, crop intent, etc.)

### 5.3 “Linked file (advanced)” UX

dMPP may support linking a photo to an “advanced” file (or external resource). If present:

* Treat links as optional enhancements
* Avoid making archive validity depend on external linked resources

---

## 6. People & Identity System (Implemented direction)

### 6.1 Layers (conceptual)

* **Canonical Person**: stored in the portable archive People registry
* **Person-in-photo record (`peopleV2`)**: stored per image, authoritative for that photo
* **Identity resolution**: mapping between photo records and canonical people IDs

### 6.2 Canonical people live in the portable archive

* The portable People registry is the canonical vocabulary.
* Editors should offer canonical people consistently across the app.

### 6.3 Person-in-photo records (`peopleV2`) are authoritative per image

* The per-image record is the “truth for this photo.”
* Re-resolution should not lose user intent.

### 6.4 Save-time normalization (still required)

At save time, normalization should enforce:

* Canonical IDs when possible
* Cleaned/validated ranges and derived ages
* Reserved tag rules
* Consistent ordering where order matters (stable display + diffs)

---

## 7. Date & Age Handling (Implemented rule)

### 7.1 Canonical rule: everything is a range

All dates are treated as ranges:

* `start` (inclusive-ish)
* `end` (inclusive-ish)
* Single-day dates are represented as start=end.

### 7.2 Range-aware age math

Age calculations must handle:

* Exact dates
* Fuzzy ranges (month/year only)
* Multi-day spans

### 7.3 Single source of truth requirement

Derived fields (like age) must be computed from the stored range and canonical person DOB range. Avoid storing duplicate “computed truth” in multiple places.

### 7.4 Loose date parsing API naming

Loose parsing helpers must be clearly labeled (e.g., “loose” / “fuzzy”), so strict logic doesn’t accidentally become vibes-based.

---

## 8. Tags (Implemented)

### 8.1 Portable tags registry

* Tags are stored in the portable archive Tags registry.
* UI should present the canonical list consistently across views.

### 8.2 Reserved tags

Reserved tags exist for system behavior and should be enforced by normalization rules (never silently removed, never user-editable unless explicitly allowed).

### 8.3 Default starter tags

If the portable registry is empty, seed a starter set (exact list is implementation-defined; keep behavior stable and documented).

### 8.4 Legacy note: prefs sync is retired (CTX14)

CTX13 described a transitional “sync tags into prefs” model. That is no longer the architecture.
**Rule now:** stores are authoritative; any remaining prefs usage is UI-only and should not be required for correctness.

---

## 9. Locations (Implemented)

Locations follow the same principle as Tags:

* Portable Locations registry is canonical.
* Per-photo assignment references canonical locations (by stable identity, not by fragile display name when possible).
* Any CTX13 transitional “prefs.userLocations” language is legacy and should not be treated as current architecture.

---

## 10. Crops (Current + planned)

### 10.1 Current truth: per-photo virtual crops

Per-photo crops represent editing intent and are stored with the photo’s metadata.

### 10.2 Planned / evolving: portable preset vocabulary (Crops folder)

Portable crop preset vocabulary may live in the portable archive so presets travel with the archive. Treat any preset registry structure as “verify in code” before stating as implemented.

---

## 11. Save semantics & “dirty” tracking

* “Dirty” state tracks unsaved changes in the editor.
* Save should be explicit and predictable.
* Save must trigger normalization, then write:

  * per-image metadata updates
  * any registry updates (if edited)
  * any export crops (if requested by the workflow)

---

## 12. Snapshots

Snapshots (where implemented) exist to prevent “oops” events:

* Capture last-known-good metadata state
* Provide rollback paths during risky edits
* Should be store-owned so snapshot logic remains consistent

---

## 13. Workflow options (restored + updated)

### 13.1 Include subfolders

User can choose whether browsing includes nested folders under the selected root.

### 13.2 Show only unprepped pictures

User can filter to photos missing required metadata/crops (exact definition is implementation-defined; document it where enforced).

### 13.3 Metadata status indicator (planned)

A consistent status indicator (“prepped”, “needs people”, “needs tags”, etc.) should be defined centrally and reused across views.

---

## 14. Known limitations and open decisions (Updated)

### 14.1 Known limitations (current)

* Some architecture claims must be verified in code before being labeled “Reality” (notably store configuration sequencing and any remaining singleton usage).
* Crop/export UI may have ergonomic issues (button placement) that slow down the workflow.
* “Unprepped” definition may vary across screens until centralized.

### 14.2 Known Questions / Open Decisions

* **Singleton audit:** Are there any remaining singleton store references? If yes, where and what’s the migration plan?
* **Filters/Flagged mode scope:** Is “Flagged” a tag, a state, or a separate queue concept?
* **Crop actions UX:** Where should “Delete Crop” and “Export Crop” live so they’re discoverable but not dangerous?
* **Window behavior:** Should dMPP support multiple windows, and if so, which views are allowed to be multi-window?
* **Voice input:** What is the first target (tags? notes? people?) and what accuracy threshold is acceptable?
* **Face recognition:** Pure investigation vs implementation? If implementation, what privacy model and what “opt-in” story?
* **Photos integration:** Import-only, reference-only, or both? How do we avoid turning dMPP into a Photos replacement?
* **Onboarding:** What is “first success” for a new user (select archive → edit 1 photo → export 1 crop)?

---

## 15. Roadmap (Updated — CTX14)

### 15.1 Medium Priority Work (Next) — Ordered

**(1) Filters / Flagged mode (find/queue photos by criteria)** - Done
*Definition of done:*

* A user can define at least one filter (e.g., missing people, missing tags, missing location, missing crop/export)
* A “Flagged” view or queue shows matching photos and stays in sync after saves
* Filter logic is centralized (not re-implemented per view)

*Likely files/components touched (best guess):*

* Archive browsing / list views (root + folder browser)
* Shared filter model / service (new)
* Store queries (Identity/Tag/Location/Crop stores as needed)

---

**(2) Relocate “Delete Crop” and “Export Crop” buttons** - Done
*Definition of done:*

* Buttons are placed where users naturally look during crop workflow
* Dangerous action (“Delete”) has confirmation or safe-guard
* No regression in keyboard/mouse flow

*Likely files/components touched:*

* Crop editor view(s)
* Toolbar / command definitions (if used)
* Any shared button components/styles

---

**(3) Window sizing / multi-window polish** - Done
*Definition of done:*

* Default window size is sensible and stable across launches
* Resizing doesn’t break layout (no “mystery collapsing” panels)
* If multiple windows are supported: which windows are allowed is explicitly defined

*Likely files/components touched:*

* App scene configuration
* Root editor shell layout
* Any split-view / navigation views

---

**(4) Voice input / automation hooks** - Done
*Definition of done:*

* Voice input can reliably populate one scoped field (first target TBD)
* Clear UI affordance for start/stop
* Errors fail gracefully (no ghost text, no silent data corruption)

*Likely files/components touched:*

* The target edit view(s)
* A small input service wrapper (new)
* Permissions / entitlements if required

---

**(5) Investigate facial recognition** *(investigation only unless explicitly promoted)*
*Definition of done:*

* Written decision memo: feasibility, privacy stance, technical approach, and “nope” criteria
* Identifies whether we can support offline-only and what data would be stored

*Likely files/components touched:*

* Docs (new)
* Prototype sandbox code (optional, isolated)

---

**(6) Investigate integration / acquisition from Photos** *(investigation only unless explicitly promoted)*
*Definition of done:*

* Written decision memo: import vs reference, scope boundaries, and UX implications
* Identifies what metadata can be read and what cannot

*Likely files/components touched:*

* Docs (new)
* Prototype code (optional, isolated)

---

**(7) First-run help / onboarding**
*Definition of done:*

* New user can reach “first success” with minimal confusion
* Onboarding does not block power users
* Help content matches actual UI

*Likely files/components touched:*

* Archive gate view
* A help/onboarding view (new)
* Docs text assets (new)

---

**(8) README / examples / docs cleanup**
*Definition of done:*

* A new developer (or Future Dan) can build + run + understand archive setup
* Includes an example portable archive structure and sample metadata

*Likely files/components touched:*

* `README.md`, `Docs/` (if created)
* Context docs (this file + AI context alignment)

---

**(9) Code review / optimization / singleton audit**
*Definition of done:*

* Verified answer: “Singleton leftovers: yes/no” + list if yes
* Any cleanup is small and reversible (avoid drive-by refactors)
* Performance hotspots are measured before optimizing

*Likely files/components touched:*

* Store definitions
* App entry wiring
* Any legacy helpers still referencing prefs/singletons

---

### 15.2 Phases (carried forward from CTX13)

Keep CTX13 phases as the long-horizon structure, but treat them as subordinate to §15.1’s ordered medium-priority list unless explicitly re-prioritized.

---

## 16. Version tracking

**Build environment (current):**

* macOS: 26
* Xcode: 26.2 (17C52)

**Collaboration rules (operational):**

* Default to **full-file paste-over** for code changes.
* Work in **1–2 steps at a time**, with a short “remaining steps” reminder.
* Require `// MARK:` anchors in any file we touch.
* Add “versioning points” only for risky refactors.
* Add a brief “file purpose” header gradually as files are touched.

---
