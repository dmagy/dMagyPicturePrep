
This document mirrors the structure and clarity of your existing dMPS documentation and anchors everything we’ve built so far.

---

# dMPP-Context v1.md

**dMagy Picture Prep — Application Context & Architecture Overview**
**Version:** dMPP-2025-11-21-CTX1

---

## **1. Purpose of dMagy Picture Prep (dMPP)**

dMPP is a companion macOS utility designed to prepare personal and archival photographs for advanced display workflows. It streamlines the process of:

* Assigning rich metadata to images according to the **dMagy Photo Metadata Standard (dMPMS)**
* Creating and managing **virtual crops** for different display targets
* Walking through folders of images efficiently
* Saving edits as **sidecar JSON files** that can be consumed by other tools, including dMagy Picture Show (dMPS)

Where dMPS is the *viewer*, dMPP is the *preparator*.

---

## **2. Relationship to dMPMS and dMPS**

### **dMPP ↔ dMPMS**

dMPP is the first application to fully implement dMPMS.
Responsibilities:

* Reading dMPMS sidecar files
* Writing new or updated sidecars
* Ensuring consistency with the evolving metadata standard

### **dMPP ↔ dMPS**

dMPP prepares images; dMPS presents them.
The two apps remain **decoupled** and communicate only through dMPMS sidecar files.

---

## **3. Current Features (What’s Built Now)**

**As of dMPP-2025-11-21-CTX1, the following major features are implemented:**

---

### **3.1 Folder Selection & Navigation**

* Uses `NSOpenPanel` to allow the user to select any folder accessible to the application.
* Scans the folder for supported image types:
  `jpg, jpeg, png, heic, tif, tiff, webp`
* Builds an ordered list of images and presents them in the UI.
* Supports:

  * **Next Image**
  * **Previous Image**

---

### **3.2 Image Display & Metadata Binding**

* Displays a large preview of the selected image (`NSImage`).
* Embeds an editable metadata form:

  * `title`
  * `description`
  * `dateTaken` (supports full → partial formats)
  * `tags`
  * `people`

All fields live-bind to the underlying `DmpmsMetadata` model.

---

### **3.3 Virtual Crops System**

Each image loads with:

* **Two default crops:**

  * `Landscape 16:9`
  * `Portrait 8x10`

User can:

* Add **preset crops** (16:9, 8×10, 1:1)
* Add a new 16:9 crop
* Duplicate the selected crop
* Delete the selected crop

Crops are represented using:
`RectNormalized(x, y, width, height)`
where all values are normalized (0–1).

---

### **3.4 dMPMS Sidecar Read/Write**

For each image, dMPP looks for:

```
<filename>.<imageExtension>.dmpms.json
```

On **load**:

* If the sidecar exists → metadata is loaded and bound
* If not → default metadata is created

On **navigation** (Next/Previous/folder switch):

* dMPP saves the current metadata back to a new or updated sidecar
* Uses `JSONEncoder` with `.prettyPrinted` & `.sortedKeys`
* Writes using atomic file replacement

This ensures dMPP is **stateful across sessions**, and metadata never gets lost.

---

### **3.5 Sandbox-Safe Save Locations**

Because macOS protects folders named:

* Pictures
* Documents
* Desktop
* Downloads
* Movies
* Music

…dMPP correctly requires:

* App Sandbox entitlement: **User Selected File → Read/Write**
* User-selected folders that are **not TCC-protected** or named like them

This behavior is documented here so future you never has to rediscover it.

---

## **4. Technical Architecture**

### **4.1 Key Swift Components**

| File                             | Responsibility                                                 |
| -------------------------------- | -------------------------------------------------------------- |
| `DMPPImageEditorView.swift`      | UI, navigation, folder loading, sidecar I/O                    |
| `DMPPImageEditorViewModel.swift` | Holds metadata & crops; crop management logic                  |
| `Models/*.swift`                 | dMPMS model types (RectNormalized, VirtualCrop, DmpmsMetadata) |
| `Resources/*`                    | Bundled assets                                                 |
| `dMagy_Picture_PrepApp.swift`    | App entry point                                                |

---

### **4.2 Data Flow Overview**

```
Folder Picker → Folder Scan → Image List
        ↓               ↓
   loadImage()      Supported extensions
        ↓
Load sidecar (if exists) or defaults
        ↓
Bind fields + crop editor to ViewModel
        ↓
User edits (metadata/crops)
        ↓
On navigation or folder change:
saveCurrentMetadata()
        ↓
<filename>.<ext>.dmpms.json written
```

---

### **4.3 Why Sidecars?**

Advantages:

* Non-destructive
* Works with cloud-synced folders (Dropbox, iCloud Drive)
* Protects original image files
* Easy for other tools to parse
* Naturally extensible for future fields

This design was intentional from the earliest stages of dMPP.

---

## **5. Known Limitations (as of this version)**

* Crop overlay cannot yet be dragged or resized interactively
* Status indicators for “has sidecar” are not yet shown
* No batch operations (skip existing, mark complete, etc.)
* Sandbox restrictions mean certain folders require entitlements
* No history tracking or undo/redo UI
* No preview of actual cropped output yet

These items will be tackled incrementally.

---

## **6. Roadmap (Short-Term)**

### **6.1 High Priority**

* Crop overlay drag/resize interaction
* Per-image status indicator (“metadata exists” vs “new”)
* Auto-advance mode

### **6.2 Medium**

* Batch skip images with sidecars
* Batch apply or clear crops
* “Duplicate settings to next image”

### **6.3 Long-Term**

* Full integration with dMPS (crop selection + display filtering)
* Exporters (flattened crops, preview JPEGs)
* Keyboard-only workflow
* Plugin hooks for third-party tools

---

## **7. Version Tracking**

This document uses the version tag:

```
dMPP-2025-11-21-CTX1
```

Future revisions should follow:

```
dMPP-YYYY-MM-DD-CTX#
```

…or more specific tags like:

```
dMPP-2026-01-10-CTX2-sidecar
dMPP-2026-02-04-CTX3-cropEditor
```

---

## **8. Author Notes**

This file is not just documentation — it is your internal product guide.
As the app evolves, this document should:

* Track architectural decisions
* Describe workflows
* Capture constraints or entitlements
* Explain how components work together

Keep it short, structured, and updated as each major feature lands.

---

## **End of dMPP-Context.md**


