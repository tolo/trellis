/// Generates sass/_variables.scss with !default variables for all standard params.
String themeVariablesTemplate() => r'''// Theme variables — all use !default so site can override.
// These map to params in theme.yaml via the auto-generated _theme_params.scss.

// Skin & Colors
$trellis-primary-color: #2563eb !default;
$trellis-accent-color: #3b82f6 !default;
$trellis-text-color: #1f2937 !default;
$trellis-muted-color: #6b7280 !default;
$trellis-bg-color: #ffffff !default;
$trellis-surface-color: #f3f4f6 !default;
$trellis-border-color: #e5e7eb !default;

// Typography
$trellis-font-family: system-ui, -apple-system, sans-serif !default;
$trellis-heading-font-family: null !default;
$trellis-code-font-family: ui-monospace, monospace !default;

// Layout
$trellis-max-width: 800px !default;
$trellis-border-radius: 6px !default;

// Feature flags (SASS-only, not in CSS custom properties)
$trellis-show-powered-by: true !default;
$trellis-show-rss-link: true !default;
''';
