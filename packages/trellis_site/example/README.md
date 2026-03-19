# Example

Minimal `trellis_site` setup:

```dart
final config = SiteConfig(
  siteDir: '.',
  title: 'My Site',
  baseUrl: 'https://example.com',
  taxonomies: ['tags'],
);

final site = TrellisSite(config);
```

This demonstrates:

- Programmatic site configuration
- `TrellisSite` construction
- The entry point used by `trellis build`

Related docs and examples:

- Blog starter template via `trellis create --template blog`
- Example apps: https://github.com/tolo/trellis/tree/main/examples
