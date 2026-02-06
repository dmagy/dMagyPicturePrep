
# dMPMS v1.4 — Draft Specification

**dMagy Photo Metadata Standard**  
**Status:** Draft (sidecar-first, portable archive)  
**Intended Consumers:** dMPP, dMPS, and other read/write tools

---

## 0. Version Summary

### 0.1 What’s new in v1.4 (vs v1.3)

v1.4 is a **non-destructive, minor** update. Primary goals:

1) **Headshot crops**: define a portable way to represent **multiple headshot crops per image**, each optionally linked to a person.  
2) **Portable registries flexibility**: allow archives to store shared registries either:
   - as **single dictionary files** (classic `_dmpms/*.json`), or
   - as **sharded / per-entity files** (e.g., per-person JSON) while still being portable and tool-independent.
3) **Richer dictionary entries**: explicitly support **human descriptions/notes** for tags/crops/locations in dictionaries.

> Important: **Reserved tags** (like “Do Not Display” / “Flagged”) are *tool policy*, not part of the dMPMS standard. A tool MAY enforce them; dMPMS does not require any specific reserved tag names.

### 0.2 Compatibility expectations

- **Readers MUST** ignore unknown fields and tolerate missing optional files.  
- **Writers MUST** preserve unknown fields they do not understand.  
- **v1.4 tools SHOULD** be able to read v1.3 archives and sidecars.  
- **Minor bump rule**: v1.3 → v1.4 must remain non-destructive; older v1.3 readers should still find core fields.

---

## 1. Purpose

dMPMS defines a **portable family archive** format for photographs. It is **sidecar-first**, supports long-term curation, and enables multiple downstream tools (especially dMPS) to **filter and present** photos using shared, canonical people/tag/crop definitions.

The standard prioritizes:

- Human-entered meaning over automated inference  
- Non-destructive editing  
- Tool independence  
- Computable structure for filtering and display  
- Portability (copy the folder, everything works)

---

## 2. Design Principles

1) **Sidecar-first**  
   - Image binaries are never modified.  
   - Photo metadata lives next to the image in `.dmpms.json`.

2) **Archive portability**  
   - Shared dictionaries (people/tags/crops/locations) live **inside the archive**, not app-only settings.

3) **Human authority**  
   - People, dates, tags, and crops are curated, not inferred.  
   - Tools may derive machine-readable fields, but must not override user-entered intent.

4) **Structured where it matters**  
   - People and filters use stable IDs.  
   - Dates support loose human grammar plus a canonical range for computation.

5) **Writers preserve unknown fields**  
   - Tools must not destroy fields they don’t understand, in sidecars or dictionaries.

---

## 3. Archive Layout

A dMPMS “portable family archive” is a folder containing photos plus a reserved metadata directory:

```

/Photos/...                        (your images in any subfolders)
/_dmpms/people.json                (shared people + identities)     OPTIONAL*
/_dmpms/people/                    (people shards)                 OPTIONAL*
/_dmpms/tags.json                  (shared tag dictionary)         OPTIONAL
/_dmpms/crops.json                 (shared crop presets)           OPTIONAL
/_dmpms/locations.json             (shared locations dictionary)   OPTIONAL
/_dmpms/archive.json               (optional archive metadata)     OPTIONAL
/**/*.dmpms.json                   (per-photo sidecars)

````

### 3.1 Reserved folder name

- The reserved folder name MUST be `_dmpms` (case-sensitive).

### 3.2 Dictionary strategy (v1.4)

An archive MAY use either strategy, or even both (tools should merge with precedence rules):

**Strategy A — Monolithic dictionaries**
- `_dmpms/people.json`
- `_dmpms/tags.json`
- `_dmpms/crops.json`
- `_dmpms/locations.json`

**Strategy B — Sharded dictionaries**
- `_dmpms/people/` containing per-person files (see §7.2.3)

> *People registry is OPTIONAL in the standard, but tools that want filtering across the archive will usually require it.

### 3.3 Precedence rule (recommended)

If both are present:
- A tool SHOULD treat the union as authoritative, but MUST avoid destructive merging.
- A safe default is:
  - Load shards, then load monolithic and let monolithic win on conflicts **only if it is explicitly marked as authoritative** in `_dmpms/archive.json` (see §11).  
  - If no authority is declared, prefer “newer updatedAt” as a tie-breaker.

---

## 4. Root Object (Per-Photo Sidecar)

Example:

```json
{
  "dmpmsVersion": "1.4",
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
````

### 4.1 Required fields

* `dmpmsVersion` (String, must be `"1.4"` for v1.4 writers)
* `sourceFile` (String)

All other fields are optional.

### 4.2 Backward compatibility guidance

Readers SHOULD accept:

* `dmpmsVersion` missing (treat as legacy / unknown)
* `dmpmsVersion` `"1.3"` (treat as v1.3)

Writers SHOULD write `"1.4"` once they use any v1.4-only fields.

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
* `1985-1986`

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

Rules:

* Tools SHOULD only write tag IDs that exist in the tag dictionary unless explicitly allowing ad-hoc tags.
* If ad-hoc tags are allowed, tools SHOULD add them to the dictionary to keep the archive self-contained.

### 6.2 Tag Dictionary (`_dmpms/tags.json`)

```json
{
  "dmpmsVersion": "1.4",
  "schema": "dmpms.tags",
  "updatedAtUTC": "2026-02-05T00:00:00Z",
  "tags": [
    {
      "tagID": "people.family",
      "label": "Family",
      "description": "Used for family members together; not extended relatives unless present.",
      "type": "group",
      "synonyms": [],
      "sortOrder": 10,
      "isHidden": false
    }
  ]
}
```

**Tag fields**

* `tagID` (required, String): stable ID, recommended dotted namespace
* `label` (required, String)
* `description` (optional, String): human guidance/meaning
* `type` (optional, String): `"event" | "place" | "topic" | "group" | "role" | "custom"`
* `synonyms` (optional, `[String]`)
* `sortOrder` (optional, Int)
* `isHidden` (optional, Bool)

---

## 7. People Model

### 7.1 Conceptual Layers

1. **Person** — a real individual (canonical attributes used for filtering)
2. **Identity** — a time-versioned structured name for that person
3. **Person-in-Photo** — appearance of a person in a specific image

### 7.2 People Dictionary options

#### 7.2.1 Monolithic (`_dmpms/people.json`)

```json
{
  "dmpmsVersion": "1.4",
  "schema": "dmpms.people",
  "updatedAtUTC": "2026-02-05T00:00:00Z",
  "people": [
    {
      "personID": "E182EA2C-DB8D-4C09-BCAF-5C025A4F9E4C",
      "primaryShortName": "Millie",
      "kind": "human",
      "birthDate": "1915-03-12",
      "deathDate": null,
      "gender": "female",
      "isFavorite": false,
      "notes": null,
      "aliases": [],
      "identities": [
        {
          "identityID": "FE1154D4-B9E8-4078-AE69-416CE194B85E",
          "shortName": "Millie",
          "preferredName": null,
          "aliases": [],
          "givenName": "Mildred",
          "middleName": "Ione",
          "surname": "Smith",
          "idDate": "1915-03-12",
          "idReason": "Birth",
          "notes": null
        }
      ]
    }
  ]
}
```

#### 7.2.2 Person fields (canonical)

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

#### 7.2.3 Sharded people (`_dmpms/people/person_<personID>.json`)

A tool MAY store each person’s identity timeline in its own file:

Path pattern:

```
_dmpms/people/person_<personID>.json
```

Recommended file shape (v1.4 canonical for shards):

```json
{
  "dmpmsVersion": "1.4",
  "schema": "dmpms.person",
  "person": {
    "personID": "E182EA2C-DB8D-4C09-BCAF-5C025A4F9E4C",
    "primaryShortName": "Millie",
    "kind": "human",
    "birthDate": "1915-03-12",
    "deathDate": null,
    "gender": "female",
    "isFavorite": false,
    "notes": null,
    "aliases": []
  },
  "identities": [
    {
      "identityID": "FE1154D4-B9E8-4078-AE69-416CE194B85E",
      "shortName": "Millie",
      "givenName": "Mildred",
      "middleName": "Ione",
      "surname": "Smith",
      "idDate": "1915-03-12",
      "idReason": "Birth"
    }
  ],
  "updatedAtUTC": "2026-02-05T00:00:00Z"
}
```

Notes:

* Sharded format is **recommended** to include the `person` object so the file is self-contained.
* Readers SHOULD tolerate legacy shard shapes (including “array of identities only”), but writers SHOULD prefer the wrapped canonical shard shape above in v1.4.

### 7.3 Identity fields (versioned name)

* `identityID` (required, String)
* `shortName` (optional, String)
* `preferredName` (optional, String)
* `aliases` (optional, `[String]`)
* `givenName` (required, String)
* `middleName` (optional, String)
* `surname` (optional, String)
* `idDate` (required, String): date when identity becomes valid
* `idReason` (required, String): reason category
* `notes` (optional)

**Name construction rule**

* `displayName` is derived:

  * If `surname` exists and non-empty: `given + (middle?) + surname`
  * Else: `given + (middle?)`

### 7.4 Per-Photo People (`peopleV2`)

Stored in the per-photo sidecar as `peopleV2`. This is the authoritative record of “who is in this photo”.

```json
{
  "id": "2634...UUID",
  "personID": "E182EA2C-DB8D-4C09-BCAF-5C025A4F9E4C",
  "identityID": "FE1154D4-B9E8-4078-AE69-416CE194B85E",
  "isUnknown": false,
  "rowIndex": 0,
  "positionIndex": 2,
  "roleHint": "subject",
  "notes": "Front row",
  "shortNameSnapshot": "Millie",
  "displayNameSnapshot": "Mildred Ione Smith",
  "nameSnapshot": {
    "given": "Mildred",
    "middle": "Ione",
    "surname": "Smith",
    "display": "Mildred Ione Smith",
    "sort": "Smith, Mildred Ione"
  },
  "ageAtPhoto": "8–10"
}
```

Rules:

* `peopleV2` is authoritative for photo membership and ordering.
* Tools MAY re-resolve `identityID` on save using the identity resolution rule below.
* Snapshots SHOULD be refreshed when identity resolution changes.

### 7.5 Identity resolution rule

Given a photo date and a person’s identity versions:

* Compute `photoEarliestYMD` (prefer `dateRange.earliest` if present; otherwise parse from `dateTaken` when possible).
* Choose the identity whose `idDate` is the **latest date <= photoEarliestYMD**.
* If none qualify, choose the earliest identity.

---

## 8. Locations (v1.4 formalization)

v1.3 discussed locations conceptually; v1.4 explicitly defines a portable locations dictionary.

### 8.1 Per-photo reference

Sidecars MAY include either:

* `locationID` (String) referencing dictionary, or
* `locationIDs` ([String]) for multi-location photos

Tools should choose one approach; multi-location is optional.

Example:

```json
"locationID": "place.us.co.longmont.high-meadow"
```

### 8.2 Locations dictionary (`_dmpms/locations.json`)

```json
{
  "dmpmsVersion": "1.4",
  "schema": "dmpms.locations",
  "updatedAtUTC": "2026-02-05T00:00:00Z",
  "locations": [
    {
      "locationID": "place.us.co.longmont.high-meadow",
      "shortName": "High Meadow",
      "description": "Dan & Amy's House (2019-)",
      "streetAddress": "1026 High Meadow Ct",
      "city": "Longmont",
      "state": "CO",
      "country": "United States",
      "aliases": []
    }
  ]
}
```

Location fields:

* `locationID` (required, String)
* `shortName` (required, String)
* `description` (optional, String)
* `streetAddress` (optional, String)
* `city` / `state` / `country` (optional, String)
* `aliases` (optional, `[String]`)

---

## 9. Virtual Crops (v1.4)

Per-photo crops are stored in `virtualCrops` as non-destructive rectangles relative to the original image coordinate space.

v1.4 adds a **first-class headshot crop concept**.

### 9.1 Crop dictionary (`_dmpms/crops.json`) — Optional but recommended

```json
{
  "dmpmsVersion": "1.4",
  "schema": "dmpms.crops",
  "updatedAtUTC": "2026-02-05T00:00:00Z",
  "presets": [
    {
      "cropID": "aspect.16x9",
      "label": "16:9",
      "kind": "aspect",
      "aspectRatio": { "w": 16, "h": 9 },
      "description": "Standard widescreen crop.",
      "isHidden": false
    },
    {
      "cropID": "headshot.tight.8x10",
      "label": "Headshot (Tight)",
      "kind": "headshot",
      "variant": "tight",
      "aspectRatio": { "w": 4, "h": 5 },
      "description": "Head + a small amount of shoulders; consistent sizing via guide marks.",
      "isHidden": false
    },
    {
      "cropID": "headshot.full.8x10",
      "label": "Headshot (Full)",
      "kind": "headshot",
      "variant": "full",
      "aspectRatio": { "w": 4, "h": 5 },
      "description": "Head + upper torso; consistent sizing via guide marks.",
      "isHidden": false
    }
  ]
}
```

Preset fields:

* `cropID` (required, String): stable ID
* `label` (required, String)
* `kind` (optional, String): `"aspect" | "print" | "display" | "headshot" | "custom"`
* `variant` (optional, String): for `kind:"headshot"`, values `"tight" | "full"` are RECOMMENDED
* `aspectRatio` (optional): `{ "w": Int, "h": Int }`
* `description` (optional, String)
* `isHidden` (optional, Bool)

### 9.2 Per-photo crop instances (`virtualCrops`)

```json
"virtualCrops": [
  {
    "id": "CROP-ROW-UUID",
    "cropID": "aspect.16x9",
    "labelSnapshot": "16:9",
    "rect": { "x": 0.12, "y": 0.08, "w": 0.76, "h": 0.76 },
    "coordinateSpace": "unit",
    "createdAtUTC": "2026-02-05T00:00:00Z",
    "notes": null
  },
  {
    "id": "CROP-ROW-UUID-2",
    "kind": "headshot",
    "variant": "tight",
    "personID": "E182EA2C-DB8D-4C09-BCAF-5C025A4F9E4C",
    "displayLabel": "Millie — Headshot (Tight)",
    "rect": { "x": 0.33, "y": 0.10, "w": 0.30, "h": 0.50 },
    "coordinateSpace": "unit",
    "createdAtUTC": "2026-02-05T00:00:00Z"
  }
]
```

Crop instance fields (v1.4):

* `id` (required): unique per-photo crop row ID
* `cropID` (optional): references `_dmpms/crops.json`
* `labelSnapshot` (optional): denormalized convenience label
* `rect` (required): rectangle
* `coordinateSpace` (required): `"unit"` (0–1 normalized) recommended
* `createdAtUTC` (optional ISO timestamp)
* `notes` (optional)

**Headshot additions (v1.4):**

* `kind` (optional String): use `"headshot"` to declare a headshot instance
* `variant` (optional String): RECOMMENDED `"tight" | "full"`
* `personID` (optional String): links crop instance to a person

  * A tool MAY require this for headshots, but the standard allows it to be missing for “unknown subject headshot”.
* `displayLabel` (optional String): human label, e.g. `"<ShortName> — Headshot (Tight)"`

#### 9.2.1 Uniqueness guidance (recommended, tool-enforced)

dMPMS does not enforce uniqueness, but RECOMMENDS a tool prevent duplicates like:

* multiple headshots with same `(personID, variant)` in a single photo.

#### 9.2.2 Missing person references

If a `personID` referenced by a headshot is not present in the people dictionary:

* Readers MUST still retain and display the crop.
* Tools SHOULD show it as “missing person” and allow relinking by ID when possible.

---

## 10. History

Optional array of meaningful change events.

Example:

```json
"history": [
  {
    "atUTC": "2026-02-05T00:00:00Z",
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

## 11. Optional Archive Metadata (`_dmpms/archive.json`)

Optional file describing the archive itself (not a photo).

```json
{
  "dmpmsVersion": "1.4",
  "schema": "dmpms.archive",
  "title": "Magyar Family Archive",
  "notes": "Portable archive for dMPP/dMPS",
  "createdAtUTC": "2026-02-05T00:00:00Z",
  "registryStrategy": {
    "people": "sharded",
    "tags": "monolithic",
    "crops": "monolithic",
    "locations": "monolithic",
    "authoritative": "shards"
  }
}
```

Notes:

* `registryStrategy` is OPTIONAL.
* If present, it can guide tools on precedence rules for monolithic vs shards.

---

## 12. Compatibility Rules (Within v1.3+ tools)

### 12.1 Readers

* MUST ignore unknown fields
* MUST tolerate missing optional files (`archive.json`, `crops.json`, `locations.json`, `people.json`)
* SHOULD degrade gracefully if dictionaries are missing (filtering may be limited)
* SHOULD tolerate legacy formats:

  * `tags.json` as `["a","b"]`
  * `tags.json` as `{ "tags": ["a","b"] }`
  * legacy people shards with “array only” identities

### 12.2 Writers

* MUST preserve unknown fields in sidecars and dictionaries
* MUST write stable IDs where dictionaries are used:

  * `personID` / `identityID` / `tagID` / `cropID` / `locationID`
* SHOULD write `updatedAtUTC` in dictionaries when modifying them
* SHOULD prefer `"unit"` coordinateSpace for crops

### 12.3 Versioning

* Minor bumps (1.3 → 1.4) must remain non-destructive.
* Tools SHOULD be tolerant of newer minor versions by preserving unknown fields.

---

## 13. Non-Goals

* No database semantics
* No cloud sync assumptions
* No UI-only state (window positions, selections)
* No automatic inference requirements
* No guarantee of uniqueness of human labels (IDs are the truth)
* No “reserved tag” mandates (tool policy, not standard)

---

## Summary of Key Changes from v1.3 → v1.4

* Adds a portable representation for **headshot crops** (kind + variant + optional personID + displayLabel).
* Formalizes a **locations dictionary** and optional per-photo `locationID` reference.
* Allows **people dictionary sharding** into per-person files while remaining portable.
* Adds/clarifies dictionary `description` fields for human meaning-sharing.

---

**End of dMPMS v1.4 Draft Specification**
