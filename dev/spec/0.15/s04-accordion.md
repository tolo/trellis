# Accordion

**Plan**: dev/spec/0.15/plan.json
**Story-ID**: S04

## Feature Overview and Goal

**Intent**: Let authors group FAQs and navigation without building an accessible disclosure widget themselves.

**Expected Outcomes**

- [OC01] Readers can open and close sections with pointer or keyboard, including when suite assets are unavailable.
- [OC02] Authors can compose independent single-open and multiple-open groups from suite fragments.
- [OC03] Accordion appears in the suite reference with the evidence required by ADR-012.

## Required Context

- `dev/spec/0.15/prd.md#fr4-accordion`
- `dev/spec/0.15/prd.md#non-functional-requirements`
- `dev/spec/0.15/prd.md#edge-cases`
- `dev/spec/0.15/prd.md#constraints`
- `dev/PRODUCT.md#proportionality`
- `dev/adrs/ADR-012-trellis-ui-contract.md#porting-pipeline`
- `dev/adrs/ADR-012-trellis-ui-contract.md#browser-emulation-fallback`
- `dev/guidelines/TESTING-STRATEGY.md#ui-qualification-gate`
- `dev/guidelines/RELEASE-RUNBOOK.md#trellis-ui-release-prep`

## Acceptance Scenarios

- **S01 [OC01,OC02] [runtime] Native summaries toggle sections independently in multiple-open mode**
  - **Given** a rendered multiple-open FAQ starts with its first section open and its second closed.
  - **When** the reader opens the second summary by click, Enter or Space in separate trials and then activates it again.
  - **Then** a native `<details>` with its first-child `<summary>` exposes the expanded and collapsed states, content follows that state and the first section stays open.

- **S02 [OC01,OC02] [runtime] Single-open mode closes the previous section in its own group**
  - **Given** two independently named single-open groups each start with their first section open.
  - **When** the reader opens the second summary in the first group.
  - **Then** only the previously open section in that group closes. The other group stays as it was.

- **S03 [OC01,OC02] [runtime] Both modes work before enhancement**
  - **Given** the served gallery runs with scripts disabled, and each group includes an ordinary link in its second section.
  - **When** the reader opens a second section in each mode with the keyboard.
  - **Then** both links are reachable and activatable, the first multiple-open section stays open, and the first single-open section closes.

- **S04 [OC03] [runtime] Accordion passes the served-gallery qualification gate**
  - **Given** the pinned port is embedded and the Accordion gallery is served under `script-src 'self'; style-src 'self'`.
  - **When** the gate runs on Chrome and Firefox against both modes, including HTMX replacement and history restoration.
  - **Then** every automated item qualifies under ADR-012’s browser rule, with zero CSP violations and the native disclosure working after a swap or restore. The retained record carries results from both browsers.

## Structural Criteria

- **SC01 [runtime]** Accordion’s slots and style hooks reproduce from the active shadcn pin through the existing MIT-licensed, no-Node port and embedding path. Subsequent sync hand edits stay within the PRD limit.
- **SC02** The component reference and package catalogue expose the fragment contract and its native behavior. Its support claim is governed by the three manual results at release prep.

## Scope & Boundaries

### Work Areas

- Pinned Accordion source, native fragment composition, CSS, embedding and styling state (TI01, TI02).
- Gallery exercise, release inventory, qualification manifest, appearance baseline and browser records (TI02, TI03).
- Package catalogue and component reference (TI04).

### What We're NOT Doing

- Story S06 owns Lattice adoption and its theme baselines. Its existing navigation links continue to be destinations.
- Optional height animation is outside this slice. The browser owns disclosure visibility.

## Architecture Decision

**Approach**: Use native `<details>` and `<summary>` for interaction and shadcn’s generated styling for appearance. Any JavaScript only mirrors the native state for styling.
**Why this over the floor**: A raw `<details>` example supplies disclosure, while FR4 also requires a composable suite fragment with the pinned look and qualified release evidence.

**Flow**:

- `trellis-ui/accordion :: accordion(...attrs)` accepts Accordion items in its default slot. `accordionItem(name, title, open, ...attrs)` accepts panel contents in its default slot.
- Use the same nonempty `name` for every item in one single-open instance. Give separate instances distinct tokens across the document. Pass null in multiple-open mode so `name` is absent. `title` labels the native summary. Keep interactive links in the item content or beside the item.

## Constraints & Gotchas

- Native exclusivity applies to the whole light DOM tree. When rendering a group twice, for example in a static sidebar and a Sheet, use distinct group names even when a breakpoint hides one copy.
- If generated selectors need a state mirror, read the actual `open` value on connection and native `toggle` on each item. Native exclusivity can toggle an item the reader did not activate. Story S01 supplies the common lifecycle and state helper.
- Qualification records keep VoiceOver with Safari, NVDA with Firefox, and the Safari browser pass at `release-prep` for the maintainer, per the PRD and release runbook.

## Implementation Plan

### Implementation Tasks

- **TI01** Accordion reproduces through the active port and embedding pipeline.
  - **Verify**: `cmd: dart run packages/trellis_ui/tool/port.dart parity && dart run packages/trellis_ui/tool/port.dart check && dart run packages/trellis_ui/tool/embed.dart --check` – Accordion's pinned inputs, documented structural differences, generated CSS and embedded bytes agree. Check the active sync report for applicability of the PRD hand-edit ceilings to subsequent syncs.
  - **SATISFIES**: SC01

- **TI02** Both modes and their fallback work in the rendered gallery.
  - Follow `packages/trellis_ui/test/behaviour_browser_test.dart#main` for the served route and `test/browser_reflow_probe.dart#BrowserProbe` for script disabling.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/accordion_browser_test.dart` – assert native summary state and visible content, three input methods, independent groups, and activatable links in both modes with scripting disabled.
  - **SATISFIES**: S01, S02, S03

- **TI03** Accordion's gallery qualifies in the two-browser sweep and feeds the existing release inventory.
  - Register the subject in the release policy. Record closed/open examples in both modes and exercise the conditional visual and interaction checks through the manifest.
  - **Verify**: `cmd: cd packages/trellis_ui && dart test test/gate_records_test.dart test/qualification_gate_test.dart` – the retained Accordion record matches a fresh Chrome and Firefox run with zero CSP violations and working disclosure after HTMX lifecycle checks.
  - **SATISFIES**: S04

- **TI04** Authors can find and copy both modes from the public reference.
  - **Verify**: `cmd: dart run tool/generate_ui_reference.dart --check && git grep -n -e 'accordionItem' -e 'Accordion' -- site/content/docs/ui/components/accordion.md packages/trellis_ui/README.md` – confirm the generated reference agrees with the record, the listed signatures and both examples match the embedded fragments, and support follows the manual results.
  - **SATISFIES**: SC02
