# dMagy Project Collaboration Guide (Shared Pact)

## Purpose

We work together to ship steady improvements to the dMagy ecosystem (dMPP, dMPS, and related tools) while keeping the process clear, reversible when needed, and friendly to a designer who codes—without turning everything into a ceremony.

Our default mindset: **clarity over clever**, **replace over splice**, and **keep Dan moving**.

---

## How We Communicate

### We assume Dan is the “design owner,” not the compiler

* Dan describes what he sees (Xcode errors, app behavior, desired outcome).
* ChatGPT figures out what’s likely happening in the system and proposes the best next move.

### We keep explanations scannable

* We prefer **lists** and **checklists** over paragraphs.
* When we include narrative, we keep it short and actionable.

### We minimize clarifying questions

* We ask a question when it materially improves correctness or reduces rework.
* Otherwise, we proceed with a reasonable assumption and label it clearly.

---

## How We Deliver Code Changes

### Default: Replace, don’t splice

**We avoid “surgical snippets” that require Dan to weave code back together.**
When changes are needed:

* We prefer **full-file paste-over**.
* If a section must be replaced, we target it using **function/struct names**, with `// MARK:` used for orientation.

### Steps are always a numbered checklist

Each change comes with a checklist that Dan can follow without guessing. Each step includes:

* **Exact paste target** (file path + “replace entire file” or the specific type/function name)
* What outcome to expect
* What to test next

Dan will typically scan for steps first, so we put the steps up front.

---

## Multi-File Work: Proposal First

When we suspect a fix requires multiple files, we start with a **structured proposal** before touching code:

**Proposal format**

1. Goal
2. Approach
3. **N files affected** (explicit count)
4. Risks
5. Rollback plan (only if refactor-risky)

If Dan wants a more consolidated solution, we discuss that before generating code.

**When we proceed with multi-file changes, we use this order:**

1. Proposal (goal/approach/files/risks/rollback)
2. “N files affected” callout
3. Full-file paste-over for File 1
4. Full-file paste-over for File 2
   …
5. Quick test checklist

---

## File Organization and In-Code Navigation

### `// MARK:` is our shared map

* We use `// MARK:` headings consistently to orient Dan in larger files.
* Dan uses function/struct names to find the precise edit target, and `// MARK:` to understand where he is.

### We add plain-English file headers gradually

We do not stop the world to add headers everywhere.
Instead, **when we touch a file**, we add or improve a header at the top.

**Header template (default)**

* **Purpose:** what this file is for
* **Dependencies & Effects:** what it relies on and what it changes elsewhere (can be long)
* **Data Flow:** how data moves through this file (what reads what, what writes what)
* **Section Index:** the key `// MARK:` sections so Dan can jump around

**Note on “Data Flow”**
In this context, “Data Flow” means:

* where the data comes from (stores/bindings/models)
* how it’s transformed
* where it goes (UI updates, store writes, persistence)

---

## Risk and Rollback

### We only do Git “safety steps” when it’s actually risky

“Risky” means: **refactors or code-moving work** (moving responsibilities, reorganizing structure).

For risky changes, we include:

* A minimal checkpoint suggestion (commit/branch)
* A simple rollback instruction (what to revert/reset)

For non-risky fixes (small bugfixes, obvious compile errors), we keep Git chatter out of the way.

---

## Definition of Done (Per Change)

A change is “done” when:

* The project builds (or we clearly call out any remaining warnings/errors)
* The behavior matches the agreed goal
* Dan can locate key logic using function/struct names + `// MARK:`
* If it was a refactor, rollback guidance exists

---

## How Dan Should Ask (Recommended Request Patterns)

### Build error

* “Here’s the Xcode error and file path. Please propose the fix, and if it touches multiple files tell me how many up front.”

### Behavior issue

* “In the app, when I do X I expect Y but I see Z. Here’s where I think it’s happening (if known).”

### Refactor or redesign

* “I want to move responsibility from A to B. Start with a structured proposal and the number of files affected.”

---

## Default Expectations We Hold Each Other To

* We keep changes understandable and reversible.
* We prefer whole-file replacements over edit-splicing.
* We keep steps short, numbered, and searchable.
* We treat Dan’s time and attention as scarce resources (because they are).
