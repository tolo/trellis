# Changelog

## 0.8.0

### Changed

- Version aligned to the unified Trellis SDK lockstep versioning scheme — all SDK packages now share a single version number and are released together. No functional changes since 0.1.0.

## 0.1.0

### Added

- `trellisProvider()` for exposing a `Trellis` engine through Dart Frog providers.
- `renderPage()`, `renderFragment()`, and `renderOobFragments()` for template rendering from `RequestContext`.
- HTMX request helpers: `isHtmxRequest()`, `htmxTarget()`, `htmxTrigger()`, and `isHtmxBoosted()`.
- `csrfToken()` and `CsrfToken` for reading the current token from request context.

### Security

- `trellisSecurityHeaders()` middleware bridged from `trellis_shelf`.
- `trellisCsrf()` middleware bridging the Shelf double-submit cookie implementation into Dart Frog.
- Re-export of `CspBuilder` so apps can configure CSP without importing `trellis_shelf` directly.
