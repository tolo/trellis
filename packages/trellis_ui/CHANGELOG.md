## 0.15.0

- Add Popover with trigger and content slots, four-sided viewport placement and focus return after dismissal.
- Preserve the next control's focus when native Popover dismissal already returned focus to the trigger.
- Escape dismisses a focused Popover inside a Safari modal before dismissing the modal itself.
- Render only supplied Card copy. Omitted title, description and body slots no longer show demo text.
- Document a labelled native date field in the Input reference.
- Document the app-owned Cally 0.9.2 single-date and range recipe with native fallback and HTMX history recovery.
- Keep disabled Button progress labels at full opacity while `aria-busy="true"`.
- Add Tooltip for delayed, hoverable text hints and immediate hints on keyboard focus.
- Add a four-edge Sheet with native modal focus, link dismissal and an optional inline breakpoint.
- Add native single-open and multiple-open Accordion groups that work without JavaScript.
- Add Navigation menu with grouped site links, delayed hover, keyboard interaction and native disclosure fallback.
- Lattice and the docs site use Navigation menu, Accordion, Sheet, and Tooltip. Meadow closes its mobile
  Sheet on navigation. Both themes resolve the saved skin before paint under strict CSP.
- Inline Sheets allow Tab to leave the panel.
- Modal focus wrapping follows selected radios and editable regions, and skips collapsed or inert content.
- Add Command palette with a modal local picker, guarded keyboard shortcut, selection event, and focus return.
- Keep the highlighted palette result in view when the results panel is repositioned.
- Dropdown menus support nested actions with keyboard and pointer navigation.
- Pointer movement over a parent menu keeps keyboard focus in its open submenu.
- Dismissed dialogs, sheets, popovers and menus fade while native focus moves immediately. Reduced motion skips the fade.
- A rightward touch swipe dismisses one toast while the others retain their order.

## 0.14.0

- Add embedded suite fragments, same-origin assets and the pinned shadcn porting pipeline
  (developed against SDK 0.13.0).
- Add CSS-only native form controls, data views and stack/cluster/grid/container/sidebar fragments, with closed
  layout scales, touch-target overrides, destructive contrast and forced-colour focus/checked paint.
- Add dialog, alert dialog, dropdown menu, tabs, toast and HTMX-populated combobox fragments.
  One deferred classic script handles keyboard interaction and cleans up state across swaps and history restores.
  The combobox shows and announces “No results” after a request timeout and keeps the typed text.
- Add `dart run trellis_ui:materialize [dir]` to write or refresh the three embedded preview assets.
- Add a table header slot for column controls and `aria-sort`.
- Pin the vega port to `shadcn@4.23.0`. The sync checker matches the report's upstream rows to the inventory
  generated for the active pin.
- Release checks match optional component retirements to recorded failures and require withdrawal of the
  component's public reference and catalogue entry.
- Qualification accepts a passing measurement when the other browser records unsupported emulation with a
  reason. A later emulation limit preserves appearance differences already captured against a baseline.
  Malformed saved states or token samples make an otherwise clean comparison unavailable, even for states the
  browser could not reach.
  Component and app release checks and the reference generator use the same verdict.
