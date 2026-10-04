/// Generates README.md for the theme project.
String themeReadmeTemplate(String themeName) {
  final displayName = themeName.replaceAll('_', ' ').replaceAll('-', ' ');
  return '''
# $displayName

A Trellis theme.

## Installation

```bash
trellis theme add <git-url-or-local-path>
```

## Configuration

Add to your `trellis_site.yaml`:

```yaml
theme: $themeName
theme_params:
  skin: auto
  primary_color: "#2563eb"       # light palette
  primary_color_dark: "#60a5fa"  # dark palette
```

Colours are per mode: a plain colour param (`primary_color`) sets the light
palette's entry only, and its `_dark` twin sets the dark palette's. With
`skin: dark`, `primary_color` changes nothing; set `primary_color_dark`.

## Customization

### Override Layouts

Create a layout in your site's `layouts/` directory with the same name to override:

```html
<html tl:extends="theme:layouts/base.html">
<body>
  <footer tl:define="site-footer">
    <p>My custom footer</p>
  </footer>
</body>
</html>
```

### Change Values

Set `theme_params:` in your site's `trellis_site.yaml`. The build compiles
`sass/main.scss` with those values configured on the theme's `!default` variables
(`@use "main.scss" with (...)`). A site `sass/_variables.scss` does not
reconfigure them: Sass resolves the theme's own `@forward 'variables'` first.

## Development

Preview the theme during development:

```bash
cd example
trellis build
trellis serve
```

## Structure

```
$themeName/
  theme.yaml          # Theme manifest and params
  layouts/            # HTML layouts with tl:define blocks
  sass/               # SASS source: main.scss forwards _variables.scss first
    _skins/           # Light and dark palette maps
  static/             # Static assets (fonts, images, JS)
  example/            # Preview site for development
```
''';
}
