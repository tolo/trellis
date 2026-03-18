# Basic Trellis Example

Small, self-contained examples for the core Trellis API using in-memory
templates.

## Quick Start

Run from this directory:

```bash
dart pub get
dart run bin/example.dart
dart run bin/shelf_example.dart
```

## What to Look At

- `bin/example.dart` -- inline-template examples for `tl:text`, conditionals,
  iteration, fragments, and `renderFragments()`
- `bin/shelf_example.dart` -- minimal Shelf integration pattern with Trellis

This example is useful when you want to understand the engine API without
setting up file-based templates or a larger app structure.
