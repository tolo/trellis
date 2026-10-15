# Visual Validation

How to serve and capture the Trellis docs site, the bundled theme examples, and the Shelf example app, so a
re-validation recaptures exactly what the first pass did. Every command below was run on macOS with the
`agent-browser` CLI. Judging (severity, gates, report shape) belongs to the `andthen:visual-validation` skill, not here.

All paths are relative to the repository root. Captures go in `.agent_temp/validation/` (git-ignored).

## Serving

Pick a port nobody else is using and confirm it answers with something specific to your build before trusting a
capture: concurrent agents have measured another agent's server on the intended port. Ports below are the ones used
when this document was proven.

### Docs site (`site/`, theme `lattice`)

```sh
cd site
dart run ../packages/trellis_cli/bin/trellis.dart build --path-prefix '' --output ../.agent_temp/validation/site-build
dart run ../packages/trellis_cli/bin/trellis.dart serve --output ../.agent_temp/validation/site-build --port 8765 &
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8765/    # 200 when ready
```

- Ready when `serve` prints `Serving http://localhost:8765 ...` and curl returns 200. The build reports
  `Built 34 pages, 42 static files` in well under a second after the first compile.
- `--path-prefix ''` is required: `site/trellis_site.yaml` mounts the site under `/trellis/` for GitHub Pages, so
  without the override every asset URL 404s on a root-served preview.
- `tool/serve_docs.sh [port]` does the same into `site/output-root` (git-ignored), but first runs
  `dart run tool/generate_theme_gallery.dart`. That changes tracked gallery files only when they are stale against
  `themes/` (`--check` reports it), and then the regenerated files belong in the same commit. Use it when a theme
  manifest or screenshot changed; otherwise the commands above are enough.
- Rebuild after any change to `site/content`, `site/layouts`, or `themes/`. `serve` does not watch.

### Theme examples (`themes/<name>/example/`)

Build in a copy under `.agent_temp/`, never in place: an in-place build writes `output/` and `.trellis/` into the
theme's example directory, and a link into the repo makes the build write through it over real files. This mirrors
`buildExample` in `tool/visual_baseline.dart`.

```sh
R=$PWD
D=$R/.agent_temp/validation/theme-lattice
mkdir -p $D/themes/lattice
rsync -a --exclude themes --exclude output --exclude .trellis --exclude .dart_tool themes/lattice/example/ $D/
rsync -a --exclude example themes/lattice/ $D/themes/lattice/
cd $D
dart run $R/packages/trellis_cli/bin/trellis.dart build        # Built 5 pages; css/main.css must exist
dart run $R/packages/trellis_cli/bin/trellis.dart serve --port 8766 &
```

Use the `trellis` CLI build, not the SSG alone: only the CLI compiles the SASS and bridges `theme_params`, and a site
without `css/main.css` renders in the browser's default serif. Replace `lattice` with `arbor`, `bloom`, `folio`,
`meadow` or `verdant` for the others.

### Shelf example app (`examples/shelf_app`)

```sh
cd examples/shelf_app
PORT=8767 dart run bin/server.dart &      # prints: trellis_shelf_example running at http://localhost:8767
```

- Default port is 8080. The Counter value lives in server memory, so restart the process to return to 0.
- htmx is loaded from `cdn.jsdelivr.net` (the app's CSP allows it), so the page needs network access for the Counter
  buttons to work. `typeof htmx` is `object` when it loaded.
- `/favicon.ico` returns 404 in the server log. It is not a defect in the page.

### Stopping

Stop each server with Ctrl-C, or `lsof -nP -iTCP:<port> -sTCP:LISTEN` for the PID and `kill <pid>` for ones started
with `&`. Close the browser with `agent-browser --session <name> close`. Never use `agent-browser close --all`: it
ignores the session name and kills every other agent's browser.

## Capture

Tool: `agent-browser` (headless Chromium, device pixel ratio 1, native scrollbars hidden, so no scrollbar shifts the
layout). Use a named session so a concurrent agent does not share your page, and give every setting before `open`.

```sh
OUT=$PWD/.agent_temp/validation   # absolute: a relative path is resolved by the browser daemon, not your cwd
agent-browser --session vv set viewport 1280 800
agent-browser --session vv set media light reduced-motion  # or: dark reduced-motion
agent-browser --session vv open http://localhost:8765/
agent-browser --session vv wait 1000
agent-browser --session vv screenshot $OUT/home-1280.png
agent-browser --session vv close
```

In the commands below, `agent-browser $S` stands for `agent-browser --session vv`.

- Always open the written PNG and read it. A 200 response does not prove the page rendered.
- `set media` emulates `prefers-color-scheme` and `prefers-reduced-motion`. The docs site and the theme examples have
  `skin: auto`, so `set media dark` yields `<html data-theme="dark">` (read it back with
  `agent-browser $S eval "document.documentElement.dataset.theme"`). The skin toggle button persists the choice in
  `localStorage['trellis-theme']`, which then overrides emulation, so use a fresh session name after clicking it.
- One region per image at viewport size. Scroll for the next region and capture again:
  `agent-browser $S scroll down 900`, then `screenshot` (read back `scrollY` with `eval "scrollY"`). Full-page
  (`screenshot --full`, 1280x2126 on `/docs/syntax/attributes/`) and element (`screenshot "main" <path>`, 1280x1912)
  captures exist but exceed the 1600px long-side limit, so treat them as an overview only and judge from viewport
  captures.
- Overflow check, the same measurement `test/browser_reflow_probe.dart` uses:
  `agent-browser $S eval "document.documentElement.scrollWidth + '/' + document.documentElement.clientWidth"`.
  Anything other than equal numbers is horizontal overflow.
- Fonts: `document.fonts` lists every declared face and shows lazily loaded ones as `unloaded`. Count real failures
  with `[...document.fonts].filter(f => f.status === 'error').length` (0 when proven). Subsetted faces can lack
  glyphs the content emits (arrows, marks) and then render them in a system font with no error, so read non-ASCII
  characters in the image.
- Interaction: `agent-browser $S snapshot -i` lists controls with refs (`@e8`), then `click @e8`. `find text "+" click`
  matched the wrong element on the Shelf app, so prefer refs. `fill "input[type=search]" "fragment"` fills the docs
  search.

The Chrome DevTools MCP is also installed on this machine but was not used to prove this procedure.

## Routes and states

Docs site (`http://localhost:8765`), every built page is listed by
`find .agent_temp/validation/site-build -name index.html`:

| Route | Why it is worth validating |
|---|---|
| `/` | Lattice home: vine hero, rotating headline, code window |
| `/docs/` | Section index, sidebar tree |
| `/docs/syntax/attributes/` | Long page: sidebar, breadcrumb, code block, "On this page" column |
| `/docs/themes/gallery/` | 13 images, theme cards, install snippet |
| `/docs/packages/trellis/` | Package page (built, not captured in this session) |

Non-default states, all proven:

- Dark skin: `set media dark reduced-motion` before `open`.
- Mobile menu open: at 390px, `agent-browser $S find text "Menu" click`, wait 500ms, capture.
- Search results: at 1440px on any docs page, `fill "input[type=search]" "fragment"`, wait 800ms. Results render in the
  sidebar above the section tree.

Theme examples (`http://localhost:8766` when serving lattice): `/` and the pages under `/docs/`. Fixture pages for
deliberately awkward content are built by `buildFixtures` in `tool/visual_baseline.dart` and are not served by the
recipe above.

Shelf app (`http://localhost:8767`): `/` shows the Counter at 0 (the `-` button disabled). Click `+` through its ref
to reach the incremented state (a POST to `/counter/increment`, then the fragment is swapped in). `/about` exists and
was not captured.

Not covered because they were not served in this session: `examples/todo_app`, `examples/relic_app`,
`examples/dart_frog_app` and `examples/docs_site`. The first three start with `dart run bin/server.dart` or the
README command and listen on 8080, but that is unproven here.

## Breakpoints

Judge at 390, 768, 1024 and 1440 px wide. 390, 768 and 1440 are the widths `test/visual_baseline_test.dart` records
for the themes; 1024 sits between the docs site's 981 and 1180 bands; 390 is also the widest of the narrow widths
(320, 375, 390) that `test/reflow_sweep.dart` sweeps. Hero captures use 1280x800, which is the size of the committed
theme screenshots.

The docs site's compiled `css/main.css` changes layout at `max-width` 700, 900, 980, 1199 and `min-width` 1180, and
`gallery.css` at 700 and 981. When a change touches layout, also capture one width either side of the boundary it
affects (699/701, 979/981, 1179/1200). Viewport heights are 800 for desktop and 844 for 390 wide.

## References

- Theme top-of-fold screenshots: `themes/<name>/screenshots/light.png` and `dark.png`, 1280x800, byte-pinned by SHA-256
  in `tool/theme_screenshot_digests.json`. They are reference images for the theme's example home page. A fresh
  capture differs from them by antialiasing on every theme (4 to 24 percent of pixels, see `dev/state/LEARNINGS.md`),
  so compare by reading both images, not by pixel diff.
- Recorded appearance of the six theme examples: `test/visual_baselines/<theme>.macos.json`, a digest of box geometry
  and computed styles at 390/768/1440 in light and dark, not images. Check with
  `dart test test/visual_baseline_test.dart` (macOS only, about 55 seconds, 7 tests passed when proven). Never run it
  with `UPDATE_VISUAL_BASELINES=1` during validation: that rewrites tracked baselines.
- `site/static/themes/<name>/{light,dark}.png` are the gallery's copies of those theme screenshots, not references for
  the docs pages.
- No wireframes, mockups or design-system document exist in this repository. The docs site pages (`/`, `/docs/...`),
  the Shelf app and the other examples have no reference image, so they are judged by the defect sweep alone.

## Traps

- **Home hero timing.** Lattice's vine and leaf entrance runs to about 2.7s, and the headline rotator starts at 6.5s
  and cycles through three headlines (`hero_headlines`). A capture before 2.7s shows a half-grown vine and a
  partly faded headline; one after 6.5s shows a different headline than the server-rendered first entry. Emulating
  `reduced-motion` before `open` removes both: `document.getAnimations().length` was 0 and the first headline was
  unchanged after 8 seconds. The capture in this procedure always sets it. Without it, capture between 3 and 6 seconds.
- **Reduced motion hides animation bugs.** A change to the vine or rotator itself has to be captured without
  `reduced-motion`, inside the 3 to 6s window, and the leaf count checked (six leaves on the finished vine, from six
  `vine-leaf` animations).
- **Do not build theme examples in place.** See Serving. The recorded digest and the committed screenshots both
  come from the copy recipe.
- **Standalone theme previews are not the docs site.** The docs site builds with `theme_params` bridged into the
  compiled CSS; a standalone theme build uses the theme's own SCSS defaults and can hide bridge bugs such as quoted
  `font-family` values. Validate a docs-site claim on the docs-site build.
- **Stale build.** `serve` serves whatever is in `--output`. After editing content, layouts or a theme, rebuild before
  capturing, and read a string that only the new build has.
- **Relative screenshot paths** land in `~/.agent-browser/tmp/` instead of the given path. Pass absolute paths.
- **Concurrent agents.** Ports and the default `agent-browser` session are shared. Name your session, claim a port
  range, and curl it first.
- **Offline.** The Shelf app's htmx comes from a CDN. The docs site and theme examples are fully same-origin and need
  no network.
