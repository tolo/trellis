# Native date field

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S08

## Feature Overview and Goal

**Intent**: Give Trellis authors a date field they can add to a form using the browser's built-in control.

**Expected Outcomes**

- [OC01] An author can find the recommended date field in the Input reference.
- [OC02] The example provides a labelled, named field that needs no client script to enter or submit a date.

## Required Context

- `dev/spec/0.15/prd.md#fr8-tier-2-recipe-seam-and-date-recipe` for the native baseline.
- `dev/spec/0.15/prd.md#mvp-boundary` for shipping the baseline independently of the recipe.
- `site/content/docs/ui/components/input.md#example` for the current reference example.

## Acceptance Scenarios

- **S01 [OC01,OC02] An author finds the native date field in the Input reference**
  - **Given** An author needs a single date in a form.
  - **When** They open the Input reference's Date fields section.
  - **Then** It presents `<input type="date">` as the baseline with a copyable example that includes an associated visible label and a submission name.

## Scope & Boundaries

### Work Areas

- Input reference prose and code example (TI01).

### What We're NOT Doing

- Story S09 owns the calendar, range recipe and admin integration.

## Architecture Decision

**Approach**: Add `## Date fields` to the existing Input reference and use native HTML for the example. Story S09 adds any recipe guidance after the baseline at this anchor.

## Implementation Plan

### Implementation Tasks

- **TI01** The Input reference offers the native date-field example alongside its current example.
  - **Verify**: `cmd: git grep -n -A 12 '^## Date fields$' -- site/content/docs/ui/components/input.md` – the section introduces the native baseline first and shows a visible `label` whose `for` matches the ID of a named `type="date"` input, using HTML alone.
  - **SATISFIES**: S01
