# Changelog

## 0.1.0

### Added

- `liveReloadHandler()` for streaming SSE reload events to connected browsers.
- `devMiddleware()` for mounting the reload endpoint and optionally injecting the client script into buffered HTML responses.
- `liveReloadScript()` for manual integration when you want to control HTML injection yourself.

### Notes

- Designed to pair with `FileSystemLoader(devMode: true)` from the core `trellis` package.
- Works independently of framework-specific hot restart workflows by focusing on template changes and browser refresh.
