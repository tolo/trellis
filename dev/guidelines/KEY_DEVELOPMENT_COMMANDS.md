# Key Development Commands

## Build

```bash
# Install / sync dependencies
dart pub get
```

## Code Quality

> **Line width: 120 chars** — enforced in analysis_options.yaml.

```bash
# Format
dart format lib test

# Analyze
dart analyze
```

## Testing

```bash
# All tests
dart test

# Single test file
dart test test/engine_test.dart
```
