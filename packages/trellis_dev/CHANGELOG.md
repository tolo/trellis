# Changelog

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
