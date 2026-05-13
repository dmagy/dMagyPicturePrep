# dMagy Photo Metadata Standard (dMPMS)

**Version 1.1 — Draft Specification**  
**Status:** Draft / evolving with dMPP + dMPS

---

## 1. Introduction

The **dMagy Photo Metadata Standard (dMPMS)** defines an open, human‑readable, and application‑agnostic method for attaching structured metadata to digital images **without modifying the original file**.

It is designed to support:

- Titles and descriptions
- Tags and categorization
- People (simple + structured “people in photo” rows)
- Virtual crop definitions (non-destructive, resolution-independent)
- Processing history
- Interoperability across multiple applications

dMPMS is used by:

- **dMagy Picture Prep (dMPP)** — prepares images and writes sidecars
- **dMagy Picture Show (dMPS)** — reads sidecars to drive display / filtering

---

## 2. Guiding Principles

1. **Non-destructive** — Original images are never modified.
2. **Readable by humans and machines** — JSON, UTF‑8, no BOM.
3. **File-based, not database-dependent** — Sidecars live next to images.
4. **Normalized coordinate systems** — Crops are resolution independent.
5. **Explicit versioning** — `dmpmsVersion` supports backward compatibility.
6. **Minimal required fields** — Keep required fields small.
7. **Extensible** — Unknown fields must be ignored gracefully.

---

## 3. Storage Model

### 3.1 Sidecar Files

Each image has a matching metadata file stored next to it.

Example:

```
IMG_1234.jpg
IMG_1234.jpg.dmpms.json
```

### 3.2 Naming Convention

A sidecar file is named:

```
<filename>.<image_extension>.dmpms.json
```

Examples:

```
IMG_0001.jpg.dmpms.json
family_photo.heic.dmpms.json
scan_1978.png.dmpms.json
```

### 3.3 Supported Image Formats

dMPMS is file-format agnostic. Typical formats:

- JPG / JPEG
- PNG
- TIFF
- HEIC / HEIF
- WebP
- RAW formats (sidecar still works)

---

## 4. Data Format

dMPMS uses UTF‑8 JSON with no BOM.

### 4.1 Canonical key style (v1.1)

**Canonical keys are camelCase** (e.g., `dateTaken`, `virtualCrops`).  
Earlier drafts used snake_case (e.g., `date_taken`, `virtual_crops`). Implementations **may accept** either, but **must write** the canonical v1.1 names going forward.

---

## 5. Top-Level Structure (v1.1)

```jsonc
{
  "dmpmsVersion": "1.1",
  "dmpmsNotice": "Created by dMagy Picture Prep. Stores metadata and crop settings for this photo. Deleting it erases edits (not the original image).",

  "sourceFile": "IMG_0001.jpg",

  "title": "Mesa Verde Twilight",
  "description": "Dan and Amy at cliff dwellings",

  "tags": ["vacation", "family", "mesa-verde"],

  // Legacy summary list (kept for compatibility)
  "people": ["Dan", "Amy"],

  // Structured per-photo rows (optional; future-facing)
  "peopleV2": [
    {
      "id": "C70E5C49-7A3B-4E0E-9C3C-15B2B4D5E68F",
      "identityID": "2A9D6F1F-0F63-4A4A-9E8C-6EFC4F0B6A2B",
      "isUnknown": false,
      "shortNameSnapshot": "Amy",
      "displayNameSnapshot": "Amy Elizabeth Magyar",
      "ageAtPhoto": "58",
      "rowIndex": 0,
      "rowName": "front",
      "positionIndex": 1,
      "roleHint": null
    }
  ],

  "dateTaken": "2025-06-22",
  "dateRange": { "earliest": "2025-06-22", "latest": "2025-06-22" },

  "virtualCrops": [
    {
      "id": "crop-16x9-01",
      "label": "Landscape 16:9",
      "aspectWidth": 16,
      "aspectHeight": 9,
      "rect": { "x": 0.05, "y": 0.10, "width": 0.90, "height": 0.80 }
    }
  ],

  "history": [
    {
      "action": "createCrop",
      "cropID": "crop-16x9-01",
      "timestamp": "2025-06-24T11:21:44-07:00"
    }
  ]
}
```

---

## 6. Field Definitions

### 6.1 `dmpmsVersion` (required)

Semantic version string for the schema.  
Example: `"1.1"`

### 6.2 `dmpmsNotice` (recommended)

Human-facing notice explaining the sidecar.  
Recommended default:

- `"Created by dMagy Picture Prep. Stores metadata and crop settings for this photo. Deleting it erases edits (not the original image)."`

### 6.3 `sourceFile` (required)

Filename (with extension) of the associated image.  
Example: `"IMG_0001.jpg"`

### 6.4 `title` (optional)

Human-readable title used for display.  
Example: `"Mesa Verde Twilight"`

### 6.5 `description` (optional)

Long-form notes or context for the image.

### 6.6 `tags` (optional)

List of keywords (typically lowercase; hyphens encouraged).  
Example:

```json
["family", "2025-trip", "mountains"]
```

### 6.7 `people` (optional, legacy)

Legacy summary list used by early versions: a flat array of strings.

```json
["Dan", "Amy"]
```

- This field remains valid and is expected to persist for compatibility.
- Newer tooling may also populate `peopleV2` and keep `people` as a summary.

### 6.8 `peopleV2` (optional, structured)

Normalized records of “this person in this specific photo.”

Each entry is a `DmpmsPersonInPhoto`:

| Field | Type | Notes |
|------|------|------|
| `id` | String | Unique per-photo row ID (UUID recommended). |
| `identityID` | String? | References an identity registry record when known. May be `null` for unknown placeholders. |
| `isUnknown` | Bool | `true` for placeholder rows that preserve layout when a person isn’t identified. |
| `shortNameSnapshot` | String | The label used at tagging time (usually the person’s shortName). |
| `displayNameSnapshot` | String | Display name snapshot (often based on identity + photo date). |
| `ageAtPhoto` | String? | Optional snapshot like `"3"`, `"42"`, `"late 30s"`. |
| `rowIndex` | Int | 0 = front row, 1 = second row, etc. |
| `rowName` | String? | Optional UI label (“front”, “second”, …). |
| `positionIndex` | Int | 0 = leftmost in that row, then 1, 2, … |
| `roleHint` | String? | Optional role like “bride”, “groom”, “birthday child”. |

### 6.9 `dateTaken` (optional)

Represents the date or approximate date when the image’s subject matter occurred.

Accepted standard forms:

| Format | Example | Meaning |
|---|---|---|
| Full date | `2025-06-22` | Exact day |
| Year + month | `2025-06` | Month-level accuracy |
| Year only | `2025` | Year-level accuracy |
| Decade | `2020s` | The decade (2020–2029) |
| Year range | `1975-1977` | Between the two years |
| Month range | `1976-07 to 1976-09` | Between two months |

Other freeform values (e.g., `Summer 1965`) are allowed but considered **non-standard**; apps may show a gentle warning.

### 6.10 `dateRange` (optional, recommended when `dateTaken` is standard)

A structured range derived from `dateTaken` for reliable comparisons and age calculations.

```json
{ "earliest": "YYYY-MM-DD", "latest": "YYYY-MM-DD" }
```

Rules (typical implementation):

- `YYYY-MM-DD` → same day for earliest/latest
- `YYYY-MM` → full calendar month
- `YYYY` → full calendar year
- `YYYYs` → decade start to decade end
- `YYYY-YYYY` → lower-year start to higher-year end
- `YYYY-MM to YYYY-MM` → start month begin to end month end

If `dateTaken` is non-standard or invalid, apps may leave `dateRange` as `null`.

---

## 7. Virtual Crops

Virtual crops define non-destructive viewports into an image.

### 7.1 Structure

```jsonc
{
  "id": "crop-16x9-01",
  "label": "Landscape 16:9",
  "aspectWidth": 16,
  "aspectHeight": 9,
  "rect": { "x": 0.05, "y": 0.10, "width": 0.90, "height": 0.80 }
}
```

### 7.2 Coordinate System

All crop rectangles use **normalized coordinates**:

```
0.0 ≤ x, y, width, height ≤ 1.0
```

This makes crops resolution independent.

### 7.3 Aspect Semantics

- Fixed-aspect crops use integer `aspectWidth` and `aspectHeight`.
- **Freeform crops** use `aspectWidth = 0` and `aspectHeight = 0` to indicate “no fixed aspect”.

### 7.4 Multiple Crops

Images may include multiple crops of the same aspect and/or label.

- `id` must be unique per image.

---

## 8. History Log

`history` is an append-only record of meaningful operations (particularly crop operations).

Typical fields in a history record:

| Field | Type | Notes |
|---|---|---|
| `action` | String | e.g., `createCrop`, `deleteCrop`, `updateCropRect`, `scaleCrop` |
| `timestamp` | String | ISO-8601 string (include timezone offset when possible) |
| `cropID` | String? | Links event to a specific crop |
| `oldName` / `newName` | String? | Useful for rename/label-change events |

Example:

```json
{
  "action": "deleteCrop",
  "cropID": "crop-16x9-01",
  "timestamp": "2025-06-24T11:22:10-07:00"
}
```

Implementations may coalesce noisy “continuous” events (dragging/slider scrubbing) into fewer records.

---

## 9. Identity Registry (companion file; app-level)

dMPMS v1.1 introduces a richer people model that benefits from a **global identity registry** (used by dMPP today, and by dMPS in the future). This registry is **not required** to exist for a sidecar to be valid, but it enables:

- Consistent person selection across photos
- Identity changes over time (marriage/divorce/name change)
- Age-at-photo calculations using `birthDate` + photo `dateRange`
- Search by preferred/alias names

### 9.1 Storage

The identity registry is typically stored once per user/application (not next to every image). Example location (dMPP):

```
~/Library/Application Support/dMagyPicturePrep/identities.json
```

### 9.2 Identity Record (`DmpmsIdentity`)

A single identity version for a person, valid starting at `idDate`.

Core concepts:

- A “person” may have **multiple identity versions** (birth name, married name, etc.).
- All versions share a `personID` to group them.

Recommended fields:

| Field | Type | Notes |
|---|---|---|
| `id` | String | Unique identity version ID |
| `personID` | String? | Groups versions under one person |
| `shortName` | String | Primary UI checklist label (may be disambiguated by birth year when duplicated) |
| `preferredName` | String? | “Known as” / nickname (e.g., Betty) |
| `aliases` | [String] | Search helpers / variants (e.g., Elizabeth, Betty Ann) |
| `birthDate` | String? | Uses the same date grammar as `dateTaken` (full date recommended) |
| `isFavorite` | Bool | Person-level favorite flag |
| `notes` | String? | Person-level notes |
| `givenName` | String | Identity-version legal name part |
| `middleName` | String? | Identity-version legal name part |
| `surname` | String | Identity-version legal name part |
| `idDate` | String | Date when this identity became valid |
| `idReason` | String | Birth / Marriage / Divorce / Name Change / etc. |

---

## 10. Extensibility

Applications **must ignore unknown fields**.

Likely future extensions:

- Albums / collections
- Face regions and bounding boxes
- GPS / location
- AI descriptions / captions
- Quality scores

---

## 11. Validation

dMPMS files may be validated with a JSON Schema (recommended).  
A schema file can live alongside the spec, for example:

```
dMPMS-Schema.json
```

---

## 12. License

The dMagy Photo Metadata Standard (dMPMS) is released under the  
**Creative Commons Attribution 4.0 (CC BY 4.0)** license.

Attribution:

**Daniel P. Magyar (“dMagy”)**

---

## 13. Version History

### v1.0 (Draft)
- Sidecar JSON format
- Virtual crops (normalized coordinates)
- History log
- Multiple date formats + decade support

### v1.1 (Draft)
- Canonical camelCase field names (while tolerating earlier snake_case)
- `dateRange` added for structured earliest/latest date semantics
- Structured `peopleV2` (`DmpmsPersonInPhoto`) alongside legacy `people: [String]`
- Companion identity registry model (`DmpmsIdentity`) including `preferredName` and `aliases`
