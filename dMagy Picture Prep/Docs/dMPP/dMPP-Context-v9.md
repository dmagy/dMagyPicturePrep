# dMPP-Context v9.md

**dMagy Picture Prep — Application Context & Architecture Overview**  
**Version:** dMPP-2025-12-15-CTX9  

---

## 1. Purpose of dMagy Picture Prep (dMPP)

dMPP is a macOS utility that prepares personal and archival photographs for advanced display workflows. It provides an efficient, non-destructive way to:

- Assign rich metadata according to the **dMagy Photo Metadata Standard (dMPMS)**  
- Create and manage **virtual crops** customized for multiple display targets  
- Navigate through folders of images in a structured reviewing workflow  
- Persist edits in **sidecar metadata files** for use in other applications (e.g., dMagy Picture Show)

Where **dMPS shows pictures** , **dMPP prepares them**.

---

## 2. Relationship to dMPMS and dMPS

### 2.1 dMPP ↔ dMPMS

dMPP is the first full implementation of the dMPMS metadata standard.

- Current spec: **dMPMS v1.1**
  - Adds `dateRange` for more precise date/era handling.
  - Introduces a richer **people model** at the schema level:
    - `DmpmsIdentity` and `DmpmsPersonInPhoto` types (implemented in code).
    - Future-facing support for structured per-photo people records alongside the legacy `people: [String]`.

dMPP is responsible for:

- Loading metadata from sidecar `.dmpms.json` files  
- Writing updated metadata in the standardized format  
- Enforcing dMPMS compatibility at runtime

### 2.2 dMPP ↔ dMPS

The apps communicate exclusively through **dMPMS sidecars**.  
dMPP sets up image metadata and virtual crops; dMPS consumes them when rendering slideshows across multiple displays.

They are intentionally **decoupled** to keep the viewer lightweight and the prep tool flexible.

---

## 3. Current Features (What’s Built Now)

**As of dMPP-2025-12-15-CTX9**

---

### 3.1 Folder Selection & Image Navigation

- Uses `NSOpenPanel` to pick any accessible folder.
- Scans for supported image formats:  
  `jpg, jpeg, png, heic, tif, tiff, webp`
- Builds an ordered list of images.
- Supports:
  - **Previous Picture**
  - **Next Picture**
  - Automatic saving when switching images or folders
  - Explicit **Save** button (**Command–S**) for “save before you move on” behavior
- Gracefully handles switching folders (saving current metadata first).
- Navigation controls live in a **bottom bar** so they stay in a consistent place relative to the window.

---

### 3.2 Image Preview & Metadata Binding

- Displays a large, scalable image preview using `NSImage`.
- Right-hand metadata pane is driven by `DmpmsMetadata` via live bindings to the ViewModel.

Current fields:

- **File**
  - Read-only `sourceFile` (image filename).
- **Title**
  - Single-line text field.
  - For new images (no sidecar), defaults to the filename **without** extension.
  - Uses the full usable width inside its group box.
- **Description**
  - Multi-line text field (vertically expanding).
  - Uses the full usable width inside its group box.
  - Extra internal padding to make the description block feel like a proper “text area.”
- **Date / Era**
  - Label: “Date Taken or Era”.
  - Single-line `TextField` bound to `metadata.dateTaken`.
  - Helper text:
    - Line 1: “Partial dates, decades, and ranges are allowed.”
    - Line 2: `Examples: 1976-07-04, 1976-07, 1976, 1970s, 1975-1977, 1976-06 to 1976-08`
  - A **soft validation helper** watches changes and:
    - On valid forms (see 3.3), silently updates `metadata.dateRange`.
    - On invalid forms, keeps the entered string but shows a gentle warning:  
      `Entered value does not match standard forms` plus the example list.

Layout notes:

- Title, Description, and Date/Era fields take the **full width** inside their group boxes.
- Group boxes use consistent internal padding so the right pane visually balances the crop editor.

---

### 3.3 Date Semantics & `dateRange` (dMPMS v1.1)

dMPMS v1.1 adds:

- `dateTaken: String`  
- `dateRange: DmpmsDateRange?` (new; structured earliest/latest dates)

Both are stored in `DmpmsMetadata`.

#### 3.3.1 Accepted `dateTaken` formats

The Date/Era field accepts:

1. **Exact date**
   - `YYYY-MM-DD`  
     - e.g., `1976-07-04`
2. **Year + month**
   - `YYYY-MM`  
     - e.g., `1976-07`
3. **Year only**
   - `YYYY`  
     - e.g., `1976`
4. **Decade**
   - `YYYYs`  
     - e.g., `1970s`
5. **Year range**
   - `YYYY-YYYY`  
     - e.g., `1975-1977`
6. **Month range**
   - `YYYY-MM to YYYY-MM`
     - e.g., `1976-06 to 1976-08`

Other freeform values (e.g., `Summer 1965`) are allowed but treated as **non-standard**, producing a warning.

#### 3.3.2 `dateRange` behavior

`DmpmsDateRange` stores:

- `earliest: "YYYY-MM-DD"`  
- `latest:  "YYYY-MM-DD"`

On every change to `dateTaken`, dMPP attempts to parse and compute a canonical `dateRange`:

- `YYYY-MM-DD` → that exact day for both earliest/latest.  
- `YYYY-MM` → whole calendar month.  
- `YYYY` → whole calendar year.  
- `YYYYs` (decade) → `YYYY-01-01` through `YYYY+9-12-31`.  
- `YYYY-YYYY` → lower-year start to higher-year end (only if `start <= end`).  
- `YYYY-MM to YYYY-MM` → start-month first day through end-month last day (only if start <= end).

If the input is **invalid**:

- `dateTaken` is kept as typed.
- `dateRange` is left `nil`.
- A soft, non-blocking warning is shown in the UI.

This allows future tools (dMPP v2, dMPS v2) to use **dateRange** for better filtering and age calculations without forcing perfect precision.

#### 3.3.3 Default dates for camera images

For **new sidecars** created for digital photos:

- dMPP attempts to read the capture date from image metadata (EXIF/metadata).
- If a valid date is found, it initializes:
  - `dateTaken` as a `YYYY-MM-DD` string.
  - `dateRange` from that exact date.

For **scanned or legacy images** without reliable metadata:

- `dateTaken` starts empty.
- `dateRange` is `nil` until the user enters something.

---

## 4. Technical Architecture

(Contents unchanged from CTX8; see prior document versions.)

---

## 5. Known Limitations (as of CTX9)

(Contents unchanged from CTX8; see prior document versions.)

---

## 6. Roadmap (Short-Term)

(Contents unchanged from CTX8; see prior document versions.)

---

## 7. Version Tracking

This document uses the version tag:

```text
dMPP-2025-12-15-CTX9
```

Previous revisions:

```text
dMPP-2025-12-09-CTX8
dMPP-2025-12-07-CTX7
dMPP-2025-12-04-CTX6
dMPP-2025-11-30-CTX5
dMPP-2025-11-26-CTX4
dMPP-2025-11-24-CTX3
```

---

## 8. Author Notes

This file serves as the authoritative record for:

- Architectural decisions
- Workflow definitions
- Schema changes (dMPMS evolution)
- Constraints encountered (sandboxing, metadata rules, etc.)
- Progress milestones

Keeping it up to date helps future development stay intentional rather than reactive, especially as dMPP, dMPS, and dMPMS evolve together.

---

## 9. Delta from dMPP-2025-12-09-CTX8

Changes introduced in **CTX9** relative to **CTX8**:

1. **Date grammar expanded**
   - Added support documentation for `YYYY-MM to YYYY-MM` in 3.3.1 and 3.3.2.

---

## End of dMPP-Context-v9.md
