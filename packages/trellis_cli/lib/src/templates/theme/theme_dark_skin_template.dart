/// Generates sass/_skins/_dark.scss, the dark palette map.
String themeDarkSkinTemplate() => r'''// Dark palette. Read by _variables.scss, where each entry is the default of its
// `<name>_dark` param and the base of the dark palette: the whole `skin: dark`
// output, and the `prefers-color-scheme: dark` block main.scss emits for
// `skin: auto`. Never derived from the light palette. Keep the entries equal to
// the `_dark` defaults in theme.yaml.
//
// WCAG 2.1 AA contrast ratios (computed over sRGB, per WCAG relative luminance):
//   On the page background (#111827):
//     #f3f4f6 = 16.12:1  (body text — passes 4.5:1)
//     #9ca3af =  6.99:1  (muted — passes 4.5:1)
//     #60a5fa =  6.98:1  (primary/links — passes 4.5:1)
//     #93c5fd =  9.84:1  (accent — passes 4.5:1)
//   On the elevated surface (#1f2937):
//     #f3f4f6 = 13.34:1  (body text — passes 4.5:1)
//     #9ca3af =  5.78:1  (muted — passes 4.5:1)
//     #60a5fa =  5.77:1  (primary — passes 4.5:1)
//     #93c5fd =  8.14:1  (accent — passes 4.5:1)

$palette: (
  text-color: #f3f4f6,
  muted-color: #9ca3af,
  bg-color: #111827,
  surface-color: #1f2937,
  border-color: #374151,
  primary-color: #60a5fa,
  accent-color: #93c5fd,
);
''';
