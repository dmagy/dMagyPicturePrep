# dMPP Backlog — Post 1.0 / Version 2.0 Planning

*Last updated: May 2026*

---

## Version 2.0 Theme

**Make dMPP faster, safer, and more useful for working through real photo collections at scale.**

Version 1.0 establishes the foundation: local sidecars, portable archive data, people, locations, tags, crops, face suggestions, help, and launch readiness. Version 2.0 should focus on the next practical leap: better batch work, better repair/recovery, stronger archive insight, and a cleaner editor structure.

---

# Version 2.0 Candidates

## 1. Bulk Operations

**Goal:** Help users apply repeated information without editing every picture one at a time.

Possible work:

* Apply location to selected pictures.
* Apply tags to selected pictures.
* Apply people to selected pictures where appropriate.
* Batch mark pictures as Flagged or Do Not Display.
* Batch clear or replace a location/tag.
* Batch save/update sidecars safely.

Why it matters:

* This is the clearest productivity upgrade for anyone processing a large collection.
* It makes dMPP feel less like “one picture at a time forever,” which is important for real-world adoption.

Suggested priority: **High**

---

## 2. Archive Health / Diagnostics

**Goal:** Give users a clear way to understand whether their picture collection and dMPP data are healthy.

Possible checks:

* Missing or unreadable `.dmpms.json` sidecars.
* Invalid sidecar JSON.
* Missing People / Locations / Tags references.
* Missing or unreadable `dMagy Portable Archive Data`.
* Permission problems with the selected Picture Library Folder.
* Registry files readable/writable:

  * People
  * Locations
  * Tags
  * Crops
  * FaceIndex
  * `_locks`
* Sidecars with unknown tags or missing people references.
* Pictures with missing dates, people, tags, or crops, depending on user-selected goals.

Why it matters:

* The current backlog already notes possible diagnostics for People, Locations, Tags, Crops, FaceIndex, and `_locks`, but defers a full panel unless access issues become frequent. 
* After launch, a health/diagnostics panel becomes one of the best ways to build user trust.

Suggested priority: **High**

---

## 3. Folder Access Recovery Improvements

**Goal:** Make stale macOS / cloud folder permission problems easier for normal users to recover from.

Possible work:

* Detect when dMPP can see the saved Picture Library Folder path but cannot write inside it.
* Show a clear “Refresh Picture Library Folder Access…” message.
* Offer a one-click path to reselect the same folder.
* Avoid misleading messages when the real problem is folder access.
* Add a lightweight access check for portable archive folders.

Suggested user message:

```text
dMPP needs permission to save inside your Picture Library Folder. Choose the folder again to refresh access.
```

Why it matters:

* This came up during failure-state testing.
* The current backlog already identifies this as a watch-list item under Archive Access / Permissions. 

Suggested priority: **High**

---

## 4. Location Manager UX Parity

**Goal:** Bring Locations closer to the polish and clarity of People Settings.

Possible work:

* Improve Locations Settings layout.
* Make saved locations easier to review, edit, and reuse.
* Improve linked-file / advanced information if needed.
* Show clearer confidence when GPS-derived data matched a saved location.
* Consider adding GPS coordinates to saved Locations for better distance-based matching.

Why it matters:

* Locations are already in the near-term backlog. 
* dMPP’s value depends heavily on consistent places, especially for family history and recurring event locations.

Suggested priority: **High / Medium**

---

## 5. Crop System 2.0

**Goal:** Make crops more powerful and more portable.

Possible work:

* Move crop presets fully to portable JSON.
* Improve crop preset editing.
* Add better reusable crop definitions.
* Revisit smarter initial headshot crop placement from detected face boxes.
* Improve crop/export/delete action layout if it still feels visually bolted on.
* Consider crop quality warnings, such as “this crop may be too small for display.”

Why it matters:

* Crop presets are already listed as planned future work. 
* Headshot placement was intentionally deferred because the centered default was acceptable for now. 
* The editor crop action box is also noted as visible polish work. 

Suggested priority: **Medium**

---

## 6. Face Review and Learning Tools

**Goal:** Make face suggestions easier to inspect, repair, and trust over time.

Possible work:

* Per-sample face-learning review instead of only reset-all-for-person.
* Show source photo for learned samples.
* Add a clearer “wrong suggestion” recovery path.
* Continue tuning high-confidence mismatch thresholds after real-world testing.
* Consider better explanation for why a suggestion appeared.

Why it matters:

* The current backlog already identifies per-sample review, source photo review, explainability, and wrong-match handling as future face-recognition improvements. 
* The current reset-person workflow is acceptable for now, but not the end state. 

Suggested priority: **Medium**

---

## 7. Help System Improvements

**Goal:** Make in-app Help easier to search and connect to the current screen.

Possible work:

* Add search to dMPP Help.
* Add “Open full Help topic…” links from section help popovers.
* Improve Markdown rendering for:

  * bold text
  * inline code
  * links
  * nested lists
* Add screenshots once the UI stabilizes.

Why it matters:

* These are already listed as near-term Help items. 
* dMPP has concepts that are clear once explained, but unusual at first: Picture Library Folder, sidecars, portable archive data, curator notes, and local face suggestions.

Suggested priority: **Medium**

---

## 8. Performance and Responsiveness

**Goal:** Make large folders feel faster and smoother.

Possible work:

* Faster folder scanning.
* Thumbnail caching.
* Avoid blocking the main thread during large-folder operations.
* Improve perceived loading state.
* Consider background preloading for adjacent pictures.
* Keep correctness and UI stability ahead of premature optimization.

Why it matters:

* Faster folder scanning and thumbnail caching are already called out in the backlog. 
* Large collections are one of dMPP’s natural use cases.

Suggested priority: **Medium**

---

## 9. Editor Decomposition / Maintainability

**Goal:** Carefully reduce the size and complexity of `DMPPImageEditorView.swift` after launch.

Possible extractions:

* Title / Description / Curator Notes section.
* Tags section.
* Location section.
* People section.
* Crop header/actions.
* File/folder toolbar helpers.
* Save/navigation command handling.

Rules:

* Do not do broad refactors without a clear reason.
* Keep extractions small and reversible.
* Use versioning checkpoints before each extraction.
* Preserve `// MARK:` anchors.

Why it matters:

* The backlog already says the large editor file is a maintainability concern, not a shipping blocker. 
* This should be v2.0 infrastructure work only when it supports real feature work or reduces risk.

Suggested priority: **Medium / Low**

---

## 10. Accessibility Review

**Goal:** Improve support for users relying on macOS accessibility features.

Possible work:

* Test onboarding, Settings, Help, editor fields, crop controls, people assignment, and navigation with VoiceOver.
* Add accessibility labels to custom controls.
* Review Voice Control behavior.
* Review contrast and color-only status indicators.
* Review Dark Mode.
* Revisit App Store accessibility declarations only after verified support.

Why it matters:

* This came up during App Store submission.
* v1.0 should not overclaim accessibility support, but v2.0 can improve it intentionally.

Suggested priority: **Medium / Low**

---

# Watch List

## Face Matching Quality

Current status:

* Suggestion thresholds feel acceptable after real-world batch testing.
* Confidence percentage display feels acceptable.
* Reset-person workflow is acceptable for wrong-match recovery.
* Inline warnings now help users recover from deleted people and high-confidence mismatches. 

Watch for:

* Repeated false positives.
* Users misunderstanding confidence.
* Need for explicit “wrong match” feedback.

---

## Data Integrity

Current status:

* Unknown tags and missing people references have basic handling.
* Orphaned people reference details are preserved in curator notes. 

Watch for:

* Missing location references.
* Broken crop references.
* Face sample references to deleted people.
* Invalid or older draft sidecars.

---

## UI / Layout

Current status:

* Suggested and Manual people modes are closer to the same design system.
* Right-column spacing and scrollbar breathing room remain worth watching.
* Manual row behavior is acceptable for now. 

Watch for:

* Crowded action areas.
* Users missing important controls.
* Sections that need progressive disclosure.

---

# Recently Completed / Version 1.0 Foundation

I would keep this much shorter than the current backlog:

```markdown
## Recently Completed / Version 1.0 Foundation

- Public dMPMS v1.0 standard created and licensed under CC BY 4.0.
- dMPP writes `dmpmsVersion: "1.0"`.
- `privateNotes` renamed to `curatorNotes`.
- Picture Library Folder workflow stabilized.
- `dMagy Portable Archive Data` structure established.
- Sidecar read/write failure handling improved.
- Invalid sidecars now warn users and preserve a backup before replacement.
- Privacy policy, App Store privacy answers, support pages, and App Review notes prepared.
- Sandbox entitlements reviewed.
- Failure-state testing completed for missing folders, deleted images, invalid sidecars, save failures, and portable archive repair.
- Help and Getting Started windows added.
- People, Locations, Tags, Crops, and face suggestion workflows reached v1.0 readiness.
```

---

# My Version 2.0 Recommendation

If I were choosing the actual **2.0 headline**, I would make it:

## **dMPP 2.0 — Bulk Work and Archive Health**

That gives you a version with a clear promise:

1. **Bulk apply tags and locations**
2. **Archive health / diagnostics panel**
3. **Better folder-access recovery**
4. **Location manager polish**
5. **Performance improvements**

That is the version most likely to make users say, “Okay, now I can use this on a real collection.”

I would **not** make 2.0 primarily a face-recognition release. Face improvements matter, but they are more complex, riskier, and harder to explain. Bulk operations plus archive health is practical, understandable, and deeply aligned with what dMPP is becoming.
