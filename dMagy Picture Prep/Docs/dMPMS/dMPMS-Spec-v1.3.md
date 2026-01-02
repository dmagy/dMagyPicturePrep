# dMPMS v1.3 — Draft Specification

**dMagy Photo Metadata Standard**
**Status:** Draft (portable family archive, sidecar-first)
**Intended Consumers:** dMPP, dMPS, and other read/write tools

---

## 1. Purpose

dMPMS defines a **portable family archive** format for photographs. It is **sidecar-first**, supports long-term curation, and enables multiple downstream tools (especially dMPS) to **filter and present** photos using shared, canonical people/tag/crop definitions.

The standard prioritizes:

* Human-entered meaning over automated inference
* Non-destructive editing
* Tool independence
* Computable structure for filtering and display
* Portability (copy the folder, everything works)

---

## 2. Design Principles

1. **Sidecar-first**

   * Image binaries are never modified.
   * Photo metadata lives next to the image in `.dmpms.json`.

2. **Archive portability**

   * Shared dictionaries (people/tags/crops) live inside the archive folder (not app settings).

3. **Human authority**

   * People, dates, tags, and crops are curated, not inferred.
   * Tools may derive machine-readable fields, but must not override user-entered intent.

4. **Structured where it matters**

   * People and filters use stable IDs.
   * Dates support loose human grammar plus a canonical range for computation.

5. **Writers preserve unknown fields**

   * Tools must not destroy fields they don’t understand.

---

## 3. Archive Layout

A dMPMS “portable family archive” is a folder containing photos plus a reserved metadata directory:

```
/Photos/...                        (your images in any subfolders)
/_dmpms/people.json                (shared people + identities)
/_dmpms/tags.json                  (shared tag dictionary)
/_dmpms/crops.json                 (shared crop presets; optional)
/_dmpms/archive.json               (optional archive metadata)
/**/*.dmpms.json                   (per-photo sidecars, stored alongside photos)
```

Rules:

* The reserved folder name MUST be `_dmpms` (case-sensitive).
* Shared dictionary files SHOULD be present for full filtering capability in dMPS.
* Per-photo sidecars MUST use extension `.dmpms.json` and be stored alongside the photo they describe.

---

## 4. Root Object (Per-Photo Sidecar)

Example:

```json
{
  "dmpmsVersion": "1.3",
  "sourceFile": "IMG_1234.jpg",
  "title": "Fourth of July Picnic",
  "description": "Family picnic at the park",
  "dateTaken": "1976-07",
  "dateRange": {
    "earliest": "1976-07-01",
    "latest": "1976-07-31"
  },
  "tagIDs": ["event.holiday.fourth-of-july", "people.family"],
  "peopleV2": [],
  "virtualCrops": [],
  "history": []
}
```

### Required Fields

* `dmpmsVersion` (String, must be `"1.3"`)
* `sourceFile` (String)

All other fields are optional.

### Deprecated / Removed in v1.3

* `people` (legacy string array) is removed from the spec.
* `tags` (freeform string array) is replaced by `tagIDs`.

Because you’re not maintaining backward compatibility, v1.3 assumes you will regenerate your test corpus accordingly.

---

## 5. Dates

### 5.1 `dateTaken`

* Type: `String`
* Human-entered
* May be partial, ranged, or non-standard
* Tools MUST NOT overwrite a non-empty `dateTaken` without explicit user action

Examples:

* `1976-07-04`
* `1976-07`
* `1976`
* `1970s`
* `1976-06 to 1976-08`
* `1985-1986` (acceptable shorthand)

### 5.2 `dateRange`

Canonical machine-readable range:

```json
{
  "earliest": "YYYY-MM-DD",
  "latest": "YYYY-MM-DD"
}
```

Rules:

* Optional
* MUST be valid if present
* MUST represent an inclusive range
* Consumers SHOULD prefer `dateRange` for computation and filtering
* Writers SHOULD derive or refresh `dateRange` from `dateTaken` when possible

---

## 6. Tags

### 6.1 `tagIDs` (Per-photo)

* Type: `[String]`
* Stable identifiers referencing `_dmpms/tags.json`
* Order is not significant

Example:

```json
"tagIDs": ["event.holiday.christmas", "people.family", "place.colorado.longmont"]
```

Rules:

* Tools SHOULD only write tag IDs that exist in `tags.json` (unless explicitly allowing ad-hoc tags).
* If ad-hoc tags are allowed, tools MUST add them to `tags.json` to keep the archive self-contained.

### 6.2 Tag Dictionary (`_dmpms/tags.json`)

```json
{
  "dmpmsVersion": "1.3",
  "schema": "dmpms.tags",
  "updatedAt": "2026-01-01T00:00:00Z",
  "tags": [
    {
      "tagID": "people.family",
      "label": "Family",
      "type": "group",
      "synonyms": [],
      "sortOrder": 10,
      "isHidden": false,
      "notes": null
    }
  ]
}
```

**Tag fields**

* `tagID` (required, String): stable ID, recommended dotted namespace
* `label` (required, String)
* `type` (optional, String): `"event" | "place" | "topic" | "group" | "role" | "custom"`
* `synonyms` (optional, `[String]`)
* `sortOrder` (optional, Int)
* `isHidden` (optional, Bool)
* `notes` (optional, String)

---

## 7. People Model

### 7.1 Conceptual Layers

1. **Person** — a real individual (canonical attributes used for filtering)
2. **Identity** — a time-versioned legal/structured name for that person
3. **Person-in-Photo** — appearance of a person in a specific image

### 7.2 People Dictionary (`_dmpms/people.json`)

The portable archive MUST store people in `_dmpms/people.json` so that dMPS can filter by gender, birthday, etc., without access to dMPP app settings.

```json
{
  "dmpmsVersion": "1.3",
  "schema": "dmpms.people",
  "updatedAt": "2026-01-01T00:00:00Z",
  "people": [
    {
      "personID": "C1A8...UUID",
      "primaryShortName": "Josh",
      "kind": "human",
      "birthDate": "1976",
      "deathDate": null,
      "gender": "male",
      "isFavorite": false,
      "notes": null,
      "aliases": ["Joshua"],
      "identities": [
        {
          "identityID": "758C...UUID",
          "shortName": "Josh",
          "preferredName": null,
          "aliases": [],
          "givenName": "Joshua",
          "middleName": "Walter",
          "surname": "Magyar",
          "birthDate": "1976",
          "deathDate": null,
          "kind": "human",
          "idDate": "1976-01-01",
          "idReason": "Birth",
          "notes": null
        }
      ]
    },
    {
      "personID": "PET-123...UUID",
      "primaryShortName": "Mochi",
      "kind": "pet",
      "birthDate": "2019-03",
      "gender": "unknown",
      "aliases": [],
      "identities": [
        {
          "identityID": "PETID-456...UUID",
          "shortName": "Mochi",
          "givenName": "Mochi",
          "surname": null,
          "idDate": "2019-03-01",
          "idReason": "Adoption"
        }
      ]
    }
  ]
}
```

#### Person fields (canonical)

* `personID` (required, String): stable unique ID
* `primaryShortName` (required, String): default checklist label
* `kind` (optional, String): `"human"` default, `"pet"` allowed
* `birthDate` (optional, String): dMPMS date grammar
* `deathDate` (optional, String): dMPMS date grammar
* `gender` (optional, String): `"female" | "male" | "nonbinary" | "unknown" | "unspecified"`
* `isFavorite` (optional, Bool)
* `notes` (optional, String)
* `aliases` (optional, `[String]`)
* `identities` (required, `[Identity]`)

**Gender location (answering your question):**

* `gender` SHOULD live on **Person**, not Identity.

  * Gender usually doesn’t change across legal-name identities.
  * Your primary use case (filtering in dMPS) is person-level.

#### Identity fields (versioned name)

* `identityID` (required, String)
* `shortName` (optional, String)
* `preferredName` (optional, String)
* `aliases` (optional, `[String]`)
* `givenName` (required, String)
* `middleName` (optional, String)
* `surname` (optional, String) **(v1.3 change: optional for pets / unknown)**
* `idDate` (required, String): date when identity becomes valid
* `idReason` (required, String): reason category
* `birthDate` / `deathDate` / `kind` / `notes` (optional)

**Name construction rule**

* `displayName` is not stored canonically; it is derived:

  * If `surname` exists and non-empty: `given + (middle?) + surname`
  * Else: `given + (middle?)` (pets, single-name people, unknown surname)

### 7.3 Per-Photo People (`peopleV2`)

Stored in the per-photo sidecar as `peopleV2`. This is the authoritative record of “who is in this photo”.

```json
{
  "id": "2634...UUID",
  "personID": "C1A8...UUID",
  "identityID": "758C...UUID",
  "isUnknown": false,
  "rowIndex": 0,
  "positionIndex": 2,
  "roleHint": "subject",
  "notes": "Front row",
  "shortNameSnapshot": "Josh",
  "displayNameSnapshot": "Joshua Walter Magyar",
  "nameSnapshot": {
    "given": "Joshua",
    "middle": "Walter",
    "surname": "Magyar",
    "display": "Joshua Walter Magyar",
    "sort": "Magyar, Joshua Walter"
  },
  "ageAtPhoto": "8–10"
}
```

#### Fields

* `id` (required, String): unique per-photo row ID
* `personID` (optional but SHOULD be present if known): stable person ID
* `identityID` (optional): chosen identity version for this photo date
* `isUnknown` (required, Bool)
* `rowIndex` (optional, Int, default 0)
* `positionIndex` (optional, Int, default 0)
* `rowName` (optional, String)
* `roleHint` (optional, String)
* `notes` (optional, String)

**Snapshot fields (recommended)**

* `shortNameSnapshot` (optional, String)
* `displayNameSnapshot` (optional, String)
* `nameSnapshot` (optional, object)
* `ageAtPhoto` (optional, String)

Rules:

* `peopleV2` is authoritative for photo membership and ordering.
* Tools MAY re-resolve `identityID` on save using the photo date rule below.
* Snapshots SHOULD be refreshed when identity resolution changes.

### 7.4 Identity resolution rule (for tagging and normalization)

Given a photo date and a person’s identity versions:

* Compute `photoEarliestYMD` (prefer `dateTaken` if parseable, else `dateRange.earliest`).
* Choose the identity whose `idDate` is the **latest date <= photoEarliestYMD**.
* If none qualify, choose the earliest identity.

---

## 8. Virtual Crops

Per-photo crops are stored in `virtualCrops` as non-destructive rectangles relative to the original image coordinate space.

This spec supports **two crop layers**:

1. **Crop preset definitions** (shared, in `_dmpms/crops.json`, optional)
2. **Crop instances** (per photo, referencing a preset or ad-hoc)

### 8.1 Crop Dictionary (`_dmpms/crops.json`) — Optional but recommended

If you want consistent naming and reuse (“16:9 Hero”, “8×10 Print”, “Window Projection”), a shared crop dictionary is worth it.

```json
{
  "dmpmsVersion": "1.3",
  "schema": "dmpms.crops",
  "updatedAt": "2026-01-01T00:00:00Z",
  "presets": [
    {
      "cropID": "aspect.16x9",
      "label": "16:9",
      "kind": "aspect",
      "aspectRatio": { "w": 16, "h": 9 },
      "notes": null,
      "isHidden": false
    },
    {
      "cropID": "print.8x10",
      "label": "8×10 Print",
      "kind": "print",
      "aspectRatio": { "w": 4, "h": 5 }
    }
  ]
}
```

Preset fields:

* `cropID` (required, String): stable ID
* `label` (required, String)
* `kind` (optional, String): `"aspect" | "print" | "display" | "custom"`
* `aspectRatio` (optional): `{ "w": Int, "h": Int }`
* `notes` (optional)
* `isHidden` (optional, Bool)

### 8.2 Per-photo crop instances (`virtualCrops`)

```json
"virtualCrops": [
  {
    "id": "CROP-ROW-UUID",
    "cropID": "aspect.16x9",
    "labelSnapshot": "16:9",
    "rect": { "x": 0.12, "y": 0.08, "w": 0.76, "h": 0.76 },
    "coordinateSpace": "unit",
    "createdAt": "2026-01-01T00:00:00Z",
    "notes": null
  }
]
```

Crop instance fields:

* `id` (required): unique per-photo crop row ID
* `cropID` (optional): references `_dmpms/crops.json` preset
* `labelSnapshot` (optional): denormalized convenience label
* `rect` (required): rectangle
* `coordinateSpace` (required): `"unit"` (0–1 normalized) recommended
* `createdAt` (optional ISO timestamp)
* `notes` (optional)

Rect definition:

* `x`, `y`, `w`, `h` as Doubles
* For `"unit"`, values are normalized to original image dimensions:

  * `x,y` top-left origin
  * `w,h` width/height in [0,1]

Rules:

* Per-photo crops MUST be non-destructive.
* Tools SHOULD store crops in `"unit"` to survive resizing and transcoding.

---

## 9. History

* Optional array of meaningful change events.

Example:

```json
"history": [
  {
    "at": "2026-01-01T00:00:00Z",
    "tool": "dMPP",
    "action": "normalizedPeople",
    "notes": "Resolved identity versions based on photo date"
  }
]
```

Rules:

* Writers MAY coalesce events (avoid spammy history).
* History is not required for correctness.

---

## 10. Optional Archive Metadata (`_dmpms/archive.json`)

This file is optional. It exists to describe the archive itself (not a photo).

```json
{
  "dmpmsVersion": "1.3",
  "schema": "dmpms.archive",
  "title": "Magyar Family Archive",
  "notes": "Portable archive for dMPP/dMPS",
  "createdAt": "2026-01-01T00:00:00Z"
}
```

---

## 11. Compatibility Rules (Within v1.3+ tools)

### Readers

* MUST ignore unknown fields
* MUST tolerate missing optional files (`archive.json`, `crops.json`)
* SHOULD degrade gracefully if dictionaries are missing (but filtering features may be limited)

### Writers

* MUST preserve unknown fields in sidecars and dictionaries
* MUST write stable IDs (personID/identityID/tagID/cropID) rather than labels where IDs are defined

### Versioning

* Minor bumps (1.3 → 1.4) must remain non-destructive.
* Tools SHOULD be tolerant of newer minor versions by preserving unknown fields.

---

## 12. Non-Goals

* No database semantics
* No cloud sync assumptions
* No UI-only state (window positions, selection, etc.)
* No automatic inference requirements
* No guarantee of uniqueness of human labels (IDs are the truth)

---

## Summary of Key Changes from v1.2 → v1.3

* Defines **portable family archive layout** with `_dmpms/` dictionaries.
* Replaces `tags: [String]` with `tagIDs: [String]` + `tags.json`.
* Removes legacy `people: [String]`; `peopleV2` is sole per-photo representation.
* Adds `people.json` as canonical person + identity registry (portable, filterable).
* Makes `surname` optional (supports pets and single-name identities).
* Adds optional `crops.json` (recommended if you want reusable preset names across photos).

---

**End of dMPMS v1.3 Draft**
