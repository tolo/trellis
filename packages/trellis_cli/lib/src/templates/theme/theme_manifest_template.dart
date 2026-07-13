/// Generates theme.yaml with all 18 core standard params.
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
