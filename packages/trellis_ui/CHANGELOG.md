## 0.14.0

- Add embedded suite fragments, same-origin assets and the pinned shadcn porting pipeline
  (developed against SDK 0.13.0).
- Add CSS-only native form controls, data views and stack/cluster/grid/container/sidebar fragments, with closed
  layout scales, touch-target overrides, destructive contrast and forced-colour focus/checked paint.
- Add dialog, alert dialog, dropdown menu, tabs, toast and HTMX-populated combobox fragments.
  One deferred classic script handles keyboard interaction and cleans up state across swaps and history restores.
- Add `dart run trellis_ui:materialize [dir]` to write or refresh the three embedded preview assets.
- Add a table header slot for column controls and `aria-sort`.
