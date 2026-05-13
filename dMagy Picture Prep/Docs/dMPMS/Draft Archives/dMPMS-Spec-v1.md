# **dMagy Photo Metadata Standard (dMPMS)**

### **Version 1.0 — Draft Specification**

---

## **1. Introduction**

The **dMagy Photo Metadata Standard (dMPMS)** defines an open, human-readable, and application-agnostic method for attaching structured metadata to digital images **without modifying the original file**.
It is designed to support:

* Image titles and descriptions
* Tags and categorization
* People and subjects
* Virtual crop definitions
* Processing history
* Interoperability across multiple applications

dMPMS exists to provide a clean, extensible metadata layer for photographers, archivists, curators, and developers—enabling richer workflows without duplicating images or embedding proprietary/private metadata.

The standard is used by:

* **dMagy Picture Prep (dMPP)** — for renaming, tagging, and creating virtual crops
* **dMagy Picture Show (dMPS)** — for displaying images and selecting appropriate crops during slideshows

This document defines the structure, naming conventions, storage format, and validation rules for dMPMS metadata files.

---

## **2. Guiding Principles**

dMPMS is designed around the following principles:

1. **Non-destructive**
   The original image file must never be modified.

2. **Readable by humans and machines**
   JSON is used for clarity and portability.

3. **File-based, not database-dependent**
   Metadata exists as standalone sidecar files.

4. **Normalized coordinate systems**
   Virtual crop definitions must be resolution-independent.

5. **Explicit versioning**
   `dmpms_version` ensures backward compatibility.

6. **Minimal required fields**
   Only essential fields are required; all others are optional.

7. **Extensible**
   Fields may be added in future versions without breaking older files.

---

## **3. Storage Model**

### **3.1 Sidecar Files**

Each image has a matching metadata file stored next to it.

Example:

```
IMG_1234.jpg
IMG_1234.jpg.dmpms.json
```

### **3.2 Naming Convention**

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

This ensures multiple images with the same basename but different extensions can coexist unambiguously.

### **3.3 Supported Image Formats**

dMPMS is file-format agnostic. Common formats include:

* JPG / JPEG
* PNG
* TIFF
* HEIC / HEIF
* WebP
* RAW formats (sidecar still works)

---

## **4. Data Format**

dMPMS uses UTF-8 JSON with no Byte Order Mark (BOM).

### **4.1 Top-Level Structure**

```json
{
  "dmpms_version": "1.0",
  "source_file": "IMG_0001.jpg",

  "title": "Mesa Verde Twilight",
  "description": "Dan and Amy at cliff dwellings",

  "tags": ["vacation", "family", "mesa-verde"],
  "people": [{ "name": "Dan" }, { "name": "Amy" }],

  "date_taken": "2025-06-22",

  "virtual_crops": [
    {
      "id": "crop-16x9-01",
      "label": "Landscape 16:9",
      "aspect_ratio": "16:9",
      "rect": { "x": 0.05, "y": 0.10, "width": 0.90, "height": 0.80 }
    }
  ],

  "history": [
    {
      "action": "renamed",
      "old_name": "IMG_0001.JPG",
      "new_name": "Mesa_Verde_Twilight.jpg",
      "timestamp": "2025-06-23T08:14:22-07:00"
    }
  ]
}
```

---

## **5. Field Definitions**

### **5.1 `dmpms_version` (required)**

Semantic version number indicating the metadata schema version used.
Example: `"1.0"`

---

### **5.2 `source_file` (required)**

The filename (with extension) of the associated image.
Example: `"IMG_0001.jpg"`

---

### **5.3 `title` (optional)**

A human-readable title used for display or classification.
Example: `"Mesa Verde Twilight"`

---

### **5.4 `description` (optional)**

Long-form notes or context for the image.

---

### **5.5 `tags` (optional)**

List of lowercase, hyphenated keywords.
Example:

```json
["family", "2025-trip", "mountains"]
```

---

### **5.6 `people` (optional)**

List of people associated with the image.

```json
[{ "name": "Dan" }]
```

Future versions may include:

* face regions
* identifiers
* roles

---

## **5.7 `date_taken` (optional)**

Represents the date or approximate date when the image’s subject matter occurred.
dMPMS supports **multiple levels of precision**, suitable for digital photos and historical scans.

Accepted formats:

| Format                  | Example                     | Meaning                |
| ----------------------- | --------------------------- | ---------------------- |
| Full ISO-8601 timestamp | `2025-06-22T19:45:00-07:00` | Exact capture time     |
| Full date               | `2025-06-22`                | Exact day              |
| Year + month            | `2025-06`                   | Month-level accuracy   |
| Year only               | `2025`                      | Year-level accuracy    |
| Decade                  | `2020s`                     | The decade (2020–2029) |

Applications may extract this value automatically from **EXIF** when present, unless the user overrides it.

dMPMS does **not** support uncertain-year formats such as `202X`.
When only decade-level accuracy is known, the decade format should be used.
If no date is known, this field may be omitted.

---

## **6. Virtual Crops**

Virtual crops define non-destructive viewports into an image.

### **6.1 Structure**

```json
{
  "id": "crop-16x9-01",
  "label": "Landscape 16:9",
  "aspect_ratio": "16:9",
  "rect": { "x": 0.05, "y": 0.10, "width": 0.90, "height": 0.80 }
}
```

### **6.2 Coordinate System**

All crop rectangles use **normalized coordinates**:

```
0.0 ≤ x, y, width, height ≤ 1.0
```

This makes crops resolution-independent.

### **6.3 Aspect Ratio Format**

Always `"<width>:<height>"`, e.g.:

* `"16:9"`
* `"8:10"`
* `"1:1"`

### **6.4 Multiple Crops**

Images may include:

* multiple 16:9 crops
* multiple portrait crops
* specialty crops (banner, print, poster)

`id` must be unique per image.

---

## **7. History Log**

The `history` array is an **append-only** record of meaningful events.

Example:

```json
{
  "action": "added_crop",
  "crop_id": "crop-16x9-02",
  "timestamp": "2025-06-24T11:21:44-07:00"
}
```

Supported actions include:

* `"renamed"`
* `"added_crop"`
* `"modified_crop"`
* `"deleted_crop"`
* `"tagged"`
* `"untagged"`

---

## **8. Extensibility**

dMPMS is designed to evolve.
Applications **must ignore unknown fields** gracefully.

Potential future extensions:

* Albums
* Face regions
* GPS
* AI descriptions
* Quality scores

---

## **9. Validation**

dMPMS files may be validated using a JSON Schema.
A reference implementation is provided in:

```
dMPMS-Schema.json
```

Recommended tools:

* `ajv`
* `jsonschema`
* Online validators

---

## **10. License**

The dMagy Photo Metadata Standard (dMPMS) is released under the
**Creative Commons Attribution 4.0 (CC BY 4.0)** license.

This permits:

* Use
* Modification
* Distribution
* Commercial implementation

With attribution to:

**Daniel P. Magyar (“dMagy”)**

---

## **11. Example Metadata Files**

The repository should include a `/Examples` directory containing:

* Basic metadata
* Multiple crops
* Decade-based dates
* Rename and crop history

Example filenames:

```
sample1.jpg.dmpms.json
sample2.heic.dmpms.json
album.dmpms.json
```

---

## **12. Reference Implementation**

Two applications serve as the reference implementations:

* **dMagy Picture Prep (dMPP):**
  Writes, edits, and validates dMPMS metadata.

* **dMagy Picture Show (dMPS):**
  Reads dMPMS metadata for filtering, organization, and slideshow crop selection.

---

## **13. Version History**

**v1.0 (Draft)**

* Initial specification
* JSON sidecar format
* Virtual crop model
* History log
* Normalized coordinates
* Multiple date formats + decade support
* EXIF-aware behavior
* File naming rules
* Examples and schema

