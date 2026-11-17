# trellis_ui

Embedded HTML fragments and CSS/JS. Runtime depends toward `trellis` only.

- Run `dart test --exclude-tags=ui-gate`, `dart analyze --fatal-infos` and `dart format .` here.
- The local full-gallery gate is `dart test test/qualification_gate_test.dart`, with `GECKODRIVER` set. Its
  `ui-gate`/`visual` tags are declared in this package; fast/full workspace tiers exclude it.
- `dart run tool/port.dart fetch` vendors the pinned sources and notices; `build` verifies the standalone compiler
  checksum before writing `generated/`. `check` regenerates all four outputs and rejects any byte drift.
- `dart run tool/port.dart parity` rejects unexplained slot, hook or marker drift. Every ignore needs a reason.
- `dart run tool/embed.dart` bundles sources and embeds base64 plus digests. `--check` rejects drift.
- Never edit `generated/` or `*.g.dart` by hand. Tests and runtime never start the compiler.
- Add `assets/fragments/<component>.html`, `assets/css/hand/<component>.css`, optional `assets/js/<NN>-<name>.js`, and
  `gallery/pages/<component>.html`. Hand CSS is layered by the bundler; `00-base.css` is in the earlier base layer.
- Keep base classes literal and use `tl:classappend` for modifiers; `tl:attrs` preserves caller classes without a
  missing-member read on strict engines.
- Fragments use `tl:replace`, `...attrs`, `tl:attrs` and slots. No literal ids, asset URLs, inline styles, inline
  scripts or event-handler attributes. The template name is `trellis-ui/<component>`.
- `dart run tool/gallery.dart --port 0` serves the strict-policy gallery. Its first stdout line is `Serving <base-url>`.
- Behaviour elements extend the light-DOM `TlElement` from `00-base.js`. Bind listeners with `listen` so they
  are removed on disconnect. Use `place` and `trackPopup` for CSSOM positioning on popovers marked
  `data-trellis-popup`. Use `onHistorySave` to clear transient state before HTMX serialises the page.
- A popup lifecycle recipe opens and closes the popup before swapping the actual containing region. Exercise
  that region through HTMX and use the history transient selector to catch stale UI.
