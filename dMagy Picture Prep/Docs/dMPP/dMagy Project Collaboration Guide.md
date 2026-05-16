# dMagy Project Collaboration Guide

**Purpose:** Shared working agreement for dMagy app projects, including dMagy Picture Prep (dMPP), dMagy Picture Show (dMPS), and future dMagy tools.

This guide explains **how Dan and AI coding assistants work together**. It is not an app architecture document and it is not a backlog. Each app should still have its own context and backlog documents.

Default mindset:

- **Clarity over clever**
- **Replace over splice**
- **Small steps, clean rollback**
- **Keep Dan moving**

---

## 1. Document Roles

Use this guide as the shared collaboration rulebook across dMagy projects.

Recommended project docs:

```text
dMagy Project Collaboration Guide.md = how we work
<App>-Context-v##.md = what the app is and what is true now
<App>-Backlog.md = what we might do next, watch, defer, or revisit
<App>-AI-Collaboration.md or Codex-Agent-Brief.md = how an AI agent should use the docs
```

Only the latest numbered app context file should be treated as current. Older context files are historical and should not be used as active guidance unless specifically referenced.

---

## 2. How We Communicate

### Dan is the design owner

Dan describes:

- what he sees
- what he wants
- what feels wrong
- what Xcode reports
- what behavior should happen

The assistant should translate that into:

- likely cause
- proposed approach
- exact files or sections involved
- safe next step
- test plan

Dan should not have to become the compiler, the linker, or the keeper of sixteen interacting implementation details.

### Keep explanations scannable

Prefer:

- short sections
- numbered steps
- checklists
- exact paste targets
- clear “what to test next” instructions

Avoid long theory unless Dan asks for it.

### Minimize clarifying questions

Ask a question when it materially improves correctness or prevents rework.

Otherwise:

- proceed with a reasonable assumption
- state the assumption plainly
- keep the task moving

---

## 3. Code Change Delivery

### Default: replace, do not splice

Avoid surgical snippets that require Dan to weave code into the right place by hand.

Preferred delivery order:

1. Full-file paste-over when practical.
2. Full `struct`, `class`, or `extension` replacement when full-file paste-over is too large.
3. Function-level replacement when the target is obvious and safe.
4. Small line edits only when unavoidable.

### Every code change needs exact paste targets

For each step, include:

- file path
- replace entire file, or exact `struct` / `class` / function name
- expected outcome
- what to test next

Example:

```text
1. Paste target: dMPP/Source/Stores/DMPPArchiveStore.swift — replace entire file.
2. Build.
3. Test: select Picture Library Folder, quit, relaunch, confirm portable folders exist.
```

### Steps should be numbered

Dan usually scans for steps first. Put the work plan where it is easy to follow.

---

## 4. Multi-File Work: Proposal First

When a change appears likely to touch more than one file, start with a proposal before writing code.

Proposal format:

1. **Goal**
2. **Approach**
3. **N files affected**
4. **Risks**
5. **Rollback plan** — only when the change is refactor-risky

Then proceed only after the approach is clear.

When code is delivered, use this order:

1. Proposal recap
2. “N files affected” callout
3. Full-file or section paste-over for File 1
4. Full-file or section paste-over for File 2
5. Test checklist
6. Remaining steps, if any

---

## 5. Scope Discipline

Do not quietly expand a task into adjacent cleanup, redesign, or refactoring.

If a related issue is discovered:

- mention it
- decide whether it belongs in the current task
- otherwise add it to the backlog

Avoid bundling unrelated fixes into the same change. A small fix that stays small is a feature, not a failure of ambition.

---

## 6. Architecture Stability

Do not move ownership between views, stores, models, services, or app entry points unless the task explicitly requires it.

Architecture changes require:

1. short proposal
2. affected-file count
3. risk notes
4. rollback plan
5. checkpoint before code moves

For app projects, prefer stable patterns:

- app-owned stores
- dependency injection over global singletons
- clear data flow
- model/store logic outside large views when practical
- UI views that remain understandable and navigable

---

## 7. File Size and Maintainability

We watch for files that become too large to understand, navigate, or safely edit.

Large files are not automatically a problem. A long but stable file can be better than a premature refactor that scatters behavior across the project.

A file becomes a problem when:

- changes require too much scrolling and searching
- unrelated responsibilities are mixed together
- small fixes risk breaking distant behavior
- AI-assisted edits become hard to review
- the file is difficult to summarize in plain English
- repeated work in the file causes confusion or rework

When a file starts feeling too large, do not immediately refactor. First decide whether the size is causing real friction.

If refactoring is justified:

- split by clear responsibility, not arbitrary line count
- move one section at a time
- preserve behavior first
- use `// MARK:` anchors before, during, and after extraction
- create a Git checkpoint before moving code
- test after each extraction
- stop after a useful, stable increment

---

## 8. File Organization and In-Code Navigation

### `// MARK:` is the shared map

Use `// MARK:` headings consistently so Dan can navigate larger files.

When adding or reorganizing code:

- preserve existing anchors
- do not rename anchors casually
- add new anchors when they improve navigation
- refer to anchors when explaining where logic lives

### Add plain-English file headers gradually

Do not stop the project to document every file at once.

When touching a file, consider adding or improving a short header:

```text
Purpose:
Dependencies & Effects:
Data Flow:
Section Index:
```

“Data Flow” means:

- where data comes from
- how it is transformed
- where it goes next
- what gets persisted or displayed

---

## 9. Risk and Rollback

### Git safety steps are for risky changes

“Risky” means:

- refactors
- moving code between files
- changing ownership of behavior
- changing persistence formats
- changing save/load behavior
- touching several interdependent files

For risky changes, include:

- checkpoint suggestion
- simple rollback instruction
- test plan before continuing

For small bug fixes, compile fixes, copy updates, or obvious UI text changes, keep Git ceremony light.

### Suggested checkpoint language

```text
cp-YYYY-MM-DD-## — short description
```

Example:

```text
cp-2026-05-15-01 — before extracting People editor section
```

---

## 10. AI / Agent Output Review

AI-generated code is never accepted just because it builds.

Before committing or merging:

- review what files changed
- confirm the change matches the requested goal
- check for unrelated edits
- run the relevant user workflow
- confirm no privacy, sandbox, network, or persistence behavior changed unexpectedly
- commit only after behavior is verified

The assistant should report:

1. files changed
2. what changed
3. why it changed
4. how to test
5. any follow-up concerns

---

## 11. Explainability Standard

Every meaningful code change should be explainable in plain English.

A good explanation answers:

- what changed
- why it changed
- what behavior should be different
- how to test it
- how to undo it if needed

If we cannot explain the change clearly, it is not ready.

---

## 12. Codex / Coding Agent Boundaries

When using Codex or another coding agent, give the agent stricter boundaries than a normal chat.

Recommended agent rules:

- read the collaboration guide first
- read the app context file before changing code
- read the backlog only for task context, not permission to do everything
- keep changes small and commit-sized
- do not refactor unless explicitly asked
- do not add dependencies without approval
- do not add network, analytics, telemetry, cloud sync, accounts, or server behavior unless explicitly requested
- do not change signing, entitlements, bundle identifiers, privacy behavior, or App Store configuration unless explicitly requested
- do not move code between files without a proposal
- state files likely affected before coding
- report changed files and test steps after coding

For major work, prefer this branch pattern:

```text
main = stable released app
feature/<app>-v2 = long-running redesign branch
codex/<task-name> = short task branch merged into feature branch after review
```

Example:

```text
main
feature/dmps-v2
codex/dmps-v2-display-profiles
codex/dmps-v2-dmpms-reader
```

---

## 13. Backlog Discipline

The backlog is a living thinking surface.

It can contain:

- ideas
- deferred work
- watch-list items
- post-launch observations
- possible future versions
- things intentionally declined for now

The backlog does not need to be perfectly clean all the time, but it should be periodically reorganized so useful ideas do not disappear.

Recommended sections:

```text
Now / Next
Version 2.0 Candidates
Later / Maybe
Watch List
Completed Recently
Parking Lot / Deferred
```

The backlog is not the source of current architecture truth. When an idea becomes a decision or implemented behavior, update the app context file.

---

## 14. Definition of Done

A change is done when:

- the project builds, or remaining build issues are clearly identified
- the behavior matches the agreed goal
- Dan can locate key logic using file names, function names, and `// MARK:` anchors
- the relevant workflow has been tested
- no unrelated changes were introduced
- rollback guidance exists if it was a refactor

For release-readiness work, also confirm:

- privacy behavior still matches public claims
- sandbox / entitlements still match app needs
- user-facing messages are understandable to a normal user
- original user files are not silently damaged or overwritten

---

## 15. How Dan Should Ask

### Build error

```text
Here is the Xcode error and file path. Please propose the fix, and if it touches multiple files tell me how many up front.
```

### Behavior issue

```text
In the app, when I do X I expect Y but I see Z. Here is where I think it is happening, if known.
```

### Refactor or redesign

```text
I want to move responsibility from A to B. Start with a structured proposal and the number of files affected.
```

### Codex task

```text
Read the project collaboration guide and the app context file. Propose the smallest safe implementation plan first. Do not edit code until the affected files and test plan are clear.
```

---

## 16. Default Expectations

We keep changes understandable and reversible.

We prefer clear structure over clever code.

We protect user data, user trust, and Dan’s ability to understand the project later.

We keep the current app context accurate enough that a future session, a future coding agent, or future Dan can return after a long break and quickly understand what matters.

