/// Generates sass/main.scss — the main SASS entry point.
String themeMainScssTemplate() => r'''// Main theme stylesheet.
//
// Build: the CLI compiles a wrapper that `@use`s this file with the merged
// params configured (`@use "main.scss" with ($trellis-primary-color: ..., ...)`).
// Only variables _variables.scss declares !default are configured.

// Sass configures a module only when it is first loaded, so this `@forward` must
// come before any other rule that loads _variables.scss. Reordering it fails the
// build with "This module was already loaded, so it can't be configured using
// "with"."
@forward 'variables';
@use 'sass:map';
@use 'variables' as *;

// Colours are custom properties, so the base styles below read var(--trellis-*)
// and the auto block can flip them for OS dark mode. The layout tokens are
// there for layouts and site CSS to read.
:root {
  --trellis-text: #{$trellis-text-color};
  --trellis-muted: #{$trellis-muted-color};
  --trellis-bg: #{$trellis-bg-color};
  --trellis-surface: #{$trellis-surface-color};
  --trellis-border: #{$trellis-border-color};
  --trellis-primary: #{$trellis-primary-color};
  --trellis-accent: #{$trellis-accent-color};
  --trellis-max-width: #{$trellis-max-width};
  --trellis-radius: #{$trellis-border-radius};
}

// skin: auto emits the light palette above plus this block, which carries the
// dark palette. Under skin: light it would flip a forced-light site dark for
// dark-OS visitors, and under skin: dark the :root above is already dark.
// Reading $trellis-palette-dark lets a site's `<name>_dark` param reach it.
@if $trellis-skin == auto {
  @media (prefers-color-scheme: dark) {
    :root {
      --trellis-text: #{map.get($trellis-palette-dark, text-color)};
      --trellis-muted: #{map.get($trellis-palette-dark, muted-color)};
      --trellis-bg: #{map.get($trellis-palette-dark, bg-color)};
      --trellis-surface: #{map.get($trellis-palette-dark, surface-color)};
      --trellis-border: #{map.get($trellis-palette-dark, border-color)};
      --trellis-primary: #{map.get($trellis-palette-dark, primary-color)};
      --trellis-accent: #{map.get($trellis-palette-dark, accent-color)};
    }
  }
}

// Base styles
body {
  font-family: $trellis-font-family;
  color: var(--trellis-text);
  background-color: var(--trellis-bg);
  line-height: 1.6;
  margin: 0;
}

a {
  color: var(--trellis-primary);
  text-decoration: none;

  &:hover {
    color: var(--trellis-accent);
  }
}

h1, h2, h3, h4, h5, h6 {
  font-family: $trellis-heading-font;
}

code, pre {
  font-family: $trellis-code-font-family;
  background-color: var(--trellis-surface);
  border-radius: $trellis-border-radius;
}

pre {
  padding: 1rem;
  overflow-x: auto;
}

code {
  padding: 0.125rem 0.25rem;
}
''';
