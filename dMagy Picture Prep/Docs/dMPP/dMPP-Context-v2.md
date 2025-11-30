# dMPP-Context v2.md

**dMagy Picture Prep — Application Context & Architecture Overview**
**Version:** dMPP-2025-11-22-CTX2

---

## **1. Purpose of dMagy Picture Prep (dMPP)**

dMPP is a macOS utility that prepares personal and archival photographs for advanced display workflows. It provides an efficient, non-destructive way to:

* Assign rich metadata according to the **dMagy Photo Metadata Standard (dMPMS)**
* Create and manage **virtual crops** customized for multiple display targets
* Navigate through folders of images in a structured reviewing workflow
* Persist edits in **sidecar metadata files** for use in other applications (e.g., dMagy Picture Show)

Where **dMPS shows pictures**, **dMPP prepares them**.

----

## **2. Relationship to dMPMS and dMPS**

### **dMPP ↔ dMPMS**

dMPP is the first full implementation of the dMPMS metadata standard.
It is responsible for:

* Loading metadata from sidecar `.dmpms.json` files
* Writing updated metadata in the standardized format
* Enforcing dMPMS compatibility at runtime

### **dMPP ↔ dMPS**

The apps communicate exclusively through **dMPMS sidecars**.
dMPP sets up image metadata and virtual crops; dMPS consumes them when rendering slideshows across multiple displays.

They are intentionally **decoupled** to keep the viewer lightweight and the prep tool flexible.

---

## **3. Current Features (What’s Built Now)**

**As of dMPP-2025-11-22-CTX2**

---

### **3.1 Folder Selection & Image Navigation**

* Uses `NSOpenPanel` to pick any accessible folder

* Scans for supported image formats:

  `jpg, jpeg, png, heic, tif, tiff, webp`

* Builds an ordered list of images

* Supports:

  * **Next Image**
  * **Previous Image**
  * Automatic saving when switching

* Gracefully handles switching folders (saving current metadata first)

---

### **3.2 Image Preview & Metadata Binding**

* Displays a large, scalable image preview using `NSImage`

* Metadata form with live bindings to `DmpmsMetadata`:

  * `title`
  * `description`
  * `dateTaken` (supports full and partial dates: YYYY-MM-DD, YYYY-MM, YYYY, YYYYs)
  * `tags` (comma-separated)
  * `people` (comma-separated)

* UI uses SwiftUI `Form`, `TextField`, and binding helpers

All editing is live-bound to the ViewModel.

---

### **3.3 Virtual Crop System**

Every image loads with two default crops:

* **Landscape 16:9**
* **Portrait 8×10**

Users can:

* Add preset crops (16:9, 8×10, 1:1)
* Add a new default 16:9 crop
* Duplicate any existing crop
* Delete any crop
* Switch between crops via a **TabView**
* See a crop preview overlay within the image

Crop rectangles use:

```
RectNormalized(x: 0–1, y: 0–1, width: 0–1, height: 0–1)
```

and are encoded in the sidecar.

---

### **3.4 dMPMS Sidecar Read/Write (Complete & Verified)**

For each image, dMPP reads/writes:

```
<filename>.<extension>.dmpms.json
```

On **Load**:

* If sidecar exists → decode and bind
* If missing → create default metadata
* Ensures `sourceFile` always matches the real filename

On **Save** (Next/Previous/folder change):

* Writes JSON with `.prettyPrinted` + `.sortedKeys`
* Uses atomic replacement to prevent corruption
* Includes default or user-created crops
* Validates metadata structure per dMPMS
* Works across multiple navigation events

**Sidecar writing is verified working with App Sandbox enabled.**

---

### **3.5 macOS Sandbox Behavior (Resolved)**

macOS restricts writing to certain folder names:

* Pictures
* Desktop
* Documents
* Downloads
* Movies
* Music

Even when they appear *inside cloud folders* (Dropbox, etc.).

To support writing to user-selected locations:

* dMPP now uses App Sandbox entitlement:
  **User Selected File → Read/Write**

This enables safe, user-approved writing to:

* Any folder chosen in the open panel
* Any non-TCC-protected folders
* Cloud-synced folders (as long as the folder name isn’t special)

This is now documented permanently so you never have to rediscover it.

---

## **4. Technical Architecture**

### **4.1 Key Swift Components**

| File                             | Responsibility                                                 |
| -------------------------------- | -------------------------------------------------------------- |
| `DMPPImageEditorView.swift`      | UI layout, image loading, navigation, sidecar I/O              |
| `DMPPImageEditorViewModel.swift` | Crop management, metadata binding, tag/people helpers          |
| `Models/*.swift`                 | dMPMS model layer (RectNormalized, VirtualCrop, DmpmsMetadata) |
| `dMagy_Picture_PrepApp.swift`    | Application entry point                                        |
| `Resources/*`                    | Default images or helper assets                                |

---

### **4.2 Data Flow Overview**

```
Choose Folder → Scan directory → Build list of images
           ↓                         ↓
    loadImage(index)            Supported extensions
           ↓
  Attempt to load sidecar
    if exists → decode
    else → default metadata
           ↓
Bind metadata + crops to ViewModel
           ↓
Edit fields + crops in UI
           ↓
On image change or folder change:
    saveCurrentMetadata()
           ↓
Writes <filename>.<ext>.dmpms.json
```

This flow is now stable and verified.

---

### **4.3 Why Sidecars Are Core to dMPP**

Sidecars are:

* Non-destructive
* Compatible with cloud-syncing
* Human-readable
* Versionable
* Extensible
* Separate from the original image
* Lightweight enough to process in batches

This was a central design decision from the beginning of the project.

---

## **5. Known Limitations (as of CTX2)**

* Crop overlays are not yet interactive (drag/resize not implemented)
* No “has metadata” indicator in UI
* No batch processing or “skip images with sidecars”
* No history or undo system yet
* No visual preview of cropped output
* No keyboard-driven workflow
* dMPMS `history` field not yet populated

These are feature opportunities, not blockers.

---

## **6. Roadmap (Short-Term)**

### **6.1 High Priority**

* Interactive crop overlays
* Per-image metadata status (New / Existing)
* Auto-advance option after save

### **6.2 Medium**

* Batch skip existing metadata
* Duplicate current settings to next image
* Batch-create default crops
* dMPMS `history[]` write API

### **6.3 Longer-Term**

* dMPS integration (crop choice per display)
* Export tools (cropped previews, thumbnails)
* Keyboard shortcut workflow ("Editor Mode")
* Potential Swift Package for shared metadata models
* Image quality checks (noise, sharpness detection)

---

## **7. Version Tracking**

This document uses the version tag:

```
dMPP-2025-11-22-CTX2
```

Future revisions should use:

```
dMPP-YYYY-MM-DD-CTX#
```

or feature-specific variants:

```
dMPP-2026-01-10-CTX3-cropEditor
dMPP-2026-02-18-CTX4-batchOps
dMPP-2026-03-02-CTX5-statusUI
```

---

## **8. Author Notes**

This file serves as the authoritative record for:

* Architectural decisions
* Workflow definitions
* Constraints encountered (sandboxing, metadata rules, etc.)
* Progress milestones

Updating this document regularly ensures future development remains clear and intentional rather than reactive.

---

## **End of dMPP-Context.md**

