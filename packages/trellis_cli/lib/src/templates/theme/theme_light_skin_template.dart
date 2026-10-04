/// Generates sass/_skins/_light.scss, the light palette map.
String themeLightSkinTemplate() => r'''// Light palette. Read by _variables.scss, where each entry is the default of its
// colour param and the base of the light palette: the whole `skin: light` output
// and the base :root of `skin: auto`. Keep the entries equal to the colour
// defaults in theme.yaml.
//
// A skin file is a palette only: it declares no variable, because Sass
// configures a variable through the module that declares it (_variables.scss).
//
// WCAG 2.1 AA contrast ratios (computed over sRGB, per WCAG relative luminance):
//   On the page background (#ffffff):
//     #1f2937 = 14.68:1  (body text — passes 4.5:1)
//     #4b5563 =  7.56:1  (muted — passes 4.5:1)
//     #2563eb =  5.17:1  (primary/links — passes 4.5:1)
//     #1d4ed8 =  6.70:1  (accent, hover colour — passes 4.5:1)
//   On the elevated surface (#f3f4f6):
//     #1f2937 = 13.34:1  (body text — passes 4.5:1)
//     #4b5563 =  6.87:1  (muted — passes 4.5:1)
//     #2563eb =  4.70:1  (primary — passes 4.5:1)
//     #1d4ed8 =  6.09:1  (accent — passes 4.5:1)

$palette: (
  text-color: #1f2937,
  muted-color: #4b5563,
  bg-color: #ffffff,
  surface-color: #f3f4f6,
  border-color: #e5e7eb,
  primary-color: #2563eb,
  accent-color: #1d4ed8,
);
''';
