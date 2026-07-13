# Changelog

## 0.10.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.9.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.9.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.8.2

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.8.1

### Added

- `devMiddleware()` now validates templates in dev mode and reports issues to stderr — on by default, disable with `validate: false`. Validation runs at startup and on every watched-file change, surfacing warnings/errors automatically instead of only via `dart run trellis:validate`. Results are formatted as `path:line: severity: message (attribute)` (matching the validate CLI) and cached per template so an unchanged template is reported only once. Pass a configured `validator:` to match a custom prefix/dialect, or `validationSink:` to redirect output.

## 0.8.0

### Changed

- Version aligned to the unified Trellis SDK lockstep versioning scheme — all SDK packages now share a single version number and are released together. No functional changes since 0.1.0.

## 0.1.0

### Added

- `liveReloadHandler()` for streaming SSE reload events to connected browsers.
- `devMiddleware()` for mounting the reload endpoint and optionally injecting the client script into buffered HTML responses.
- `liveReloadScript()` for manual integration when you want to control HTML injection yourself.

### Notes

- Designed to pair with `FileSystemLoader(devMode: true)` from the core `trellis` package.
- Works independently of framework-specific hot restart workflows by focusing on template changes and browser refresh.
