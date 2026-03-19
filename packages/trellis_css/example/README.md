# Example

Minimal SASS compilation and CSS dialect setup:

```dart
final css = TrellisCss.compileSassString(r'''
  $primary: #2563eb;
  .button { color: $primary; }
''');

final engine = Trellis(dialects: [CssDialect()]);
```

This demonstrates:

- Inline SASS compilation
- `CssDialect` registration on a Trellis engine
- The bridge between preprocessing and `tl:scope`

See also:

- Blog starter docs in `trellis_cli`
- SDK CSS package docs in this package README
