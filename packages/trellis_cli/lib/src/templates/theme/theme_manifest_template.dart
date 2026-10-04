/// Generates theme.yaml with all 25 core standard params, the seven `_dark` colour twins included.
String themeManifestTemplate(String themeName) {
  return '''
name: $themeName
version: 0.1.0
author: Theme Author
description: A custom Trellis theme.
min_trellis_version: 0.8.0
features:
  - responsive
  - dark-mode

# Screenshots for gallery/README (optional)
# screenshots:
#   - screenshots/light.png
#   - screenshots/dark.png

params:
  # === Skin & Colors ===
  skin:
    type: enum
    values: [light, dark, auto]
    default: auto
    description: Color scheme — auto follows OS prefers-color-scheme

  primary_color:
    type: color
    default: "#2563eb"
    description: Brand/accent color — links, buttons, active states

  accent_color:
    type: color
    default: "#3b82f6"
    description: Secondary accent — hover states, highlights, borders

  text_color:
    type: color
    default: "#1f2937"
    description: Main body text

  muted_color:
    type: color
    default: "#6b7280"
    description: Secondary text — dates, metadata, captions

  bg_color:
    type: color
    default: "#ffffff"
    description: Page background

  surface_color:
    type: color
    default: "#f3f4f6"
    description: Elevated surfaces — code blocks, cards, callouts

  border_color:
    type: color
    default: "#e5e7eb"
    description: Borders, dividers, separators

  # Dark-mode twins: each colour param has a `<name>_dark` sibling that sets the
  # same entry in the dark palette (skin: dark, and the prefers-color-scheme
  # block of skin: auto). A plain colour param sets the light entry only.
  primary_color_dark:
    type: color
    default: "#3b82f6"
    description: Brand/accent color in dark mode — links, buttons, active states

  accent_color_dark:
    type: color
    default: "#60a5fa"
    description: Secondary accent in dark mode — hover states, highlights, borders

  text_color_dark:
    type: color
    default: "#f3f4f6"
    description: Main body text in dark mode

  muted_color_dark:
    type: color
    default: "#9ca3af"
    description: Secondary text in dark mode — dates, metadata, captions

  bg_color_dark:
    type: color
    default: "#111827"
    description: Page background in dark mode

  surface_color_dark:
    type: color
    default: "#1f2937"
    description: Elevated surfaces in dark mode — code blocks, cards, callouts

  border_color_dark:
    type: color
    default: "#374151"
    description: Borders, dividers, separators in dark mode

  # === Typography ===
  font_family:
    type: string
    default: "system-ui, -apple-system, sans-serif"
    description: Body text font stack

  heading_font_family:
    type: string
    default: null
    description: Heading font stack (null inherits body font)

  code_font_family:
    type: string
    default: "ui-monospace, monospace"
    description: Code/pre font stack

  # === Layout ===
  max_width:
    type: string
    default: "800px"
    description: Maximum content width

  border_radius:
    type: string
    default: "6px"
    description: Global border radius for cards, code blocks, tags

  # === Navigation ===
  nav_links:
    type: list
    default: []
    description: "Header navigation links [{label, url}]"

  social_links:
    type: list
    default: []
    description: "Social media links [{platform, url, label?}]"

  # === Footer ===
  footer_text:
    type: string
    default: null
    description: Custom footer text (null = theme default)

  show_powered_by:
    type: boolean
    default: true
    description: Show "Powered by Trellis" attribution

  # === Features ===
  show_rss_link:
    type: boolean
    default: true
    description: Display RSS/Atom feed link

  # === Theme-Specific Params ===
  # Add your theme's custom params below.
  # Example:
  # show_sidebar:
  #   type: boolean
  #   default: false
  #   description: Show sidebar navigation
''';
}
