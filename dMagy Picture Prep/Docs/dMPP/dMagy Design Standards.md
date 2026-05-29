# dMagy Design Standards

**Shared design direction for dMagy apps**  
**Last updated:** 2026-05-15  
**Purpose:** Help dMagy apps feel like parts of the same thoughtful, local-first suite while still allowing each app to serve a different role.

---

## 1. Purpose

dMagy apps should feel related.

They do not need identical screens or identical workflows, but they should share a recognizable product philosophy:

- practical
- calm
- local-first
- user-controlled
- clear without being childish
- powerful without feeling fussy
- respectful of personal pictures, memories, and archives

This document describes shared standards for language, user experience, visual patterns, privacy posture, and future app relationships.

Use this document alongside:

```text
dMagy Project Collaboration Guide.md
```

For individual app architecture and backlog, use each app’s own context and backlog files.

---

## 2. Brand Promise

dMagy apps help people preserve, prepare, understand, display, and explore meaningful picture collections.

The apps should help users answer questions like:

- What is this picture?
- Who is in it?
- Where and when was it taken?
- Why does it matter?
- How should it be shown?
- How can this meaning stay with the collection over time?

The broader dMagy promise:

```text
Your pictures and memories should stay understandable, useful, and yours.
```

For dMagy Picture Prep:

```text
Same pictures, more meaning.
```

Core dMPP idea:

```text
The original picture stays untouched.
The meaning travels beside it.
```

---

## 3. Suite Philosophy

## 3.1 Local-First, Not Necessarily Local-Only

dMagy apps should prefer local, user-controlled files and avoid unnecessary accounts, hidden sync, cloud services, analytics, tracking, or data collection.

However, future dMagy apps may use sync when sync is essential to the product experience.

Example:
- A future Heritage app may need to sync between a person’s Mac and iPhone.
- A future Apple TV / tvOS display experience may be considered later, but not before dMPS v3 at the earliest.

When sync is used, it must be:
- explicit
- user-understandable
- user-controlled where practical
- clearly described in the app
- clearly described in support materials
- reflected in the privacy policy
- reflected in App Store privacy answers
- designed to preserve exportability and long-term access wherever practical

Default principle:

```text
Local-first means the user understands and controls where their data lives.
```

It does **not** mean every dMagy app must be permanently offline forever.

---

## 3.2 Original Files Should Be Safe

Whenever possible, dMagy apps should avoid modifying original photo files.

Preferred patterns:
- sidecars
- local support folders
- non-destructive crop/view instructions
- separate export actions when users intentionally want output files

If an app ever modifies or creates new files, the user should understand:
- what is being changed or created
- where it is being stored
- whether original files are affected
- how to back up or remove the app-created data

---

## 3.3 Prepare, Display, Explore

Current and future dMagy apps should have clear roles.

### dMagy Picture Prep — dMPP

Role:

```text
Prepare picture collections.
```

dMPP adds meaning:
- titles
- descriptions
- dates
- people
- places
- tags
- curator notes
- crop choices
- local face suggestions

dMPP writes dMPMS sidecars and portable archive data.

### dMagy Picture Show — dMPS

Role:

```text
Display picture collections.
```

dMPS shows pictures cleanly from folders users choose. dMPS v2 should become smarter by reading dMPMS sidecars and using virtual crops, display profiles, and metadata-aware filtering.

dMPS should not become a metadata editor.

### Future Heritage App

Role:

```text
Explore and preserve family history.
```

A future Heritage app may support Mac/iPhone sync because that product likely needs a person’s family history work to follow them across devices.

Sync should be designed intentionally and transparently.

### Future Apple TV / tvOS Support

Apple TV support may be explored for dMPS or a future companion app, but it should not drive dMPS v2.

Current direction:
- dMPS v2 should focus on Mac-based display profiles, dMPMS reading, virtual crop support, and metadata-aware filtering.
- Apple TV / tvOS support is a future exploration item for **dMPS v3 or later**.
- Any Apple TV sync or companion behavior must be explicit, user-controlled, and privacy-reviewed.

---

## 4. Voice and Tone

dMagy apps should sound like a knowledgeable guide, not a corporate platform and not a technical manual.

Use a tone that is:
- clear
- calm
- practical
- human
- respectful
- lightly warm
- confident without overpromising

Avoid:
- generic corporate filler
- alarmist warnings
- unnecessary jargon
- cute wording that hides important behavior
- technical detail too early in onboarding

Good dMagy copy should help a user feel:

```text
I understand what this app is doing.
I know where my files are.
I can undo or recover if needed.
My pictures are safe.
```

---

## 5. Shared Language

## 5.1 Preferred Everyday Terms

Use these in first-run screens, common UI, and App Store copy:

- picture collection
- Picture Library Folder
- saved information
- notes
- people
- places
- tags
- crop choices
- local
- stays with your pictures
- original pictures are not changed
- same pictures, more meaning

## 5.2 Technical Terms for Help / Advanced Contexts

Use these when the user has already been introduced to the concept, or in Help / README / advanced sections:

- metadata
- sidecar
- `.dmpms.json`
- dMPMS
- portable archive data
- registry
- JSON
- security-scoped folder access
- virtual crops

## 5.3 Terms to Avoid or Use Carefully

Avoid:
- “private notes” when the correct term is `curatorNotes`
- “private” when data is merely local/plain text
- “Auto-Detect” when the UI says “Suggested”
- “facial recognition” as the first user-facing label when “face suggestions” is clearer
- “cloud” unless sync/cloud behavior actually exists
- “archive” too early for non-technical onboarding unless context makes it clear

Use carefully:
- “metadata” — accurate but abstract
- “sidecar” — important but unfamiliar
- “registry” — useful to developers, rarely useful to first-time users
- “sync” — only when the behavior truly syncs and users know where

---

## 6. Visual Design Principles

dMagy apps should feel macOS-native, clean, and practical.

Priorities:
- clarity over decoration
- strong spacing
- readable hierarchy
- calm controls
- consistent section layout
- progressive disclosure for advanced details
- visible recovery paths
- minimal visual noise during picture display

Avoid:
- crowded toolbars
- hidden critical actions
- excessive badges
- color-only status
- overusing modal alerts
- making advanced file details look like required reading

---

## 7. Shared UI Patterns

## 7.1 First-Run / Setup

First-run screens should answer:

1. What is the app asking me to choose?
2. Why does it need access?
3. What will it create or change?
4. Are my original pictures safe?
5. What should I do next?

Example dMPP style:

```text
Choose the main folder for the picture collection you plan to prepare. dMPP will save its notes, people, places, tags, and crop choices inside that folder so everything stays together.
```

## 7.2 Settings

Settings should:
- use clear sections
- show important paths when relevant
- hide advanced file details behind disclosure controls
- include “Show in Finder” where useful
- explain consequences of changing roots/folders/settings

Advanced linked-file details should be helpful, not intimidating.

## 7.3 Help and Info Popovers

Use short help popovers for immediate context.

A popover should answer:
- what this field/section is for
- when to use it
- what happens if the user changes it

Longer explanations belong in Help.

Preferred pattern:
- short popover
- optional “Open full Help topic…” link later

## 7.4 Error and Recovery Messages

Error messages should follow this pattern:

1. What happened.
2. Whether original pictures/data are safe.
3. What the user can do next.

Example:

```text
dMPP found saved information for this picture, but could not read it. Your original picture was not changed. If you save, dMPP will keep a backup of the unreadable file and create a new saved information file.
```

Avoid leading with raw technical errors unless they are in an advanced detail area.

## 7.5 Destructive or Risky Actions

Risky actions should be clear and recoverable where practical.

Use confirmation when:
- data will be deleted
- user-created information may be overwritten
- a selected folder may create a new support structure
- a setting could make existing work appear missing

Do not over-confirm routine actions.

---

## 8. App Relationship Standards

## 8.1 dMPP and dMPS

dMPP prepares.  
dMPS displays.

This distinction matters.

dMPP can include detailed editing, review, repair, and metadata tools.

dMPS should stay focused on:
- selecting what to show
- choosing where to show it
- presenting pictures cleanly
- using prepared metadata to make display smarter

dMPS should not require dMPP metadata for basic slideshows.

dMPS may use dMPP/dMPMS data to enhance:
- filtering
- display crops
- captions
- people/location/date-aware slideshows
- display profiles

## 8.2 Future Heritage App

A Heritage app may have a different data model and may support sync.

However, it should still follow dMagy standards:
- user control
- transparency
- exportability where practical
- respectful handling of family data
- clear privacy explanations
- no hidden tracking or monetization of personal history

## 8.3 Future Apple TV / tvOS Direction

Apple TV support is a future exploration item for dMPS v3 or later.

Possible future models:
- Mac-controlled slideshow displayed over AirPlay
- lightweight tvOS companion display app
- full tvOS app with synced profiles or selected picture sets

Do not design dMPS v2 around tvOS.

For v2, focus on:
- dMPMS sidecar reading
- virtual crop display
- metadata-aware filtering
- display profiles
- per-display memory on Mac
- multi-display refinement on macOS

---

## 9. Privacy and Trust Standards

A dMagy app should never surprise users about data.

For each app, be clear about:
- what files it reads
- what files it writes
- whether original files are modified
- whether data leaves the device
- whether sync is used
- whether accounts are required
- what data is collected, if any
- how to remove or back up app-created data

Default posture:
- no analytics unless explicitly justified and disclosed
- no tracking
- no advertising SDKs
- no hidden upload
- no unnecessary account requirement
- no network behavior unless the app’s purpose requires it

If an app’s behavior changes, update:
- privacy policy
- support page
- App Store privacy answers
- App Review Notes
- in-app explanations where needed

---

## 10. Accessibility and Inclusion

Do not claim verified accessibility support until it has been tested against common tasks.

Design should still aim for:
- readable text
- sufficient contrast
- keyboard-friendly interaction
- VoiceOver labels for custom controls
- not relying on color alone
- clear focus states
- reduced motion where relevant
- plain-language messages

For future accessibility declarations, verify:
- onboarding
- settings
- help
- primary workflows
- error recovery
- file/folder selection

---

## 11. App Store and Public Page Standards

Public-facing app copy should emphasize:
- what the app helps the user do
- local-first behavior
- original files remain safe
- no unnecessary account/cloud requirement
- simple workflow
- relationship to the broader dMagy suite when useful

Avoid leading with internal architecture.

Good public copy examples:
- “Same pictures, more meaning.”
- “Prepare your photo collection locally with notes, people, places, tags, and crops—without changing your original pictures.”
- “Use the folders you already have.”
- “Your photos never leave your device.”

---

## 12. Design Review Checklist

Before shipping a meaningful UI or feature change, ask:

1. Does this feel like a dMagy app?
2. Is the user in control?
3. Is it clear where data lives?
4. Are original pictures safe?
5. Is the feature understandable without jargon?
6. Is advanced detail hidden until useful?
7. Does the app explain what to do if something goes wrong?
8. Does this change privacy, sandboxing, or App Store answers?
9. Does this create inconsistency with other dMagy apps?
10. Is this practical, or just clever?

---

## 13. Document Maintenance

Update this document when:
- a new dMagy app starts
- shared terminology changes
- product philosophy changes
- sync/cloud behavior becomes part of an app
- public-facing language changes significantly
- a recurring UI pattern becomes a standard

Do not use this document as an app backlog.

App-specific ideas belong in each app’s backlog.

App-specific architecture belongs in each app’s context file.
