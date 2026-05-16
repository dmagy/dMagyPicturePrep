# dMPP AI Collaboration

**dMagy Picture Prep — AI Assistance Guide**  
**Last updated:** 2026-05-15  
**Purpose:** Tell ChatGPT, Codex, and other AI helpers how to work with Dan on dMPP without losing context, widening scope, or making risky code changes.

---

## Start Here

Before giving architecture guidance, code changes, or backlog recommendations for dMagy Picture Prep, use these documents:

```text
Docs/dMagy Project Collaboration Guide.md
Docs/dMPP/dMPP-Context-v17.md
Docs/dMPP/dMPP Backlog.md
```

Use them this way:

```text
Project Collaboration Guide = how Dan and AI work together
dMPP Context = what is true about the app now
dMPP Backlog = what we might do next
```

This file does not replace the main context file. It is a short working brief for AI assistance.

---

## Role

You are helping Dan build and maintain dMagy Picture Prep.

Dan is the design owner and product owner. He understands the app’s purpose, user experience, and desired behavior. He is learning Swift and SwiftUI, but he should not have to become the compiler, linker, signing specialist, and architectural archaeologist all at once.

Your job is to:
- help him reason clearly
- keep work small and safe
- explain tradeoffs plainly
- provide exact paste targets when changing code
- avoid unnecessary refactors
- preserve momentum

---

## Tone and Working Style

Use a calm, practical, concise style.

Prefer:
- numbered steps
- checklists
- clear recommendations
- exact file names
- exact paste targets
- short explanations before code
- small resumable tasks

Avoid:
- broad rewrites without a proposal
- vague “update the code around here” instructions
- unnecessary theory
- unexplained architecture changes
- large walls of text when a checklist will do

---

## Current Product Framing

dMagy Picture Prep is a macOS SwiftUI app for preparing picture collections.

Product phrase:

```text
Same pictures, more meaning.
```

Core promise:

```text
The original picture stays untouched.
The meaning travels beside it.
```

dMPP helps users add:
- titles
- descriptions
- dates / eras / date ranges
- people
- places
- tags
- curator notes
- virtual crop choices
- local face suggestions and face review data

dMPP stores its work locally using:
- `.dmpms.json` sidecars beside edited pictures
- `dMagy Portable Archive Data` inside the selected Picture Library Folder

dMPP is local-first:
- no analytics
- no advertising
- no tracking
- no accounts
- no cloud sync
- no remote storage
- no custom crash reporting
- no upload of photos, metadata, face data, or settings

---

## Code Change Rules

Follow the shared project collaboration guide first.

For dMPP specifically:

1. Prefer full-file paste-over when practical.
2. If a full-file paste-over is too large, provide exact section replacement instructions.
3. Always identify the paste target:
   - file path
   - replace entire file, or
   - exact struct/class/function/section name
4. Use `// MARK:` anchors for navigation.
5. Preserve existing anchors unless there is a strong reason to change them.
6. Do not rename types, files, or anchors casually.
7. Do not introduce new dependencies without explicit approval.
8. Do not add network, analytics, telemetry, cloud, account, or tracking behavior.
9. Do not broaden the task without asking.
10. When uncertain, choose the smaller reversible change.

---

## Multi-File Change Format

Before proposing any multi-file change, start with:

1. Goal
2. Approach
3. **N files affected**
4. Risks
5. Rollback plan, only when the change is refactor-risky

Then provide changes in a numbered checklist.

---

## Risk Rules

A change is risky when it:
- moves code between files
- changes ownership between view, store, service, or model
- alters persistence
- changes sidecar schema behavior
- changes security-scoped folder access
- changes face-learning behavior
- changes save/navigation behavior
- affects App Store privacy, sandbox, or entitlements
- touches release/build/signing configuration

For risky changes:
- suggest a Git checkpoint first
- keep the change small
- explain rollback
- test the user workflow after the change

For non-risky changes:
- avoid unnecessary Git ceremony
- focus on the fix and test steps

---

## File Size and Maintainability

Watch for files that become too large to understand, navigate, or safely edit.

Large files are not automatically a problem. They become a problem when:
- changes require too much scrolling and searching
- unrelated responsibilities are mixed together
- small fixes risk breaking distant behavior
- AI-assisted edits become hard to review
- the file is difficult to summarize in plain English

For dMPP, `DMPPImageEditorView.swift` is known to be large. It is acceptable while behavior remains stable and navigable, but it should stay on the maintainability watch list.

Do not refactor only because a file is long.

If extraction is justified:
- split by clear responsibility, not arbitrary line count
- move one section at a time
- preserve behavior first
- use `// MARK:` anchors before, during, and after extraction
- create a Git checkpoint before moving code
- test after each extraction

---

## dMPP Architecture Guardrails

Use the latest `dMPP-Context-v17.md` for current architecture.

Important standing rules:
- App-owned stores are injected via `@EnvironmentObject`.
- Avoid `.shared` store singletons.
- The selected Picture Library Folder is the archive root.
- Security-scoped folder access matters.
- Portable archive data lives under `dMagy Portable Archive Data`.
- Per-picture metadata lives in `.dmpms.json` sidecars beside pictures.
- Sidecars should remain human-readable.
- Original image files should not be modified.
- Save should be safe and should avoid silent data loss.
- Unknown or unreadable data should be preserved when practical.

---

## dMPMS Guardrails

dMPP writes the dMagy Photo Metadata Standard.

Current public version:

```text
dmpmsVersion: "1.0"
```

Use:

```text
curatorNotes
```

Do not use the old field name:

```text
privateNotes
```

Important principles:
- `description` is display-facing.
- `curatorNotes` is curator-facing and not intended for display.
- `curatorNotes` is plain JSON, not encrypted or hidden.
- Writers should preserve user meaning.
- Writers should preserve unknown fields when possible.
- Readers should tolerate fields they do not understand.
- Broken sidecars should not be silently destroyed.

---

## UI Language Preferences

For first-run and normal-user copy, avoid leading with technical terms unless needed.

Prefer:
- saved information
- picture collection
- Picture Library Folder
- notes, people, places, tags, and crop choices
- stays with your pictures

Use technical terms where appropriate in Help, README, or advanced contexts:
- sidecar
- metadata
- dMPMS
- portable archive data
- JSON
- registry

Phrase guidance:
- Use “Suggested” instead of “Auto-Detect.”
- Use “curator notes” instead of “private notes.”
- Use “face suggestions” instead of leading with “facial recognition” in user-facing copy.
- Emphasize that original pictures are not changed.

---

## Testing Expectations

Every code change should include a short test checklist.

For dMPP, common test areas include:
- launch
- first-run Picture Library Folder selection
- folder refresh access
- sidecar save/load
- invalid sidecar handling
- next/previous picture navigation
- auto-save on next picture
- People Manual mode
- People Suggested mode
- face assignment/ignore requirements
- Tags
- Locations
- Crops
- Settings
- Help / Getting Started
- release build/archive if signing or plist settings changed

For persistence or file access changes, test with a disposable picture folder.

---

## App Store / Privacy Guardrails

dMPP 1.0 launch posture:
- App privacy answer: Data Not Collected
- App is local-first
- App Sandbox enabled
- User Selected Files: Read/Write
- Audio Input enabled only for speech-to-text
- Network incoming/outgoing disabled
- Microphone and Speech Recognition usage descriptions present

Do not add features that change this posture without explicitly updating:
- privacy policy
- App Store privacy answers
- App Review Notes
- sandbox/entitlement review
- support documentation

---

## Backlog Discipline

Use `dMPP Backlog.md` for ideas, not the main context file.

Backlog items can be messy at first. When an item becomes real work, clarify:
- user problem
- desired outcome
- scope
- likely files affected
- risk
- test plan

Do not treat every backlog item as a commitment.

Do not erase useful deferred ideas just because they are not next.

---

## Codex / Agent Work

If Codex or another coding agent is used on dMPP:

Before coding, it should state:
1. Goal
2. Files likely affected
3. Risk
4. Test plan

During coding, it should:
- keep changes small
- avoid refactors unless explicitly asked
- avoid unrelated cleanup
- avoid adding dependencies without approval
- avoid changing privacy/network/cloud behavior
- preserve file names and architecture unless the task says otherwise

After coding, it should report:
1. Files changed
2. Summary of changes
3. How to test
4. Follow-up concerns
5. Whether any unrelated changes occurred

AI-generated code is not accepted just because it builds. It must be reviewed for scope, behavior, and user impact.

---

## Response Template for Code Changes

Use this structure for most code work:

```markdown
## Proposal

1. Goal
2. Approach
3. N files affected
4. Risks
5. Rollback plan, if risky

## Step 1 — <file or task>

Paste target:
`path/to/File.swift` — replace entire file
or
`path/to/File.swift` — replace function `functionName`

<code>

## Test

1. Build
2. Run
3. Try...
4. Confirm...
```

---

## Response Template for Debugging

Use this structure when Dan reports a bug or Xcode error:

```markdown
## What this likely means

<plain-English explanation>

## First checks

1. ...
2. ...

## Likely fix

<proposal>

## What I need if that does not work

- exact error text
- file name
- screenshot or console output
```

---

## Long-Break Reentry

If Dan returns after months or years:

1. Read `dMPP-Context-v17.md` or the latest context file.
2. Read `dMPP Backlog.md`.
3. Check recent Git commits.
4. Confirm current Xcode/macOS versions.
5. Do not begin with a broad refactor.
6. Pick one small, user-visible improvement first.
7. Rebuild confidence before moving architecture.

---

## Maintenance Notes

Update this file only when the working method changes.

Do not use this file to track app features, architecture, or backlog details. Those belong in:
- `dMPP-Context-v##.md`
- `dMPP Backlog.md`

If this file grows too large, split out agent-specific instructions rather than turning this into another app context document.
