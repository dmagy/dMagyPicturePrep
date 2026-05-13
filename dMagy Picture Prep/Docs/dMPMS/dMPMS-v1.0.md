# dMPMS v1.0 — dMagy Photo Metadata Standard

**Status:** First public specification  
**Version:** 1.0  
**Primary implementation:** dMagy Picture Prep (dMPP)  
**Intended readers:** developers, archivists, technically curious users, and future dMagy apps

dMPMS is a human-readable sidecar metadata standard for non-destructive photo archive curation.

---

## 1. Purpose

The **dMagy Photo Metadata Standard (dMPMS)** defines a JSON sidecar format for storing useful photo metadata without modifying the original image file.

A dMPMS sidecar can describe:

- title and description
- dates and date ranges
- people in the photo
- locations and GPS data
- tags
- virtual crops
- headshot crops
- curator notes
- workflow history

dMPMS is intended to support tools such as:

- **dMagy Picture Prep (dMPP)**, which prepares and writes metadata
- **dMagy Picture Show (dMPS)**, which may later read metadata for filtering, display, and presentation
- other tools that want to read or preserve dMPMS sidecars

---

## 2. Design Principles

### 2.1 Non-destructive editing

dMPMS does not require modifying original image files.

Metadata is written to a separate sidecar file stored beside the image.

### 2.2 Human-readable sidecars

A dMPMS sidecar should be understandable when opened in a text editor.

The sidecar should not require registry lookup just to understand the basic meaning of a photo.

### 2.3 Sidecars are useful without registry lookup

Registries may exist as archive support data, but sidecars should still carry meaningful human-readable values.

For example, tags are stored as readable strings:

```json
"tags": ["Flagged", "Christmas", "Family"]
```

Locations are stored as embedded readable objects:

```json
"location": {
  "shortName": "Grandma’s House",
  "city": "New Ulm",
  "state": "MN",
  "country": "United States"
}
```

### 2.4 Human authority over automated inference

Tools may suggest, derive, or calculate metadata, but user-entered meaning should not be silently overwritten.

### 2.5 Forward compatibility

Readers should tolerate fields they do not understand.

Writers should preserve unknown fields when possible.

---

## 3. Sidecar File Naming

### 3.1 Filename convention

A dMPMS sidecar is stored beside the image it describes.

The sidecar filename appends `.dmpms.json` to the original image filename.

Examples:

```text
IMG_0001.jpg
IMG_0001.jpg.dmpms.json

family_photo.heic
family_photo.heic.dmpms.json

scan_1978.png
scan_1978.png.dmpms.json
```

### 3.2 Relationship to the original image

The `sourceFile` field identifies the image file the sidecar describes.

Example:

```json
"sourceFile": "IMG_0001.jpg"
```

### 3.3 Supported image formats

dMPMS is image-format agnostic. It can describe common image files such as:

- JPEG / JPG
- PNG
- TIFF
- HEIC / HEIF
- WebP
- RAW image files

The sidecar format does not depend on the image format.

---

## 4. JSON Format Expectations

### 4.1 Encoding

dMPMS files should be UTF-8 JSON.

### 4.2 Key style

dMPMS v1.0 uses camelCase field names.

Examples:

```text
dateTaken
dateRange
curatorNotes
virtualCrops
```

### 4.3 Unknown fields

Readers should ignore unknown fields.

Writers should preserve unknown fields when possible.

### 4.4 Field ordering

JSON field order is not semantically significant.

Tools may write fields in any order.

---

## 5. Root Sidecar Object

A dMPMS sidecar is a JSON object.

### 5.1 Required fields

Only two fields are required:

```text
dmpmsVersion
sourceFile
```

### 5.2 Minimal sidecar

```json
{
  "dmpmsVersion": "1.0",
  "sourceFile": "IMG_0001.jpg"
}
```

### 5.3 Typical sidecar fields

A fuller sidecar may include:

```text
dmpmsVersion
dmpmsNotice
sourceFile
title
description
curatorNotes
dateTaken
dateRange
gps
location
tags
people
peopleV2
peopleV2Snapshots
peopleMethod
ignoredFaceNumbers
faceAssignments
virtualCrops
history
```

All fields except `dmpmsVersion` and `sourceFile` are optional.

---

## 6. Field Classifications

### 6.1 Required fields

These fields are required for a valid dMPMS v1.0 sidecar:

```text
dmpmsVersion
sourceFile
```

### 6.2 Optional display-facing fields

These fields may be used by display, search, browsing, presentation, or filtering tools:

```text
title
description
dateTaken
dateRange
gps
location
tags
people
peopleV2
virtualCrops
```

### 6.3 Optional curator-facing fields

These fields are intended for archive preparation, review, repair, or internal curation:

```text
curatorNotes
```

`curatorNotes` is not intended for display, but it is plain JSON. It is not encrypted or hidden.

### 6.4 Optional workflow / app-private fields

These fields may help tools manage editing, review, face workflows, history, or app-specific behavior:

```text
dmpmsNotice
peopleMethod
ignoredFaceNumbers
faceAssignments
peopleV2Snapshots
history
```

Readers should preserve these fields when possible, but display tools should not need to understand them for normal presentation.

---

## 7. Core Fields

### 7.1 `dmpmsVersion`

Type: `String`  
Required: yes

For this public specification:

```json
"dmpmsVersion": "1.0"
```

Readers may encounter older internal draft values and should handle them gracefully when possible.

### 7.2 `sourceFile`

Type: `String`  
Required: yes

The filename of the image this sidecar describes.

Example:

```json
"sourceFile": "IMG_0001.jpg"
```

### 7.3 `dmpmsNotice`

Type: `String`  
Required: no

A human-facing notice explaining the purpose of the sidecar.

Example:

```json
"dmpmsNotice": "Created by dMagy Picture Prep. Stores metadata and crop settings for this photo. Deleting it erases edits (not the original image)."
```

### 7.4 `title`

Type: `String`  
Required: no  
Classification: display-facing

A short human-readable title for the photo.

Example:

```json
"title": "Christmas morning"
```

### 7.5 `description`

Type: `String`  
Required: no  
Classification: display-facing

A description or story intended for display or sharing.

Example:

```json
"description": "Anna, Zach, and Hannah opening presents at Grandma Jean’s house."
```

### 7.6 `curatorNotes`

Type: `String`  
Required: no  
Classification: curator-facing

Notes intended for the person preparing, maintaining, or reviewing the archive.

Use `curatorNotes` for uncertainty, repair clues, follow-up tasks, source notes, and behind-the-scenes review context.

Example:

```json
"curatorNotes": "Ask Mom whether this was Christmas 1997 or 1998."
```

Curator Notes are stored plainly in JSON. They are not encrypted, hidden, or password-protected.

---

## 8. Dates and Date Ranges

### 8.1 `dateTaken`

Type: `String`  
Required: no  
Classification: display-facing

`dateTaken` records what is known about when the photo’s subject matter occurred.

It may be exact, approximate, or ranged.

Supported standard forms include:

| Format | Example | Meaning |
|---|---|---|
| `YYYY-MM-DD` | `2025-06-22` | exact day |
| `YYYY-MM` | `2025-06` | year and month |
| `YYYY` | `2025` | year only |
| `YYYYs` | `2020s` | decade |
| `YYYY-YYYY` | `1975-1977` | year range |
| `YYYY-MM to YYYY-MM` | `1976-07 to 1976-09` | month range |

Example:

```json
"dateTaken": "2025-04-18"
```

### 8.2 `dateRange`

Type: `Object`  
Required: no  
Classification: display-facing / computation support

`dateRange` stores a machine-readable inclusive date range derived from `dateTaken` when possible.

Fields:

```text
earliest
latest
```

Example:

```json
"dateRange": {
  "earliest": "2025-04-18",
  "latest": "2025-04-18"
}
```

For a month-level date:

```json
"dateTaken": "2025-09",
"dateRange": {
  "earliest": "2025-09-01",
  "latest": "2025-09-30"
}
```

### 8.3 Date interpretation

Typical interpretation:

| `dateTaken` | `dateRange.earliest` | `dateRange.latest` |
|---|---|---|
| `2025-06-22` | `2025-06-22` | `2025-06-22` |
| `2025-06` | `2025-06-01` | last day of June 2025 |
| `2025` | `2025-01-01` | `2025-12-31` |
| `2020s` | `2020-01-01` | `2029-12-31` |
| `1975-1977` | `1975-01-01` | `1977-12-31` |
| `1976-07 to 1976-09` | `1976-07-01` | last day of September 1976 |

### 8.4 User-entered date authority

Tools should not overwrite a non-empty user-entered `dateTaken` without explicit user action.

Tools may derive or refresh `dateRange` from `dateTaken`.

---

## 9. People

dMPMS supports both a readable people summary and structured person-in-photo records.

### 9.1 `people`

Type: `[String]`  
Required: no  
Classification: display-facing / compatibility snapshot

A human-readable summary list of people in the photo.

Example:

```json
"people": ["Everett", "Emmalyn"]
```

The `people` field is useful for simple display, compatibility, and quick human understanding.

### 9.2 `peopleV2`

Type: `[Object]`  
Required: no  
Classification: display-facing / structured metadata

`peopleV2` stores structured records of people in this specific photo.

This is the preferred structured representation for person-in-photo data.

Example:

```json
"peopleV2": [
  {
    "id": "C222DCC0-FB61-4AA1-ABB9-E40B66FFD120",
    "personID": "A80B7E5B-424B-40A9-B1C8-E5FFE958AD84",
    "identityID": "5D15DCD5-6C85-4CA9-883A-35180EBF115A",
    "isUnknown": false,
    "shortNameSnapshot": "Everett",
    "displayNameSnapshot": "Everett Samuel Colburn",
    "ageAtPhoto": "7",
    "rowIndex": 0,
    "rowName": "Faces",
    "positionIndex": 0,
    "roleHint": "facesDerived"
  }
]
```

### 9.3 Person-in-photo fields

| Field | Type | Required | Notes |
|---|---:|---:|---|
| `id` | String | recommended | Unique per-photo person row ID. |
| `personID` | String? | no | Stable person identifier when known. |
| `identityID` | String? | no | Stable identity/version identifier when known. |
| `isUnknown` | Bool | recommended | `true` for unknown placeholders or one-off labels. |
| `shortNameSnapshot` | String? | no | Short label at tagging time. |
| `displayNameSnapshot` | String? | no | Display name at tagging time. |
| `nameSnapshot` | Object? | no | Structured name snapshot. |
| `ageAtPhoto` | String? | no | Age clue or age snapshot. |
| `rowIndex` | Int? | no | Row order; often `0` for front row or detected faces. |
| `rowName` | String? | no | Optional row label such as `Faces`. |
| `positionIndex` | Int? | no | Left-to-right order within row. |
| `roleHint` | String? | no | Optional role or workflow hint. |

### 9.4 `nameSnapshot`

A `nameSnapshot` may include:

```text
given
middle
surname
display
sort
```

Example:

```json
"nameSnapshot": {
  "given": "Everett",
  "middle": "Samuel",
  "surname": "Colburn",
  "display": "Everett Samuel Colburn",
  "sort": "Colburn, Everett Samuel"
}
```

Snapshots make the sidecar more readable even if a registry is missing.

### 9.5 Unknown people

Unknown people may be represented with `isUnknown: true`.

Example:

```json
{
  "id": "2DCC2B67-D028-4E89-8FF0-F147B2EE3978",
  "personID": null,
  "identityID": null,
  "isUnknown": true,
  "shortNameSnapshot": "Unknown woman",
  "displayNameSnapshot": "Unknown woman",
  "rowIndex": 0,
  "positionIndex": 2
}
```

### 9.6 `peopleMethod`

Type: `String`  
Required: no  
Classification: workflow / app-private

Indicates how people were identified in the photo.

Common values:

```text
manual
faces
```

Display tools should generally use `people` or `peopleV2`, not `peopleMethod`.

---

## 10. Location and GPS

### 10.1 `gps`

Type: `Object`  
Required: no  
Classification: display-facing / computation support

GPS coordinates from the image or derived metadata.

Fields:

```text
latitude
longitude
altitudeMeters
```

Example:

```json
"gps": {
  "latitude": 40.75906666666667,
  "longitude": -73.98374166666666,
  "altitudeMeters": -15.79
}
```

### 10.2 `location`

Type: `Object`  
Required: no  
Classification: display-facing

Human-readable location information.

Fields may include:

```text
shortName
description
streetAddress
city
state
country
```

Example:

```json
"location": {
  "shortName": "PRES",
  "description": "Prairie Ridge Elementary School",
  "streetAddress": "6632 St. Vrain Ranch Blvd.",
  "city": "Firestone",
  "state": "CO",
  "country": "United States"
}
```

### 10.3 Embedded locations

dMPMS v1.0 uses embedded location data rather than requiring `locationID`.

A locations registry may exist as support data, but the sidecar should remain understandable without it.

### 10.4 GPS drift

GPS and reverse geocoding may be approximate.

A tool may allow a user to correct or replace GPS-derived address information with a saved human-readable location.

---

## 11. Tags

### 11.1 `tags`

Type: `[String]`  
Required: no  
Classification: display-facing / filtering

Tags are human-readable strings.

Example:

```json
"tags": ["Flagged", "Christmas", "Family"]
```

### 11.2 Human-readable tags

dMPMS v1.0 intentionally keeps tags readable in the sidecar.

This is preferred:

```json
"tags": ["Flagged", "Christmas"]
```

This is not required by dMPMS v1.0:

```json
"tagIDs": ["reserved.flagged", "event.christmas"]
```

### 11.3 Standard dMagy tags

dMPMS itself allows human-readable tag strings.

dMagy apps may treat certain tag names as standard tags with shared behavior.

Examples may include:

```text
Flagged
Do Not Display
```

`Flagged` may be used for follow-up or review.

`Do Not Display` may be used by display tools to avoid showing a photo in slideshows, public views, or family presentations.

### 11.4 Tag registries

A tag registry may exist as archive support data for:

- descriptions
- sorting
- default tags
- reserved behavior
- UI support
- consistency checking

A registry should enrich the archive, not make the sidecar unreadable without lookup.

---

## 12. Virtual Crops

Virtual crops describe non-destructive viewports into an image.

They do not crop or alter the original image file.

### 12.1 `virtualCrops`

Type: `[Object]`  
Required: no  
Classification: display-facing / presentation support

Example:

```json
"virtualCrops": [
  {
    "id": "crop-16x9",
    "label": "Landscape 16:9",
    "aspectRatio": "16:9",
    "kind": "standard",
    "rect": {
      "x": 0,
      "y": 0.455708912037037,
      "width": 1,
      "height": 0.421875
    }
  }
]
```

### 12.2 Crop fields

| Field | Type | Required | Notes |
|---|---:|---:|---|
| `id` | String | yes | Unique crop ID within the sidecar. |
| `label` | String | recommended | Human-readable crop label. |
| `aspectRatio` | String | recommended | Example: `16:9`, `4:5`, `1:1`. |
| `kind` | String | recommended | Example: `standard`, `headshot`. |
| `rect` | Object | yes | Normalized crop rectangle. |

### 12.3 Crop rectangle

`rect` uses normalized coordinates relative to the original image.

Fields:

```text
x
y
width
height
```

Values are typically between `0.0` and `1.0`.

Example:

```json
"rect": {
  "x": 0.11822515359175433,
  "y": 0.04102349405436526,
  "width": 0.7922400841346154,
  "height": 0.7922400841346154
}
```

### 12.4 Standard crops

A standard crop has:

```json
"kind": "standard"
```

Common standard crop labels may include:

```text
Original (full image)
Landscape 16:9
Portrait 4:5
Square 1:1
```

### 12.5 Original crop

An Original crop represents the full image.

Example:

```json
{
  "id": "crop-3x2",
  "label": "Original (full image)",
  "aspectRatio": "3:2",
  "kind": "standard",
  "rect": {
    "x": 0,
    "y": 0,
    "width": 1,
    "height": 1
  }
}
```

---

## 13. Headshot Crops

Headshot crops are person-focused virtual crops.

They are part of dMPMS v1.0 because current dMagy sidecars may include them.

### 13.1 Headshot crop structure

A headshot crop uses:

```json
"kind": "headshot"
```

Example:

```json
{
  "id": "crop-4x5-2",
  "label": "Headshot (Tight)",
  "aspectRatio": "4:5",
  "kind": "headshot",
  "headshotVariant": "tight",
  "headshotPersonID": "A80B7E5B-424B-40A9-B1C8-E5FFE958AD84",
  "rect": {
    "x": 0.11822515359175433,
    "y": 0.04102349405436526,
    "width": 0.7922400841346154,
    "height": 0.7922400841346154
  }
}
```

### 13.2 `headshotVariant`

Type: `String`  
Required: no, but recommended for headshot crops

Common values:

```text
tight
full
```

A tight headshot is intended to frame the head more closely.

A full headshot may include more of the upper body or surrounding context.

### 13.3 `headshotPersonID`

Type: `String`  
Required: no, but recommended when the person is known

Links the headshot crop to a person record.

If the referenced person is missing from available registries, readers should preserve and display the crop rather than deleting it.

### 13.4 Future compatibility

Future versions may refine headshot crop naming or registry relationships.

Readers should preserve unknown crop fields.

---

## 14. Curator Notes

### 14.1 `curatorNotes`

Type: `String`  
Required: no  
Classification: curator-facing

Curator Notes are intended for the person preparing or maintaining the archive.

Examples:

```json
"curatorNotes": "Ask Mom who the person on the left is."
```

```json
"curatorNotes": "Date may be 1984, not 1985."
```

### 14.2 Not intended for display

Display tools should not normally show `curatorNotes`.

Use `description` for display-facing story or context.

### 14.3 Not encrypted or hidden

Curator Notes are plain JSON.

Do not store sensitive information in `curatorNotes` unless it is appropriate for the archive metadata.

---

## 15. History and Workflow Fields

### 15.1 `history`

Type: `[Object]`  
Required: no  
Classification: workflow / app-private

History records meaningful changes or editing events.

Example:

```json
"history": [
  {
    "action": "updateCropRect",
    "cropID": "crop-4x5",
    "newName": "Portrait 4:5 (4×5, 8×10...)",
    "timestamp": "2026-05-11T11:08:25Z"
  }
]
```

History is not required for display.

### 15.2 `faceAssignments`

Type: `Object`  
Required: no  
Classification: workflow / app-private

Stores face-slot assignment state for tools that support face workflows.

Example:

```json
"faceAssignments": {
  "1": "id:A80B7E5B-424B-40A9-B1C8-E5FFE958AD84"
}
```

Display tools should generally use `people` or `peopleV2`.

### 15.3 `ignoredFaceNumbers`

Type: `[Int]`  
Required: no  
Classification: workflow / app-private

Face numbers intentionally ignored during face review.

### 15.4 `peopleV2Snapshots`

Type: `[Object]`  
Required: no  
Classification: workflow / compatibility support

Optional snapshot support used by tools that need to preserve or repair people-related metadata.

### 15.5 Preservation expectation

Readers and writers should preserve workflow/app-private fields when possible, even if they do not use them.

---

## 16. Portable Archive Support Data

dMPMS v1.0 defines the sidecar format.

Apps may also maintain portable archive support data beside the photo archive.

Examples may include:

```text
People
Locations
Tags
Crops
FaceIndex
_locks
_meta
_indexes
```

These registries and folders can support:

- consistent People
- saved Locations
- Tag descriptions
- Crop presets
- face recognition data
- rebuildable indexes
- collaboration warnings

However, the sidecar should remain useful and readable without requiring lookup into these support files.

---

## 17. Reader and Writer Expectations

### 17.1 Readers

Readers should:

- accept valid JSON sidecars
- require only `dmpmsVersion` and `sourceFile`
- tolerate missing optional fields
- ignore unknown fields
- preserve user meaning
- prefer display-facing fields for presentation
- avoid displaying curator-facing fields unless explicitly requested

### 17.2 Writers

Writers should:

- write UTF-8 JSON
- write `dmpmsVersion: "1.0"` for this public standard
- preserve unknown fields when possible
- avoid overwriting user-entered fields without explicit user action
- keep sidecars human-readable
- avoid requiring registry lookup for basic sidecar meaning

### 17.3 Unknown fields

Unknown fields should not make a sidecar invalid.

Writers should preserve them when possible.

---

## 18. Versioning

### 18.1 `dmpmsVersion`

The public v1.0 standard writes:

```json
"dmpmsVersion": "1.0"
```

### 18.2 Earlier internal drafts

Earlier internal drafts may have used other version strings.

Readers should handle older known sidecars gracefully when possible.

### 18.3 Future minor versions

Future minor versions should be non-destructive when possible.

Minor version changes should not require readers to discard unknown data.

### 18.4 Breaking changes

A future breaking change should use a major version bump.

---

## 19. Migration Expectations

Existing sidecars from internal drafts do not need to be rewritten immediately.

Tools may naturally update `dmpmsVersion` when a sidecar is next saved, provided the sidecar conforms to the public v1.0 structure.

For the internal-to-public transition, tools may migrate `privateNotes` to `curatorNotes`.

A reader may continue to tolerate `privateNotes` as a legacy synonym, but writers should prefer `curatorNotes` for v1.0 sidecars.

A reader should not reject older internal sidecars solely because their `dmpmsVersion` differs.

Future migrations may include richer registries or refined crop fields, but should preserve human-readable sidecars.

---

## 20. Example Sidecars

### 20.1 Basic photo

```json
{
  "dmpmsVersion": "1.0",
  "sourceFile": "IMG_0001.jpg",
  "title": "Christmas morning",
  "description": "Opening presents in the living room."
}
```

### 20.2 Photo with date range

```json
{
  "dmpmsVersion": "1.0",
  "sourceFile": "school-photo.jpg",
  "title": "Second grade school photo",
  "dateTaken": "2025-09",
  "dateRange": {
    "earliest": "2025-09-01",
    "latest": "2025-09-30"
  }
}
```

### 20.3 Photo with GPS and location

```json
{
  "dmpmsVersion": "1.0",
  "sourceFile": "field-trip.jpg",
  "title": "Art Show",
  "dateTaken": "2025-04-18",
  "gps": {
    "latitude": 40.15561116666667,
    "longitude": -105.12904716666667,
    "altitudeMeters": 1497.09
  },
  "location": {
    "description": "Boulder County Fair Grounds",
    "streetAddress": "9595 Nelson Rd",
    "city": "Longmont",
    "state": "CO",
    "country": "United States"
  }
}
```

### 20.4 Photo with tags and curator notes

```json
{
  "dmpmsVersion": "1.0",
  "sourceFile": "IMG_2042.jpg",
  "title": "Times Square",
  "description": "",
  "tags": ["Flagged"],
  "curatorNotes": "Confirm exact location."
}
```

### 20.5 Photo with people

```json
{
  "dmpmsVersion": "1.0",
  "sourceFile": "class-photo.jpg",
  "title": "Everett 2nd Grade",
  "dateTaken": "2025-09",
  "dateRange": {
    "earliest": "2025-09-01",
    "latest": "2025-09-30"
  },
  "people": ["Everett"],
  "peopleV2": [
    {
      "id": "C222DCC0-FB61-4AA1-ABB9-E40B66FFD120",
      "personID": "A80B7E5B-424B-40A9-B1C8-E5FFE958AD84",
      "identityID": "5D15DCD5-6C85-4CA9-883A-35180EBF115A",
      "isUnknown": false,
      "shortNameSnapshot": "Everett",
      "displayNameSnapshot": "Everett Samuel Colburn",
      "ageAtPhoto": "7",
      "rowIndex": 0,
      "rowName": "Faces",
      "positionIndex": 0,
      "roleHint": "facesDerived",
      "nameSnapshot": {
        "given": "Everett",
        "middle": "Samuel",
        "surname": "Colburn",
        "display": "Everett Samuel Colburn",
        "sort": "Colburn, Everett Samuel"
      }
    }
  ]
}
```

### 20.6 Photo with virtual crops and headshot crop

```json
{
  "dmpmsVersion": "1.0",
  "sourceFile": "portrait.jpg",
  "title": "Everett 2nd Grade",
  "virtualCrops": [
    {
      "id": "crop-4x5",
      "label": "Portrait 4:5 (4×5, 8×10...)",
      "aspectRatio": "4:5",
      "kind": "standard",
      "rect": {
        "x": 0,
        "y": 0,
        "width": 1,
        "height": 1
      }
    },
    {
      "id": "crop-4x5-2",
      "label": "Headshot (Tight)",
      "aspectRatio": "4:5",
      "kind": "headshot",
      "headshotVariant": "tight",
      "headshotPersonID": "A80B7E5B-424B-40A9-B1C8-E5FFE958AD84",
      "rect": {
        "x": 0.11822515359175433,
        "y": 0.04102349405436526,
        "width": 0.7922400841346154,
        "height": 0.7922400841346154
      }
    }
  ]
}
```

### 20.7 Photo with workflow fields

```json
{
  "dmpmsVersion": "1.0",
  "sourceFile": "portrait.jpg",
  "title": "Everett 2nd Grade",
  "peopleMethod": "faces",
  "faceAssignments": {
    "1": "id:A80B7E5B-424B-40A9-B1C8-E5FFE958AD84"
  },
  "ignoredFaceNumbers": [],
  "history": [
    {
      "action": "updateCropRect",
      "cropID": "crop-4x5-2",
      "newName": "Headshot (Tight)",
      "timestamp": "2026-05-11T10:52:49Z"
    }
  ]
}
```

---

## 21. Non-Goals

dMPMS v1.0 does not define:

- a database
- cloud sync behavior
- a required registry storage format
- a slideshow engine
- face recognition algorithms
- automatic inference requirements
- encryption
- access control
- UI layout or window state
- guaranteed uniqueness of human-readable labels

---

## 22. License and Attribution

The dMagy Photo Metadata Standard is authored by:

```text
Daniel P. Magyar (“dMagy”)
```

License to be determined before public publication.

Recommended placeholder:

```text
© Daniel P. Magyar. License pending.
```

---

## 23. Summary

dMPMS v1.0 is the first public version of the dMagy Photo Metadata Standard.

It defines a human-readable, sidecar-first, non-destructive way to describe photos while preserving enough structure for future tools to filter, search, prepare, and display family photo archives.

The core promise is simple:

```text
The original picture stays untouched.
The meaning travels beside it.
```
