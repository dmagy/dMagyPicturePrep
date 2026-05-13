# dMPMS v1.2 — Draft Specification

**dMagy Photo Metadata Standard**  
**Status:** Draft (derived from dMPP-Context-v10 reality)  
**Intended Consumers:** dMPP, dMPS, and other read/write tools

---

## 1. Purpose

dMPMS defines a **portable, sidecar-based metadata format** for photographs that supports long-term reuse, human curation, and multiple downstream presentation tools.

The standard prioritizes:

- Human-entered meaning over automated inference
- Non-destructive editing
- Forward compatibility
- Tool independence

Sidecars are JSON files stored alongside images using the extension:

```
.dmpms.json
```

---

## 2. Design Principles

1. **Sidecar-first**  
   Image files are never modified.

2. **Human authority**  
   All people, dates, and meanings are explicitly curated.

3. **Structured where it matters**  
   Freeform text is allowed, but computable fields are normalized.

4. **Readers must be tolerant**  
   Writers must not destroy unknown fields.

---

## 3. Root Object

```json
{
  "dmpmsVersion": "1.2",
  "sourceFile": "IMG_1234.jpg",
  "title": "Fourth of July Picnic",
  "description": "Family picnic at the park",
  "dateTaken": "1976-07",
  "dateRange": {
    "earliest": "1976-07-01",
    "latest": "1976-07-31"
  },
  "tags": ["Family", "Holiday"],
  "people": ["Dan", "Amy"],
  "peopleV2": [],
  "virtualCrops": [],
  "history": []
}
```

### Required Fields

- `dmpmsVersion`
- `sourceFile`

All other fields are optional.

---

## 4. Dates

### 4.1 `dateTaken`

- Type: `String`
- Human-entered
- May be partial, ranged, or non-standard
- Never auto-overwritten once set by a user

Examples:

- `1976-07-04`
- `1976-07`
- `1976`
- `1970s`
- `1976-06 to 1976-08`

---

### 4.2 `dateRange`

```json
{
  "earliest": "YYYY-MM-DD",
  "latest": "YYYY-MM-DD"
}
```

- Optional
- Canonical and machine-readable
- Derived from `dateTaken` when possible

Rules:

- MUST be valid if present
- MUST represent an inclusive range
- Consumers SHOULD prefer `dateRange` for computation

---

## 5. People Model

### 5.1 Conceptual Layers

1. **Person** – a real individual (not stored directly in sidecar)
2. **Identity** – a specific name/version of that person
3. **Person-in-Photo** – appearance of a person in a specific image

---

### 5.2 Identity (`DmpmsIdentity`)

Identities are stored in a tool-managed registry (not in the sidecar) and referenced by ID.

```json
{
  "identityID": "uuid",
  "shortName": "Amy",
  "givenName": "Amy",
  "middleName": null,
  "surname": "Magyar",
  "idDate": "2001-06",
  "idReason": "Marriage"
}
```

Rules:

- Identity IDs are stable
- Multiple identities may exist per person
- Identity dates represent when the name became effective

---

### 5.3 Person-in-Photo (`DmpmsPersonInPhoto`)

Stored in the sidecar as `peopleV2`.

```json
{
  "personID": "uuid",
  "identityID": "uuid",
  "role": "Subject",
  "notes": "Front row"
}
```

Rules:

- `peopleV2` is the authoritative people representation
- Identity SHOULD be selected based on photo date
- Tools MAY re-resolve identity references on save

---

### 5.4 Legacy `people` Field

```json
"people": ["Dan", "Amy"]
```

- Retained for backward compatibility
- Treated as a **derived snapshot**
- MUST be regenerated from `peopleV2` by writers
- MUST NOT be edited directly by tools that support `peopleV2`

---

## 6. Tags

- Type: `[String]`
- Freeform, tool-defined vocabulary
- Order is not significant

Tools MAY enforce mandatory tags.

---

## 7. Virtual Crops

- Stored as normalized rectangles
- Reference the original image coordinate space
- Consumers MAY select different crops per display target

(See crop model definitions for details.)

---

## 8. History

- Optional
- Array of events describing meaningful changes
- Writers MAY coalesce events for clarity

---

## 9. Compatibility Rules

### Readers

- MUST ignore unknown fields
- MUST tolerate missing optional fields

### Writers

- MUST preserve unknown fields
- MUST NOT silently discard data

### Versioning

- Minor version bumps (1.x) must remain backward compatible

---

## 10. Non-Goals

- No database semantics
- No cloud sync assumptions
- No UI-specific state
- No automated inference requirements

---

**End of dMPMS v1.2 Draft**

