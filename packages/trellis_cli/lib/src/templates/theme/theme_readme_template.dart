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
  primary_color: "#2563eb"
```

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

### Override SASS Variables

Create `sass/_variables.scss` in your site to override theme defaults:

```scss
\$trellis-primary-color: #e11d48;
```

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
  sass/               # SASS source with !default variables
    _skins/           # Light and dark skin presets
  static/             # Static assets (fonts, images, JS)
  example/            # Preview site for development
```
''';
}
