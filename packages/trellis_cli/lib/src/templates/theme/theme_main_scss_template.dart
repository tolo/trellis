/// Generates sass/main.scss — the main SASS entry point.
String themeMainScssTemplate() => r'''// Main theme stylesheet.
// Import order: variables → skin → components.

@import 'variables';

// Base styles
body {
  font-family: $trellis-font-family;
  color: $trellis-text-color;
  background-color: $trellis-bg-color;
  line-height: 1.6;
  margin: 0;
}

a {
  color: $trellis-primary-color;
  text-decoration: none;

  &:hover {
    color: $trellis-accent-color;
  }
}

code, pre {
  font-family: $trellis-code-font-family;
  background-color: $trellis-surface-color;
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
