# ADR-013: SASS Module Bridge and Per-Mode Colour Params

## Status
Accepted (owner, 2026-10-04). Implemented in 0.12. Supersedes the SASS bridge mechanism of
[ADR-008](ADR-008-ssg-theme-system.md); the rest of ADR-008 (theme structure, layout resolution, override model,
distribution) stands. Decided in steps by the owner: the hard cut and per-mode colours on 2026-08-18, the gate's
placement and the reader-toggle rule on 2026-10-03, this record on 2026-10-04.

## Context

ADR-008's bridge makes a theme's `!default` variables overridable by `@import` order. The CLI writes a wrapper per theme
entry that imports, in order, an optional skin file, the generated `_theme_params.scss` and the theme's `main.scss`; the
earlier file wins because everything the theme declares is `!default`. That mechanism has three problems.

1. **`@import` is going away.** Dart Sass deprecated it and removes it in 3.0.0. Every bundled theme, the CLI scaffold and
   the bridge's own wrapper used it, so Trellis would stop compiling its own themes on the first Dart Sass 3 upgrade.
2. **Skin precedence was an accident of load order.** The skin file was imported before the params, so a forced skin beat
   a site's colour override: `skin: dark` with `primary_color: "#ff0000"` compiled to the dark palette's primary. The
   `skin: auto` dark block hard-coded its colours as literals, so no param reached it either. Colour overrides applied
   to the light mode only, by an ordering nobody had decided on.
3. **A site's `sass/_variables.scss` never overrode a theme.** ADR-008 lists "site `sass/_variables.scss` overrides theme
   `!default` vars" as the fourth override dimension. Sass resolves a `@use`/`@import` relative to the importing file
   before it consults a load path, so the theme's own `variables` always won, whatever the load-path order. The claim
   was never true, and `@use` cannot make it so.

The decision is how a theme's SASS is configured by the build, and what a colour param means.

### Spike evidence

A throwaway spike on Dart Sass 1.98.0 (2026-08-17, repeated 2026-10-03) answered the questions the design turns on.
"Module" below is a stylesheet loaded with `@use`.

| ID | Question | Result |
|---|---|---|
| E1 | Under `@import`, which layer wins? | Bridge params beat theme defaults; a skin imported before the params beats both. A forced skin defeats a site colour override. |
| E2a | Does `@use '<main>' with (...)` configure a theme whose `main.scss` is `@forward 'variables'; @use 'base'; …` and whose partials `@use 'variables' as *`? | Yes. A module `@use`d by two files is emitted once. |
| E2b | `@use 'base'` before `@forward 'variables'`? | Hard error: `This module was already loaded, so it can't be configured using "with".` |
| E2c | A `main.scss` that `@use`s `variables` without forwarding it? | Hard error: `This variable was not declared with !default in the @used module.` |
| E2d | Configuring a variable the theme never declares (a manifest param with no SASS variable)? | Hard error, same message. The bridge cannot configure the full param set blindly. |
| E2e | A second `with()` on an already-loaded module? | Hard error, as E2b. Configuration happens once, at first load. |
| E3 | A single map parameter (`$trellis-params: (...)`) with a lookup function? | Works, and unknown keys are harmless. Rewrites every declaration in every theme. |
| E4 | `@forward 'variables' with ($x: v !default)` as the bridge? | Works, but at the wrong layer: it lets a theme pre-set a default that a downstream `@use … with` can still override. |
| E5 | Skins as `$palette` maps, with the forced-dark reassignment inside `_variables.scss`? | Reproduces the old skin-wins output exactly, with and without a colour override. A per-mode param is one `map.merge` away. |
| E5c/d | Site wins: the skin palette used only as the `!default` fallback for an unset colour? | The override is honoured and an unset colour falls back to the dark palette. Not adopted (option H). |
| E5e | Skin-wins removed, fed the full merged params? | The skin is silently defeated by the theme.yaml default. A mode-independent override cannot be built on the merged map. |
| E6 | Does a site `sass/_variables.scss` shadow the theme's own? | No. Relative resolution wins over every load path. |
| E7 | Can `with()` read its values from a generated module (`tp.$x`)? | Yes. Values are written once, in the generated file. |
| E8 | Does a configurable theme compile standalone? | Yes, on its own defaults. |
| E9 | Does `@use` change CSS emission order? | Yes. `@import` emits a partial per occurrence, `@use` once at first load. A trailing duplicate disappears, and a rule that won the cascade by appearing last can change. |
| E10 | Can `main.scss` both `@forward 'variables'` and `@use 'variables' as *`? | Yes. Its root-level `@if $trellis-skin == auto` block still emits. |

## Decision Drivers

- **`@import` is removed in Dart Sass 3.0.0**, and the SDK must keep compiling its own themes. The tests compile with the
  `import` deprecation as a fatal error, so a regression cannot ship.
- **No Trellis-specific invention** (ADR-008's recorded rationale). The mechanism should be Sass's own module
  configuration, which is what theme authors already know.
- **A manifest can declare more params than a theme has SASS variables** (E2d). Templates read `nav_links`; SASS never
  does. The bridge must not break on them.
- **Colours are per mode.** A colour picked against a white background has no verified contrast on `#0d1117`, and every
  mature theming system surveyed resolves brand colours per mode.
- **Pre-1.0, no external themes.** Backwards compatibility has no one to protect, and a compatibility branch would be
  the most expensive part of the change.
- **The result must be provable.** Compiled CSS, not generated SCSS text, is what a site gets.

## Options

### Module configuration

**A. `@use … with()` over the intersection (chosen).** The generated `_theme_params.scss` is a plain module. The wrapper
configures the theme entry with every manifest param that the theme's `_variables.scss` declares `!default`.

- (+) Standard Sass; the theme's `!default` variables stay the contract; values are written once (E7).
- (+) The intersection reproduces the old semantics exactly: a param with no SASS variable was inert under `@import` too.
- (−) Needs a scan of `_variables.scss` and a first-load rule (`@forward 'variables'` first, E2b/E2c).

**B. Blind per-variable `with()`.** Configure every manifest param.

- (−) Hard-fails on any param without a SASS variable (E2d): 5, 2 and 15 params in three of the bundled themes, and on
  every param a future theme declares for templates only. Rejected.

**C. Single map configuration (E3).** `$trellis-params: (...)` plus a lookup function in every theme.

- (+) No name-mismatch failure is possible.
- (−) A Trellis-specific parameter protocol, against ADR-008's rationale, and a rewrite of every declaration line in every
  theme. Rejected, but it is the fallback if the intersection scan proves brittle.

**D. `@forward … with` as the bridge (E4).** Rejected: the wrapper is the entry point, so `@use … with()` is its rule.
`@forward … with (… !default)` stays a theme-authoring tool for defaulting a sub-module's variable.

### Compatibility

**E. Dual mode (an `@import` branch behind a manifest field) or a deprecation window.** Rejected by the owner: no theme
outside the repository exists, and a second bridge doubles the surface this change is meant to shrink.

**F. Hard cut (chosen).** One bridge, one theme contract.

### Colour precedence

**G. Skin wins, colours per mode (chosen).** A forced skin selects a complete palette; a colour param sets one entry in
one palette.

**H. Site wins.** Skin palette used only as the fallback for an unset colour (E5c/d). A mode-independent override then
lands on a background it was never checked against, and cannot be built on the merged params (E5e). Not adopted.

**I. A nested `colors: {light: …, dark: …}` param.** Rejected: the generator types params from a flat name-to-type map and
honours `type: color` only at the top level, so nested entries would be emitted as plain strings and the CSS custom
property pass skips map values. It also collapses the configurable surface to one `$trellis-colors` variable.

## Decision

**Adopt option A with the hard cut (F) and per-mode colours (G).**

### The wrapper

For each non-partial `.scss`/`.sass` file in a theme's `sass/` directory, the build writes
`.trellis/build/bridge_<entry>.scss` and compiles it with the load path `[.trellis/build/, <site>/sass/, <theme>/sass/]`:

```scss
@use "theme_params" as tp;
@use "/abs/path/to/theme/sass/main.scss" as theme with (
  $trellis-skin: tp.$trellis-skin,
  $trellis-primary-color: tp.$trellis-primary-color,
  $trellis-primary-color-dark: tp.$trellis-primary-color-dark,
  // …only the variables the theme declares !default
);
```

`_theme_params.scss` holds `$trellis-<name>: <value>;` for every merged param, with no `!default`, so it is read by
namespace and never configured. The wrapper text comes from one function (`ThemeBuildConfig.bridgeWrapperSource`,
`trellis_site`) that the CLI build calls and the tests compile, so a test compiles exactly what `trellis build`
compiles. The entry gets the explicit namespace `theme`, because Sass rejects a default namespace that is not an
identifier (`2col.scss`). With no configurable variables the entry is `@use`d without `with()`. The entry is written as
the path of its `file:` URL (`/C:/a%20b/main.scss` on Windows), never a native path: Sass parses a load string as a
URL, so `C:\…` reads as scheme `c:`, and a full `file:` URL resolves only through load paths.

### The intersection rule

The `with()` list is the manifest's params intersected with the `$trellis-*` variables that the theme's
`sass/_variables.scss` declares `!default`. The scan reads whole statements, so line breaks do not matter, and a
configurable `$trellis-*` declared anywhere else is not configured. The reason is E2d: Sass fails the build when
`with()` names a variable the module does not declare `!default`, and the bridge cannot know which manifest params a
theme meant for SASS. Params the theme reads only in templates stay inert, as they were under `@import`. A manifest
param the site sets but the manifest does not declare is dropped before the wrapper is written.

### The forward-first rule

Every theme entry's first module rule is `@forward 'variables'` (E2b, E2c, E2e): Sass configures a module on its first
load only, and the forward is what makes the variables part of the module the wrapper configures. Every entry in `sass/`
receives the same list, so every entry carries the forward. The entry may also `@use 'variables' as *` for its own
use (E10). Both Sass errors above are quoted in the theme authoring guide.

### Skins are palette maps

`_skins/_light.scss` and `_skins/_dark.scss` each expose a `$palette` map and declare nothing `!default`. Palette keys
are the colour params' names in kebab case (`primary-color`), so a param finds its entry mechanically. `_variables.scss`
declares `$trellis-skin` and, per colour param, `$trellis-<name>` defaulting to its light entry and `$trellis-<name>-dark`
to its dark entry, both `!default`. It builds the public `$trellis-palette-light` and `$trellis-palette-dark` by merging
those variables back into the palettes, and under `skin: dark` reassigns the colour variables from the dark palette
before anything is derived from them. The bridge injects nothing for a skin.

### Per-mode colour params

Every `type: color` param has a flat sibling `<name>_dark`, also `type: color`, whose default equals its dark palette
entry. Twins have no twins. The seven standard colour params become 14, taking the standard contract from 18 to 25
params, and a theme's own colour params (bloom's gradient colours, meadow's sky and sun) get twins too.

**Precedence rule.** A forced skin selects a palette and a param sets one entry in it. There is no mode-independent
colour override:

- `skin: light` emits the light palette; `_dark` params are inert.
- `skin: dark` emits the dark palette; `_dark` params apply. A plain `primary_color` sets the light entry only, so it
  does nothing on a forced-dark site. `primary_color_dark` is the knob.
- `skin: auto` emits both (the light `:root`, and `@media (prefers-color-scheme: dark)` carrying the dark palette), each
  with its own overrides.

**Every dark view reads `$trellis-palette-dark`**: forced dark, the `auto` media block, and a reader toggle's dark
selectors (lattice, folio, meadow). The toggle's light selectors carry the light values. A dark token follows
`<name>_dark` exactly when its light counterpart is set from `<name>`; a token whose dark value merely equals a palette
entry does not follow it, and tokens with no colour param stay theme-authored.

**Dark is never derived from light** (`darken()`, `color.adjust()`, a mixed tint). The bundled dark palettes carry
hand-computed WCAG ratios per pair; one derived override would silently shift all of them. The reasoning, with a survey of
eleven theming systems (Docusaurus, MkDocs Material, Starlight, VitePress and Hextra resolve brand colours per mode, and
none ships one global brand colour applied unchanged to both), is in the private planning repo, canonical:
`docs/research/10-skin-vs-override-precedence.md`.

### The hard cut

There is no compatibility mode. The `@import` skin line and the import-deprecation silencing are gone from the build
path, `TrellisCss.compileSass` no longer has a parameter to silence the `@import` deprecation, and every bundled theme
and the `trellis create --template theme` scaffold are migrated in 0.12. `trellis build` compiles a theme with the
`import` deprecation fatal, so a third-party theme whose entry still `@import`s fails with Sass's import-deprecation
error, not a Trellis diagnostic; that is accepted. Without the fatal flag it would compile with only a warning while its
skin file is no longer injected, so `skin: dark` would silently build light. A site's own stylesheets are compiled
without the flag: their `@import` stays legal until Dart Sass 3.0. The owner's rationale: *"No one is really using
Trellis yet (and no-one has created a Trellis theme yet), so it's ok to make breaking changes if this makes things
simpler. We don't need backwards compatibility."* The break rides the lockstep minor (ADR-009).

### Enforcement

`packages/trellis_site/test/theme_sass_use_gate_test.dart` compiles every theme discovered under `themes/`, bridged at
each skin through `ThemeBuildConfig.bridgeWrapperSource` and standalone, with the `import` deprecation fatal; asserts no
`@import` in a theme, a scaffold template or a generated bridge file; checks each colour param's twin and default
against the palettes, which it reads by compiling them; and fails a param variable the bridge cannot configure. A theme
directory without a `theme.yaml`, or a missing bundled theme, fails discovery. Each check also runs on mutated copies of
a bundled theme to prove it fails. The test is untagged, so the fast CI job (`melos exec --dir-exists=test -- dart test
--exclude-tags=e2e`) runs it. The scaffold has its own test in `trellis_cli`, because
`trellis_site` cannot depend on the CLI.

### What this does not change

SASS stays a Dart-native library call (ADR-006); no Node.js or Sass binary is involved. Layout resolution, the override
model's first three dimensions, theme distribution and the `_theme_custom_props.css` sink are unchanged. The fourth
override dimension changes: site SASS may read the merged params (`@use "theme_params" as tp`) but cannot reconfigure a
theme, as it never could (E6); `theme_params:` is the one way.

## Consequences

### Positive

- Themes compile on Dart Sass 3.0.0, and a regression fails a test instead of a user's build.
- A colour override works in the default mode: the `auto` dark block reads the dark palette, so `primary_color_dark`
  reaches it, and the hand-maintained duplicate of each skin file is gone.
- The `!default` convention and the theme file layout survive; the rewrite is in how skins are expressed.
- A plain colour param has one documented meaning under every skin.

### Negative

- A breaking change to the theme contract and to what `theme_params:` colour keys mean on a dark site: the standard
  contract grows to 25 params, and a `skin: dark` site that set `primary_color` now sets `primary_color_dark`.
- Theme authors must follow the first-load rule, and a configurable variable declared outside `_variables.scss` is
  silently not configured (the gate catches it for bundled themes only).
- The intersection scan is a heuristic over SCSS text. Option C is the recorded fallback if it proves brittle.
- Emission order changes (E9): `@use` emits a module once, at first load, so bloom's layout block, which `@import`
  emitted twice, now appears once, and a rule that won the cascade by appearing later can change. Each theme's compiled
  CSS is diffed against the pre-migration output and every difference explained before it ships.

### Neutral

- `_theme_custom_props.css` gains the seven `--trellis-<name>-dark` entries (`css/theme-props.css`); nothing reads them.

## References

- [ADR-008](ADR-008-ssg-theme-system.md): the theme system whose SASS bridge this supersedes
- [ADR-006](ADR-006-css-strategy.md): SASS stays a Dart-native library call
- [ADR-009](ADR-009-package-versioning-strategy.md): the break ships in the lockstep minor
- [Theme Authoring Guide](../../docs/guides/theme-authoring.md) and
  [Standard Params Contract](../../docs/reference/standard-params.md): the contract as theme authors and site builders
  read it
- Sass module system: <https://sass-lang.com/documentation/at-rules/use/> (`with`, `!default` configuration) and
  <https://sass-lang.com/documentation/at-rules/forward/> (`@forward … with`)
- Sass `@import` deprecation: <https://sass-lang.com/documentation/breaking-changes/import/>
