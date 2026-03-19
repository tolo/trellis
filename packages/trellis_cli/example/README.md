# Example

Programmatic starter generation with `trellis_cli`:

```dart
final writer = InMemoryFileWriter();
final generator = ProjectGenerator(projectName: 'demo_app', writer: writer);

await generator.generate();
print(writer.files.keys);
```

This demonstrates:

- In-memory file generation for tests and tooling
- The same starter generator used by `trellis create`
- Programmatic access to scaffolding primitives

Command-line equivalents:

- `trellis create my_app`
- `trellis create --template dart_frog my_app`
- `trellis create --template relic my_app`
- `trellis create --template blog my_blog`
